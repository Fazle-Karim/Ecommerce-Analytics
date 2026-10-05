"""
compute_rfm_and_cohorts.py
Purpose: Compute RFM segments and cohort retention in pandas. Writes ONLY
         the aggregates back into documentation/control_totals.json.
         The SQL implementation in 06_rfm_cohorts.sql must reproduce them.

Both sides use the same bucket rule: rank by (sort_key, customer_unique_id ASC),
then assign buckets by FLOOR(N * 0.2), FLOOR(N * 0.4), FLOOR(N * 0.6),
FLOOR(N * 0.8). No NTILE, no pd.cut — the boundaries are identical integers.
"""

import json
import pandas as pd
from pathlib import Path

RAW       = Path("data/raw")
JSON_PATH = Path("documentation/control_totals.json")
REF_PATH  = Path("documentation/rfm_cohorts_reference.json")

IN_SCOPE     = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")
SNAPSHOT     = pd.Timestamp("2018-08-31")

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

# ---------------------------------------------------------------------------
# Bucket boundaries — the same integers SQL uses
# ---------------------------------------------------------------------------
b20 = int(n * 0.2)   # 18940
b40 = int(n * 0.4)
b60 = int(n * 0.6)
b80 = int(n * 0.8)

# ---------------------------------------------------------------------------
# R score: rank by (last_purchase_ts DESC, customer_unique_id ASC)
# Assign R=5 to top b20, R=4 to next, etc.
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
# M score: rank by (monetary ASC, customer_unique_id ASC)
# Assign M=1 to bottom b20, M=5 to top
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
# Segment assignment
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
        return "New"
    return "Lost"

per_customer["segment"] = per_customer.apply(assign_segment, axis=1)

segment_counts = per_customer["segment"].value_counts().to_dict()
print("\nSegment counts:")
for seg in ["Champions", "Loyal", "At Risk", "New", "Lost"]:
    print(f"  {seg:<10} {segment_counts.get(seg, 0):,}")

total_rows = int(len(per_customer))
repeat_customers = int((per_customer["frequency"] >= 2).sum())

# ---------------------------------------------------------------------------
# Cohort retention
# ---------------------------------------------------------------------------
orders_for_cohort = pop[["order_id", "customer_unique_id", "purchase_dt"]].copy()
orders_for_cohort["order_month"] = orders_for_cohort["purchase_dt"].dt.to_period("M").astype(str)

first_month = (
    orders_for_cohort.groupby("customer_unique_id")["purchase_dt"].min()
    .rename("first_purchase_dt").reset_index()
)
first_month["cohort_month"] = first_month["first_purchase_dt"].dt.to_period("M").astype(str)

orders_with_cohort = orders_for_cohort.merge(
    first_month[["customer_unique_id", "cohort_month"]],
    on="customer_unique_id", how="left"
)

def month_diff(a, b):
    ay, am = int(a[:4]), int(a[5:7])
    by, bm = int(b[:4]), int(b[5:7])
    return (ay - by) * 12 + (am - bm)

orders_with_cohort["month_offset"] = orders_with_cohort.apply(
    lambda r: month_diff(r["order_month"], r["cohort_month"]), axis=1
)

active = orders_with_cohort.groupby(
    ["cohort_month", "month_offset"]
)["customer_unique_id"].nunique().rename("active_customers").reset_index()

cohort_size = first_month.groupby("cohort_month")["customer_unique_id"].nunique().rename("cohort_size").reset_index()

cohort_matrix = active.merge(cohort_size, on="cohort_month", how="left")
cohort_matrix["retention_pct"] = (100.0 * cohort_matrix["active_customers"] / cohort_matrix["cohort_size"]).round(4)

print(f"\nCohort matrix rows: {len(cohort_matrix):,}")
print(f"Cohort months: {cohort_matrix['cohort_month'].nunique()}")

# ---------------------------------------------------------------------------
# Write aggregates
# ---------------------------------------------------------------------------
data = json.loads(JSON_PATH.read_text(encoding="utf-8"))

rfm = {
    "customer_count":     total_rows,
    "repeat_customers":   repeat_customers,
    "segment_champions":  int(segment_counts.get("Champions", 0)),
    "segment_loyal":      int(segment_counts.get("Loyal", 0)),
    "segment_at_risk":    int(segment_counts.get("At Risk", 0)),
    "segment_new":        int(segment_counts.get("New", 0)),
    "segment_lost":       int(segment_counts.get("Lost", 0)),
    "f_band_1":           int((per_customer["frequency"] == 1).sum()),
    "f_band_2":           int((per_customer["frequency"] == 2).sum()),
    "f_band_3_plus":      int((per_customer["frequency"] >= 3).sum()),
}
data["rfm"] = rfm

cohort = {
    "cohort_months":     int(cohort_matrix["cohort_month"].nunique()),
    "matrix_rows":       int(len(cohort_matrix)),
}
data["cohort"] = cohort

JSON_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")

ref = {
    "generated_at":  str(pd.Timestamp.now()),
    "rfm":           rfm,
    "cohort":        cohort,
    "segments_total": sum(segment_counts.values()),
    "f_ge_2_total":   repeat_customers,
}
REF_PATH.write_text(json.dumps(ref, indent=2), encoding="utf-8")

print(f"\nUpdated {JSON_PATH}")
print(f"Wrote   {REF_PATH}")
print(f"\nSanity:")
print(f"  Segments sum:       {sum(segment_counts.values()):,}  (expect {total_rows:,})")
print(f"  F>=2 repeat:        {repeat_customers:,}  (expect 2,874)")