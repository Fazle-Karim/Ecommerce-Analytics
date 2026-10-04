"""
control_totals.py
Purpose: Compute every pinned control total from the raw CSVs and write
         them to JSON + a markdown table.
Output:  documentation/control_totals.json
         documentation/control_totals.md
"""

import json
import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT_JSON = Path("documentation/control_totals.json")
OUT_MD   = Path("documentation/control_totals.md")

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

# ------------------------------------------------------------------
# Load every table
# ------------------------------------------------------------------
orders      = load("olist_orders_dataset.csv")
items       = load("olist_order_items_dataset.csv")
payments    = load("olist_order_payments_dataset.csv")
reviews     = load("olist_order_reviews_dataset.csv")
customers   = load("olist_customers_dataset.csv")
sellers     = load("olist_sellers_dataset.csv")
products    = load("olist_products_dataset.csv")
geolocation = load("olist_geolocation_dataset.csv")
trans       = load("product_category_name_translation.csv")

orders["purchase_dt"]  = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")
orders["delivered_dt"] = pd.to_datetime(orders["order_delivered_customer_date"], errors="coerce")
orders["estimated_dt"] = pd.to_datetime(orders["order_estimated_delivery_date"], errors="coerce")

items["price"]         = pd.to_numeric(items["price"],         errors="coerce")
items["freight_value"] = pd.to_numeric(items["freight_value"], errors="coerce")
items["line_total"]    = items["price"] + items["freight_value"]
payments["payment_value"] = pd.to_numeric(payments["payment_value"], errors="coerce")
reviews["review_score"]   = pd.to_numeric(reviews["review_score"], errors="coerce")
reviews["review_creation_dt"] = pd.to_datetime(reviews["review_creation_date"], errors="coerce")
reviews["review_answer_dt"]   = pd.to_datetime(reviews["review_answer_timestamp"], errors="coerce")

IN_SCOPE     = {"delivered", "shipped", "invoiced", "processing", "approved"}
EXCLUDED     = {"canceled", "unavailable", "created"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")

# ------------------------------------------------------------------
# RAW-LEVEL values (for Step 3 load verification)
# ------------------------------------------------------------------
raw_level = {
    "orders_row_count":               int(len(orders)),
    "order_items_row_count":          int(len(items)),
    "payments_row_count":             int(len(payments)),
    "reviews_row_count":              int(len(reviews)),
    "customers_row_count":            int(len(customers)),
    "sellers_row_count":              int(len(sellers)),
    "products_row_count":             int(len(products)),
    "geolocation_row_count":          int(len(geolocation)),
    "category_translation_row_count": int(len(trans)),
    "orders_distinct_order_id":       int(orders["order_id"].nunique()),
    "customers_distinct_unique_id":   int(customers["customer_unique_id"].nunique()),
    "raw_sum_price":                  round(float(items["price"].sum()), 2),
    "raw_sum_freight_value":          round(float(items["freight_value"].sum()), 2),
    "raw_sum_payment_value":          round(float(payments["payment_value"].sum()), 2),
}

# ------------------------------------------------------------------
# Funnel
# ------------------------------------------------------------------
n_raw = len(orders)

step1 = orders[orders["order_status"].isin(IN_SCOPE)]
n_in_scope = len(step1)

step2 = step1[
    (step1["purchase_dt"] >= WINDOW_START) &
    (step1["purchase_dt"] <  WINDOW_END)
]
n_in_window = len(step2)

order_ids_with_items = set(items["order_id"])
step3 = step2[step2["order_id"].isin(order_ids_with_items)]
n_population = len(step3)

population_order_ids = set(step3["order_id"])

# ------------------------------------------------------------------
# Revenue on analytic population
# ------------------------------------------------------------------
items_pop = items[items["order_id"].isin(population_order_ids)]

gmv             = round(float(items_pop["price"].sum()), 2)
freight_charged = round(float(items_pop["freight_value"].sum()), 2)
total_paid      = round(gmv + freight_charged, 2)

# ------------------------------------------------------------------
# Payments reconciliation
# ------------------------------------------------------------------
items_by_order = (
    items_pop.groupby("order_id")["line_total"].sum().round(2).rename("item_total")
)
payments_pop = payments[payments["order_id"].isin(population_order_ids)]
payments_by_order = (
    payments_pop.groupby("order_id")["payment_value"].sum().round(2).rename("payment_total")
)

merged = items_by_order.to_frame().join(payments_by_order, how="inner")
merged["diff"]     = (merged["payment_total"] - merged["item_total"]).round(2)
merged["abs_diff"] = merged["diff"].abs().round(2)

payment_total = round(float(merged["payment_total"].sum()), 2)
item_total    = round(float(merged["item_total"].sum()), 2)
net_residual  = round(float(merged["diff"].sum()), 2)
abs_residual  = round(float(merged["abs_diff"].sum()), 2)

orders_exact_match      = int((merged["abs_diff"] == 0.00).sum())
orders_differ_one_cent  = int((merged["abs_diff"] == 0.01).sum())
orders_within_one_cent  = orders_exact_match + orders_differ_one_cent
orders_with_larger_diff = len(merged) - orders_within_one_cent

# ------------------------------------------------------------------
# Customer metrics
# ------------------------------------------------------------------
orders_cust = orders[["order_id", "customer_id"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
per_person_all = orders_cust.groupby("customer_unique_id")["order_id"].nunique()

unique_customers_all = int(per_person_all.shape[0])
repeat_customers_all = int((per_person_all > 1).sum())
repeat_rate_all      = round(repeat_customers_all / unique_customers_all * 100, 2)

orders_cust_scope = orders[["order_id", "customer_id", "order_status"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
orders_cust_scope = orders_cust_scope[orders_cust_scope["order_status"].isin(IN_SCOPE)]
per_person_scope = orders_cust_scope.groupby("customer_unique_id")["order_id"].nunique()

unique_customers_scope = int(per_person_scope.shape[0])
repeat_customers_scope = int((per_person_scope > 1).sum())
repeat_rate_scope      = round(repeat_customers_scope / unique_customers_scope * 100, 2)

pop_orders_cust = orders[["order_id", "customer_id"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
pop_orders_cust = pop_orders_cust[pop_orders_cust["order_id"].isin(population_order_ids)]
per_person_pop = pop_orders_cust.groupby("customer_unique_id")["order_id"].nunique()

unique_customers_pop = int(per_person_pop.shape[0])
repeat_customers_pop = int((per_person_pop > 1).sum())

# ------------------------------------------------------------------
# Late rate (in-window, in-scope, delivered, non-null delivery date)
# ------------------------------------------------------------------
late_pop = orders[
    orders["order_status"].isin(IN_SCOPE) &
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END) &
    (orders["order_status"] == "delivered") &
    orders["delivered_dt"].notna()
].copy()

late_pop["late_flag"] = (
    late_pop["delivered_dt"].dt.normalize() > late_pop["estimated_dt"].dt.normalize()
)

n_late_denominator = int(len(late_pop))
n_late             = int(late_pop["late_flag"].sum())
late_rate          = round(n_late / n_late_denominator * 100, 2)

# ------------------------------------------------------------------
# Excluded-status payments
# ------------------------------------------------------------------
excluded_orders = orders[orders["order_status"].isin(EXCLUDED)]
excluded_payments = payments[payments["order_id"].isin(excluded_orders["order_id"])]
excluded_payments_total = round(float(excluded_payments["payment_value"].sum()), 2)

# ------------------------------------------------------------------
# Year splits
# ------------------------------------------------------------------
n_2017_in_scope = int((
    (orders["purchase_dt"] >= pd.Timestamp("2017-01-01")) &
    (orders["purchase_dt"] <  pd.Timestamp("2018-01-01")) &
    orders["order_status"].isin(IN_SCOPE)
).sum())
n_2018_in_scope = int((
    (orders["purchase_dt"] >= pd.Timestamp("2018-01-01")) &
    (orders["purchase_dt"] <  pd.Timestamp("2018-09-01")) &
    orders["order_status"].isin(IN_SCOPE)
).sum())
n_all_statuses_in_window = int((
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END)
).sum())

# ------------------------------------------------------------------
# Monthly orders + GMV for the window
# ------------------------------------------------------------------
orders_window = orders[
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END)
].copy()
orders_window["month"] = orders_window["purchase_dt"].dt.to_period("M").astype(str)

items_window = items.merge(
    orders_window[["order_id", "month", "order_status"]],
    on="order_id", how="inner"
)

monthly = {}
for month, grp in orders_window.groupby("month"):
    monthly[month] = {
        "orders_all_statuses": int(len(grp)),
        "orders_in_scope":     int((grp["order_status"].isin(IN_SCOPE)).sum()),
        "gmv_item_price_only": 0.0,
    }

items_window_scope = items_window[items_window["order_status"].isin(IN_SCOPE)]
gmv_by_month = items_window_scope.groupby("month")["price"].sum().round(2)
for month, gmv_val in gmv_by_month.items():
    if month in monthly:
        monthly[month]["gmv_item_price_only"] = float(gmv_val)

# ------------------------------------------------------------------
# Reviews — deduplicated per order_id (keep latest)
# ------------------------------------------------------------------
reviews_sorted = reviews.sort_values(
    ["review_creation_dt", "review_answer_dt"],
    ascending=[False, False],
)
reviews_dedup = reviews_sorted.drop_duplicates(subset=["order_id"], keep="first")

# Population A: all orders (any status, any date), deduplicated
orders_with_deduped_review_all_orders = int(reviews_dedup["order_id"].nunique())
avg_review_score_all_orders = round(float(reviews_dedup["review_score"].mean()), 4)

# Population B: delivered-in-window (analytic population + delivered + non-null delivery date)
late_pop_ids = set(late_pop["order_id"])
late_pop_reviews = reviews_dedup[reviews_dedup["order_id"].isin(late_pop_ids)].merge(
    late_pop[["order_id", "late_flag"]], on="order_id", how="left"
)
avg_review_score_delivered_in_window_late = round(
    float(late_pop_reviews[late_pop_reviews["late_flag"] == 1]["review_score"].mean()), 4
)
avg_review_score_delivered_in_window_on_time = round(
    float(late_pop_reviews[late_pop_reviews["late_flag"] == 0]["review_score"].mean()), 4
)
late_vs_on_time_gap_delivered_in_window = round(
    avg_review_score_delivered_in_window_late
    - avg_review_score_delivered_in_window_on_time, 4
)

# ------------------------------------------------------------------
# Top categories by GMV (item price only, analytic population)
# ------------------------------------------------------------------
products_with_cat = products[["product_id", "product_category_name"]]
items_pop_cat = items_pop.merge(products_with_cat, on="product_id", how="left")
cat_gmv = (
    items_pop_cat.groupby("product_category_name")["price"].sum().round(2)
    .sort_values(ascending=False)
    .head(10)
)
top_categories = [
    {"category_name": str(cat), "gmv": float(val)}
    for cat, val in cat_gmv.items()
]

# ------------------------------------------------------------------
# Assemble JSON
# ------------------------------------------------------------------
totals = {
    "generated_at": str(pd.Timestamp.now()),
    "raw_level": raw_level,
    "funnel": {
        "raw_orders":             n_raw,
        "in_scope_status":        n_in_scope,
        "in_scope_and_in_window": n_in_window,
        "analytic_population":    n_population,
    },
    "revenue_on_population": {
        "gmv_item_price_only": gmv,
        "freight_charged":     freight_charged,
        "total_customer_paid": total_paid,
    },
    "payments_reconciliation": {
        "payments_total":          payment_total,
        "items_total":             item_total,
        "net_residual":            net_residual,
        "absolute_residual":       abs_residual,
        "orders_exact_match":      orders_exact_match,
        "orders_differ_one_cent":  orders_differ_one_cent,
        "orders_within_one_cent":  orders_within_one_cent,
        "orders_with_larger_diff": orders_with_larger_diff,
        "orders_compared":         len(merged),
    },
    "customers": {
        "unique_customers_all_statuses":  unique_customers_all,
        "repeat_customers_all_statuses":  repeat_customers_all,
        "repeat_rate_all_statuses_pct":   repeat_rate_all,
        "unique_customers_in_scope":      unique_customers_scope,
        "repeat_customers_in_scope":      repeat_customers_scope,
        "repeat_rate_in_scope_pct":       repeat_rate_scope,
        "unique_customers_in_population": unique_customers_pop,
        "repeat_customers_in_population": repeat_customers_pop,
    },
    "late_rate": {
        "denominator":   n_late_denominator,
        "late_orders":   n_late,
        "late_rate_pct": late_rate,
    },
    "reviews": {
        "orders_with_deduped_review_all_orders":
            orders_with_deduped_review_all_orders,
        "average_review_score_all_orders":
            avg_review_score_all_orders,
        "average_review_score_delivered_in_window_late":
            avg_review_score_delivered_in_window_late,
        "average_review_score_delivered_in_window_on_time":
            avg_review_score_delivered_in_window_on_time,
        "late_vs_on_time_gap_delivered_in_window":
            late_vs_on_time_gap_delivered_in_window,
    },
    "excluded_statuses": {
        "payments_total": excluded_payments_total,
    },
    "year_splits": {
        "in_window_orders_2017":                   n_2017_in_scope,
        "in_window_orders_2018":                   n_2018_in_scope,
        "in_window_orders_2017_2018_all_statuses": n_all_statuses_in_window,
    },
    "monthly_window":     monthly,
    "top_categories_gmv": top_categories,
}

OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
OUT_JSON.write_text(json.dumps(totals, indent=2), encoding="utf-8")

# ------------------------------------------------------------------
# Markdown table
# ------------------------------------------------------------------
md = []
md.append("# Control Totals — Olist Analytics\n")
md.append(f"**Generated:** {totals['generated_at']}")
md.append("**Source:** `python/control_totals.py` (re-runnable)")
md.append("**JSON:** `documentation/control_totals.json`")
md.append("")
md.append("> Every number in this file is derived from the raw CSVs by script.")
md.append("> No value is hand-entered. Any SQL layer built on top of this")
md.append("> project must reproduce these totals exactly.")
md.append("")
md.append("---\n")

def fmt_value(v):
    if isinstance(v, float):
        if v == int(v):
            return f"{int(v):,}"
        return f"{v:,.2f}"
    if isinstance(v, int):
        return f"{v:,}"
    return str(v)

def section(title, rows):
    md.append(f"## {title}\n")
    md.append("| Metric | Value |")
    md.append("|--------|------:|")
    for k, v in rows:
        md.append(f"| {k} | `{fmt_value(v)}` |")
    md.append("")

section("Raw-Level Values (Step 3 load verification)", [
    ("orders row count",                raw_level["orders_row_count"]),
    ("order_items row count",           raw_level["order_items_row_count"]),
    ("payments row count",              raw_level["payments_row_count"]),
    ("reviews row count",               raw_level["reviews_row_count"]),
    ("customers row count",             raw_level["customers_row_count"]),
    ("sellers row count",               raw_level["sellers_row_count"]),
    ("products row count",              raw_level["products_row_count"]),
    ("geolocation row count",           raw_level["geolocation_row_count"]),
    ("category_translation row count",  raw_level["category_translation_row_count"]),
    ("distinct orders.order_id",        raw_level["orders_distinct_order_id"]),
    ("distinct customers.customer_unique_id", raw_level["customers_distinct_unique_id"]),
    ("SUM(items.price) raw",            f"BRL {raw_level['raw_sum_price']:,.2f}"),
    ("SUM(items.freight_value) raw",    f"BRL {raw_level['raw_sum_freight_value']:,.2f}"),
    ("SUM(payments.payment_value) raw", f"BRL {raw_level['raw_sum_payment_value']:,.2f}"),
])

section("Order Funnel", [
    ("Step 0 — Raw orders",             n_raw),
    ("Step 1 — In-scope status",        n_in_scope),
    ("Step 2 — In-scope and in-window", n_in_window),
    ("Step 3 — Analytic population",    n_population),
])

section("Revenue on Analytic Population", [
    ("GMV (item price only)", f"BRL {gmv:,.2f}"),
    ("Freight Charged",       f"BRL {freight_charged:,.2f}"),
    ("Total Customer Paid",   f"BRL {total_paid:,.2f}"),
])

section("Payments Reconciliation", [
    ("Payments total",                f"BRL {payment_total:,.2f}"),
    ("Items total",                   f"BRL {item_total:,.2f}"),
    ("Net residual",                  f"BRL {net_residual:,.2f}"),
    ("Absolute residual",             f"BRL {abs_residual:,.2f}"),
    ("Orders exactly equal",          orders_exact_match),
    ("Orders differing by 1 cent",    orders_differ_one_cent),
    ("Orders within 1 cent",          orders_within_one_cent),
    ("Orders with larger diff",       orders_with_larger_diff),
    ("Orders compared",               len(merged)),
])

section("Customers", [
    ("Unique customers (all statuses)",         unique_customers_all),
    ("Repeat customers (all statuses)",         repeat_customers_all),
    ("Repeat rate % (all statuses)",            repeat_rate_all),
    ("Unique customers (in-scope)",             unique_customers_scope),
    ("Repeat customers (in-scope)",             repeat_customers_scope),
    ("Repeat rate % (in-scope)",                repeat_rate_scope),
    ("Unique customers (analytic population)",  unique_customers_pop),
    ("Repeat customers (analytic population)",  repeat_customers_pop),
])

section("Late Rate", [
    ("Denominator", n_late_denominator),
    ("Late orders", n_late),
    ("Late rate %", late_rate),
])

section("Reviews (populations stated in key names)", [
    ("Orders with deduped review (all orders)",
        orders_with_deduped_review_all_orders),
    ("Avg review score (all orders)",
        avg_review_score_all_orders),
    ("Avg review score (delivered-in-window, late)",
        avg_review_score_delivered_in_window_late),
    ("Avg review score (delivered-in-window, on-time)",
        avg_review_score_delivered_in_window_on_time),
    ("Late vs on-time gap (delivered-in-window)",
        late_vs_on_time_gap_delivered_in_window),
])

section("Excluded Statuses", [
    ("Payments on canceled/unavailable/created", f"BRL {excluded_payments_total:,.2f}"),
])

section("Year Splits", [
    ("In-window orders 2017 (in-scope)",          n_2017_in_scope),
    ("In-window orders 2018 (in-scope)",          n_2018_in_scope),
    ("In-window orders 2017+2018 (all statuses)", n_all_statuses_in_window),
])

md.append("## Monthly Window (2017-01 to 2018-08)\n")
md.append("| Month | Orders (all statuses) | Orders (in-scope) | GMV (in-scope, item price) |")
md.append("|-------|----------------------:|------------------:|---------------------------:|")
for month in sorted(monthly.keys()):
    m = monthly[month]
    md.append(f"| {month} | {m['orders_all_statuses']:,} | {m['orders_in_scope']:,} | `BRL {m['gmv_item_price_only']:,.2f}` |")
md.append("")

md.append("## Top 10 Categories by GMV (analytic population)\n")
md.append("| Rank | Category | GMV |")
md.append("|-----:|----------|----:|")
for i, entry in enumerate(top_categories, start=1):
    md.append(f"| {i} | `{entry['category_name']}` | `BRL {entry['gmv']:,.2f}` |")
md.append("")

OUT_MD.write_text("\n".join(md), encoding="utf-8")

print(json.dumps(totals, indent=2))
print(f"\n✅ Written: {OUT_JSON}")
print(f"✅ Written: {OUT_MD}")