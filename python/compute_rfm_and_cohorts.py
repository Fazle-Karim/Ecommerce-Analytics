"""
compute_rfm_and_cohorts.py
Purpose: Compute RFM segments and cohort retention in pandas. Writes:
           - aggregates to documentation/control_totals.json
           - reference JSON to documentation/rfm_cohorts_reference.json
           - per-customer table to data/cleaned/pandas_rfm.csv (git-ignored)
           - cohort cells to sql/test_expected_cohort.sql (committed)
"""

import json
import pandas as pd
from pathlib import Path

RAW         = Path("data/raw")
CLEANED     = Path("data/cleaned")
JSON_PATH   = Path("documentation/control_totals.json")
REF_PATH    = Path("documentation/rfm_cohorts_reference.json")
CSV_PATH    = CLEANED / "pandas_rfm.csv"
COHORT_SQL  = Path("sql/test_expected_cohort.sql")

IN_SCOPE       = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START   = pd.Timestamp("2017-01-01")
WINDOW_END     = pd.Timestamp("2018-09-01")
SNAPSHOT       = pd.Timestamp("2018-08-31")
SNAPSHOT_MONTH = pd.Timestamp("2018-08-01")

CLEANED.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
orders = pd.read_csv(RAW / "olist_orders_dataset.csv", dtype=str, encoding="utf-8")
items  = pd.read_csv(RAW / "olist_order_items_dataset.csv", dtype=str, encoding="utf-8")
custs  = pd.read_csv(RAW / "olist_customers_dataset.csv", dtype=str, encoding="utf-8")

orders["purchase_dt"] = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")
items["price"]        = pd.to_numeric(items["price"], errors="coerce")

orders = orders.merge(custs[["customer_id", "customer_unique_id"]],
                     on="customer_id", how="left")

pop = orders[
    orders["order_status"].isin(IN_SCOPE) &
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END)
].copy()

print(f"Analytic population orders: {len(pop):,}")

pop_items = items[items["order_id"].isin(pop["order_id"])].copy()
items_per_order = pop_items.groupby("order_id")["price"].sum().rename("order_value")
pop_with_value = pop.merge(items_per_order, on="order_id", how="left")

per_customer = pop_with_value.groupby("customer_unique_id").agg(
    last_purchase_ts = ("purchase_dt", "max"),
    frequency        = ("order_id", "nunique"),
    monetary         = ("order_value", "sum"),
).reset_index()

print(f"Unique customers: {len(per_customer):,}")

n = len(per_customer)
b20 = int(n * 0.2)
b40 = int(n * 0.4)
b60 = int(n * 0.6)
b80 = int(n * 0.8)

# ---------------------------------------------------------------------------
# R score
# ---------------------------------------------------------------------------
per_customer = per_customer.sort_values(
    ["last_purchase_ts", "customer_unique_id"],
    ascending=[False, True]
).reset_index(drop=True)

per_customer["r_rank"] = range(1, n + 1)

def r_score(rank):
    if rank <= b20: return 5
    if rank <= b40: return 4
    if rank <= b60: return 3
    if rank <= b80: return 2
    return 1

per_customer["r_score"] = per_customer["r_rank"].apply(r_score)

# ---------------------------------------------------------------------------
# F band
# ---------------------------------------------------------------------------
per_customer["f_band"] = per_customer["frequency"].apply(
    lambda x: "1" if x == 1 else ("2" if x == 2 else "3+")
)

# ---------------------------------------------------------------------------
# M score
# ---------------------------------------------------------------------------
per_customer = per_customer.sort_values(
    ["monetary", "customer_unique_id"],
    ascending=[True, True]
).reset_index(drop=True)

per_customer["m_rank"] = range(1, n + 1)

def m_score(rank):
    if rank <= b20: return 1
    if rank <= b40: return 2
    if rank <= b60: return 3
    if rank <= b80: return 4
    return 5

per_customer["m_score"] = per_customer["m_rank"].apply(m_score)

# ---------------------------------------------------------------------------
# Segment
# ---------------------------------------------------------------------------
def assign_segment(row):
    f = row["f_band"]
    r = row["r_score"]
    if f in ("2", "3+") and r >= 4:
        return "Champions"
    if f in ("2", "3+") and r == 3:
        return "Loyal"
    if f in ("2", "3+") and r <= 2:
        return "At Risk"
    if f == "1" and r >= 4:
        return "Recent one-time"
    if f == "1" and r <= 3:
        return "Lapsed one-time"
    return "UNCLASSIFIED"

per_customer["segment"] = per_customer.apply(assign_segment, axis=1)

segment_counts = per_customer["segment"].value_counts().to_dict()
print("\nSegment counts:")
for seg in ["Champions", "Loyal", "At Risk", "Recent one-time", "Lapsed one-time", "UNCLASSIFIED"]:
    print(f"  {seg:<18} {segment_counts.get(seg, 0):,}")

# Recency cutoffs per R score
recency_cutoffs = per_customer.groupby("r_score")["last_purchase_ts"].agg(
    ["min", "max", "count"]
).reset_index()
print("\nRecency cutoffs per R score:")
for _, row in recency_cutoffs.sort_values("r_score", ascending=False).iterrows():
    print(f"  R={int(row['r_score'])}: {row['min'].date()} .. {row['max'].date()}  (n={int(row['count'])})")

total_rows = int(len(per_customer))
repeat_customers = int((per_customer["frequency"] >= 2).sum())

# ---------------------------------------------------------------------------
# Cohort retention
# ---------------------------------------------------------------------------
all_orders = orders[orders["order_status"].isin(IN_SCOPE)].copy()

first_ever = (
    all_orders.groupby("customer_unique_id")["purchase_dt"].min()
    .rename("first_ever_dt").reset_index()
)
first_ever["first_cohort_month"] = first_ever["first_ever_dt"].dt.to_period("M").astype(str)
first_ever.loc[first_ever["first_ever_dt"] < WINDOW_START, "first_cohort_month"] = "pre-2017"

rfm_customers = set(per_customer["customer_unique_id"])
pre_2017_count = int(
    first_ever[
        (first_ever["first_cohort_month"] == "pre-2017") &
        (first_ever["customer_unique_id"].isin(rfm_customers))
    ].shape[0]
)

in_window_first = first_ever[first_ever["first_cohort_month"] != "pre-2017"]

cohort_orders = pop[["customer_unique_id", "purchase_dt"]].copy()
cohort_orders = cohort_orders.merge(
    in_window_first[["customer_unique_id", "first_cohort_month"]],
    on="customer_unique_id", how="inner"
)
cohort_orders["order_month"] = cohort_orders["purchase_dt"].dt.to_period("M").astype(str)

def month_diff(a, b):
    ay, am = int(a[:4]), int(a[5:7])
    by, bm = int(b[:4]), int(b[5:7])
    return (ay - by) * 12 + (am - bm)

cohort_orders["month_offset"] = cohort_orders.apply(
    lambda r: month_diff(r["order_month"], r["first_cohort_month"]), axis=1
)

cohort_size = in_window_first.groupby("first_cohort_month")["customer_unique_id"].nunique().rename("cohort_size").reset_index()
cohort_size.columns = ["cohort_month", "cohort_size"]

active = cohort_orders.groupby(
    ["first_cohort_month", "month_offset"]
)["customer_unique_id"].nunique().rename("active_customers").reset_index()
active.columns = ["cohort_month", "month_offset", "active_customers"]

cohort_size["cohort_month_start"] = pd.to_datetime(cohort_size["cohort_month"] + "-01")
cohort_size["max_offset"] = (
    (SNAPSHOT_MONTH.year - cohort_size["cohort_month_start"].dt.year) * 12
    + (SNAPSHOT_MONTH.month - cohort_size["cohort_month_start"].dt.month)
)

rows = []
for _, cs in cohort_size.iterrows():
    for offset in range(0, int(cs["max_offset"]) + 1):
        rows.append({
            "cohort_month": cs["cohort_month"],
            "cohort_month_start": cs["cohort_month_start"].date(),
            "month_offset": offset,
            "cohort_size": int(cs["cohort_size"]),
        })

cohort_matrix = pd.DataFrame(rows).merge(
    active, on=["cohort_month", "month_offset"], how="left"
)
cohort_matrix["active_customers"] = cohort_matrix["active_customers"].fillna(0).astype(int)
cohort_matrix["retention_pct"] = (100.0 * cohort_matrix["active_customers"] / cohort_matrix["cohort_size"]).round(4)

matrix_customers = int(cohort_size["cohort_size"].sum())

print(f"\nCohort matrix rows: {len(cohort_matrix):,}")
print(f"Cohort months: {cohort_matrix['cohort_month'].nunique()}")
print(f"Pre-2017 bucket: {pre_2017_count} customers")
print(f"Matrix customers: {matrix_customers:,}")
print(f"Matrix + pre-2017: {matrix_customers + pre_2017_count:,}  (expect 94,703)")

# ---------------------------------------------------------------------------
# Write CSV export (per-customer RFM)
# ---------------------------------------------------------------------------
export = per_customer[[
    "customer_unique_id", "last_purchase_ts", "r_score", "f_band", "m_score", "segment"
]].copy()
export["recency_days"] = (SNAPSHOT - export["last_purchase_ts"]).dt.days
export["frequency"] = per_customer["frequency"].values
export["monetary"] = per_customer["monetary"].round(2).values

export = export[[
    "customer_unique_id", "recency_days", "frequency", "monetary",
    "r_score", "f_band", "m_score", "segment"
]].sort_values("customer_unique_id").reset_index(drop=True)

export.to_csv(CSV_PATH, index=False, encoding="utf-8")
print(f"\nWrote {CSV_PATH} ({len(export):,} rows)")

# ---------------------------------------------------------------------------
# Write cohort cells as SQL INSERT (committed)
# ---------------------------------------------------------------------------
sql_lines = []
sql_lines.append("-- ===============================================================================")
sql_lines.append("-- Script: test_expected_cohort.sql")
sql_lines.append("-- GENERATED by python/compute_rfm_and_cohorts.py")
sql_lines.append("-- DO NOT EDIT BY HAND.")
sql_lines.append("-- Loads the full cohort matrix (210 cells + pre-2017 sentinel).")
sql_lines.append("-- ===============================================================================")
sql_lines.append("")
sql_lines.append("USE OlistAnalytics;")
sql_lines.append("GO")
sql_lines.append("")
sql_lines.append("IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'tests')")
sql_lines.append("    EXEC('CREATE SCHEMA tests');")
sql_lines.append("GO")
sql_lines.append("")
sql_lines.append("IF OBJECT_ID('tests.expected_cohort', 'U') IS NOT NULL")
sql_lines.append("    DROP TABLE tests.expected_cohort;")
sql_lines.append("GO")
sql_lines.append("")
sql_lines.append("CREATE TABLE tests.expected_cohort (")
sql_lines.append("    cohort_month       NVARCHAR(10) NOT NULL,")
sql_lines.append("    cohort_month_start DATE         NULL,")
sql_lines.append("    month_offset       INT          NOT NULL,")
sql_lines.append("    cohort_size        INT          NOT NULL,")
sql_lines.append("    active_customers   INT          NOT NULL,")
sql_lines.append("    retention_pct      DECIMAL(7,4) NOT NULL,")
sql_lines.append("    PRIMARY KEY (cohort_month, month_offset)")
sql_lines.append(");")
sql_lines.append("GO")
sql_lines.append("")
sql_lines.append("INSERT INTO tests.expected_cohort")
sql_lines.append("    (cohort_month, cohort_month_start, month_offset,")
sql_lines.append("     cohort_size, active_customers, retention_pct)")
sql_lines.append("VALUES")

value_rows = []
for _, r in cohort_matrix.iterrows():
    cm = r["cohort_month"]
    cms = f"'{r['cohort_month_start']}'" if pd.notna(r["cohort_month_start"]) else "NULL"
    value_rows.append(
        f"    (N'{cm}', {cms}, {int(r['month_offset'])}, "
        f"{int(r['cohort_size'])}, {int(r['active_customers'])}, {r['retention_pct']})"
    )

# Append pre-2017 sentinel
pre_2017_row = (
    f"    (N'pre-2017', NULL, 0, {pre_2017_count}, {pre_2017_count}, 100.0000)"
)
value_rows.append(pre_2017_row)

sql_lines.append(",\n".join(value_rows) + ";")
sql_lines.append("GO")
sql_lines.append("")
sql_lines.append(f"PRINT 'Loaded {len(value_rows)} cohort cells into tests.expected_cohort';")
sql_lines.append("GO")

COHORT_SQL.write_text("\n".join(sql_lines), encoding="utf-8")
print(f"Wrote {COHORT_SQL} ({len(value_rows)} cells)")

# ---------------------------------------------------------------------------
# Write aggregates to JSON
# ---------------------------------------------------------------------------
data = json.loads(JSON_PATH.read_text(encoding="utf-8"))

rfm = {
    "customer_count":                total_rows,
    "repeat_customers":              repeat_customers,
    "segment_champions":             int(segment_counts.get("Champions", 0)),
    "segment_loyal":                 int(segment_counts.get("Loyal", 0)),
    "segment_at_risk":               int(segment_counts.get("At Risk", 0)),
    "segment_recent_one_time":       int(segment_counts.get("Recent one-time", 0)),
    "segment_lapsed_one_time":       int(segment_counts.get("Lapsed one-time", 0)),
    "segment_unclassified":          int(segment_counts.get("UNCLASSIFIED", 0)),
    "f_band_1":                      int((per_customer["frequency"] == 1).sum()),
    "f_band_2":                      int((per_customer["frequency"] == 2).sum()),
    "f_band_3_plus":                 int((per_customer["frequency"] >= 3).sum()),
    "repeat_rate_in_population_pct": round(100.0 * repeat_customers / total_rows, 2),
}
data["rfm"] = rfm

cohort = {
    "cohort_months":         int(cohort_matrix["cohort_month"].nunique()),
    "matrix_rows":           int(len(cohort_matrix)),
    "pre_2017_customers":    pre_2017_count,
    "matrix_customers":      matrix_customers,
}
data["cohort"] = cohort

JSON_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")

ref = {
    "generated_at":    str(pd.Timestamp.now()),
    "rfm":             rfm,
    "cohort":          cohort,
    "segments_total":  sum(segment_counts.values()),
    "f_ge_2_total":    repeat_customers,
}
REF_PATH.write_text(json.dumps(ref, indent=2), encoding="utf-8")

print(f"\nUpdated {JSON_PATH}")
print(f"Wrote   {REF_PATH}")