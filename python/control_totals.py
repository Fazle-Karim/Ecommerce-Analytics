"""
control_totals.py
Purpose: Compute every pinned control total from the raw CSVs and write
         them to JSON + a markdown table. Every downstream document and
         every SQL layer references these values.
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
# Load
# ------------------------------------------------------------------
orders    = load("olist_orders_dataset.csv")
items     = load("olist_order_items_dataset.csv")
payments  = load("olist_order_payments_dataset.csv")
customers = load("olist_customers_dataset.csv")

orders["purchase_dt"] = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")
items["price"]         = pd.to_numeric(items["price"],         errors="coerce")
items["freight_value"] = pd.to_numeric(items["freight_value"], errors="coerce")
items["line_total"]    = items["price"] + items["freight_value"]
payments["payment_value"] = pd.to_numeric(payments["payment_value"], errors="coerce")

IN_SCOPE     = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")   # exclusive

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
# GMV, Freight, Total Paid on analytic population
# ------------------------------------------------------------------
items_pop = items[items["order_id"].isin(population_order_ids)]

gmv             = round(items_pop["price"].sum(), 2)
freight_charged = round(items_pop["freight_value"].sum(), 2)
total_paid      = round(gmv + freight_charged, 2)

# ------------------------------------------------------------------
# Payments reconciliation on analytic population
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

payment_total = round(merged["payment_total"].sum(), 2)
item_total    = round(merged["item_total"].sum(), 2)
net_residual  = round(merged["diff"].sum(), 2)
abs_residual  = round(merged["abs_diff"].sum(), 2)
n_exact_match = int((merged["diff"].abs() < 0.01).sum())

# ------------------------------------------------------------------
# Customer metrics
# ------------------------------------------------------------------
orders_cust = orders[["order_id", "customer_id"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
per_person_all = orders_cust.groupby("customer_unique_id")["order_id"].nunique()

unique_customers = int(per_person_all.shape[0])
repeat_customers = int((per_person_all > 1).sum())
repeat_rate_all  = round(repeat_customers / unique_customers * 100, 2)

# Repeat rate under in-scope filter (for the definitions decision)
orders_cust_scope = orders[["order_id", "customer_id", "order_status"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
orders_cust_scope = orders_cust_scope[orders_cust_scope["order_status"].isin(IN_SCOPE)]
per_person_scope = orders_cust_scope.groupby("customer_unique_id")["order_id"].nunique()
unique_customers_scope = int(per_person_scope.shape[0])
repeat_customers_scope = int((per_person_scope > 1).sum())
repeat_rate_scope = round(repeat_customers_scope / unique_customers_scope * 100, 2)

# ------------------------------------------------------------------
# Late rate (in-window, in-scope, delivered, non-null delivery date)
# ------------------------------------------------------------------
orders["delivered_dt"] = pd.to_datetime(orders["order_delivered_customer_date"],  errors="coerce")
orders["estimated_dt"] = pd.to_datetime(orders["order_estimated_delivery_date"],  errors="coerce")

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

n_late_denominator = len(late_pop)
n_late             = int(late_pop["late_flag"].sum())
late_rate          = round(n_late / n_late_denominator * 100, 2)

# ------------------------------------------------------------------
# Excluded-status payments
# ------------------------------------------------------------------
excluded_statuses = {"canceled", "unavailable", "created"}
excluded_orders = orders[orders["order_status"].isin(excluded_statuses)]
excluded_payments = payments[payments["order_id"].isin(excluded_orders["order_id"])]
excluded_payments_total = round(excluded_payments["payment_value"].sum(), 2)

# ------------------------------------------------------------------
# Changelog-relevant numbers
# ------------------------------------------------------------------
n_2017_in_window_orders = len(step2[
    (step2["purchase_dt"] >= pd.Timestamp("2017-01-01")) &
    (step2["purchase_dt"] <  pd.Timestamp("2018-01-01"))
])
n_2018_in_window_orders = len(step2[
    (step2["purchase_dt"] >= pd.Timestamp("2018-01-01")) &
    (step2["purchase_dt"] <  pd.Timestamp("2018-09-01"))
])
n_2016_and_2018_tail_raw = n_raw - n_2017_in_window_orders - n_2018_in_window_orders
n_2017_to_2018_in_window_all_statuses = int(
    ((orders["purchase_dt"] >= WINDOW_START) & (orders["purchase_dt"] < WINDOW_END)).sum()
)

# ------------------------------------------------------------------
# Assemble JSON
# ------------------------------------------------------------------
totals = {
    "generated_at": str(pd.Timestamp.now()),
    "dataset": {
        "raw_orders":                n_raw,
        "raw_customers":             int(len(customers)),
        "raw_items_rows":            int(len(items)),
        "raw_payments_rows":         int(len(payments)),
    },
    "funnel": {
        "raw_orders":                n_raw,
        "in_scope_status":           n_in_scope,
        "in_scope_and_in_window":    n_in_window,
        "analytic_population":       n_population,
    },
    "revenue_on_population": {
        "gmv_item_price_only":       gmv,
        "freight_charged":           freight_charged,
        "total_customer_paid":       total_paid,
    },
    "payments_reconciliation": {
        "payments_total":            payment_total,
        "items_total":               item_total,
        "net_residual":              net_residual,
        "absolute_residual":         abs_residual,
        "orders_exact_match":        n_exact_match,
        "orders_with_diff":          len(merged) - n_exact_match,
        "orders_compared":           len(merged),
    },
    "customers": {
        "unique_customers_all_statuses":  unique_customers,
        "repeat_customers_all_statuses":  repeat_customers,
        "repeat_rate_all_statuses_pct":   repeat_rate_all,
        "unique_customers_in_scope":      unique_customers_scope,
        "repeat_customers_in_scope":      repeat_customers_scope,
        "repeat_rate_in_scope_pct":       repeat_rate_scope,
    },
    "late_rate": {
        "denominator":               n_late_denominator,
        "late_orders":               n_late,
        "late_rate_pct":             late_rate,
    },
    "excluded_statuses": {
        "payments_total":            excluded_payments_total,
    },
    "year_splits": {
        "in_window_orders_2017":     int(n_2017_in_window_orders),
        "in_window_orders_2018":     int(n_2018_in_window_orders),
        "in_window_orders_2017_2018_all_statuses": n_2017_to_2018_in_window_all_statuses,
    },
}

OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
OUT_JSON.write_text(json.dumps(totals, indent=2), encoding="utf-8")

# ------------------------------------------------------------------
# Markdown table
# ------------------------------------------------------------------
md = []
md.append("# Control Totals — Olist Analytics\n")
md.append(f"**Generated:** {totals['generated_at']}")
md.append(f"**Source:** `python/control_totals.py` (re-runnable)")
md.append(f"**JSON:** `documentation/control_totals.json`")
md.append("")
md.append("> Every number in this file is derived from the raw CSVs by script.")
md.append("> No value is hand-entered. Any SQL layer that this project builds")
md.append("> must reproduce these totals exactly. Discrepancies are bugs.")
md.append("")
md.append("---\n")

def section(title, rows):
    md.append(f"## {title}\n")
    md.append("| Metric | Value |")
    md.append("|--------|------:|")
    for k, v in rows:
        if isinstance(v, float):
            v = f"`BRL {v:,.2f}`" if "BRL" in k or "revenue" in title.lower() or "paid" in k or "residual" in k or "total" in k else f"{v:,.4f}".rstrip("0").rstrip(".")
        elif isinstance(v, int):
            v = f"{v:,}"
        md.append(f"| {k} | {v} |")
    md.append("")

section("Dataset", [
    ("Raw orders", totals["dataset"]["raw_orders"]),
    ("Raw customers", totals["dataset"]["raw_customers"]),
    ("Raw order_items rows", totals["dataset"]["raw_items_rows"]),
    ("Raw payments rows", totals["dataset"]["raw_payments_rows"]),
])

section("Order Funnel", [
    ("Step 0 — Raw orders", totals["funnel"]["raw_orders"]),
    ("Step 1 — In-scope status", totals["funnel"]["in_scope_status"]),
    ("Step 2 — In-scope and in-window", totals["funnel"]["in_scope_and_in_window"]),
    ("Step 3 — Analytic population", totals["funnel"]["analytic_population"]),
])

section("Revenue on Analytic Population", [
    ("GMV (item price only)", totals["revenue_on_population"]["gmv_item_price_only"]),
    ("Freight Charged", totals["revenue_on_population"]["freight_charged"]),
    ("Total Customer Paid", totals["revenue_on_population"]["total_customer_paid"]),
])

section("Payments Reconciliation", [
    ("Payments total", totals["payments_reconciliation"]["payments_total"]),
    ("Items total", totals["payments_reconciliation"]["items_total"]),
    ("Net residual", totals["payments_reconciliation"]["net_residual"]),
    ("Absolute residual", totals["payments_reconciliation"]["absolute_residual"]),
    ("Orders exact match", totals["payments_reconciliation"]["orders_exact_match"]),
    ("Orders with diff", totals["payments_reconciliation"]["orders_with_diff"]),
    ("Orders compared", totals["payments_reconciliation"]["orders_compared"]),
])

section("Customers", [
    ("Unique customers (all statuses)", totals["customers"]["unique_customers_all_statuses"]),
    ("Repeat customers (all statuses)", totals["customers"]["repeat_customers_all_statuses"]),
    ("Repeat rate % (all statuses)", totals["customers"]["repeat_rate_all_statuses_pct"]),
    ("Unique customers (in-scope statuses)", totals["customers"]["unique_customers_in_scope"]),
    ("Repeat customers (in-scope statuses)", totals["customers"]["repeat_customers_in_scope"]),
    ("Repeat rate % (in-scope statuses)", totals["customers"]["repeat_rate_in_scope_pct"]),
])

section("Late Rate", [
    ("Late rate denominator", totals["late_rate"]["denominator"]),
    ("Late orders", totals["late_rate"]["late_orders"]),
    ("Late rate %", totals["late_rate"]["late_rate_pct"]),
])

section("Excluded Statuses", [
    ("Payments on canceled / unavailable / created", totals["excluded_statuses"]["payments_total"]),
])

section("Year Splits", [
    ("In-window orders 2017 (in-scope)", totals["year_splits"]["in_window_orders_2017"]),
    ("In-window orders 2018 (in-scope)", totals["year_splits"]["in_window_orders_2018"]),
    ("In-window orders 2017+2018 (all statuses)", totals["year_splits"]["in_window_orders_2017_2018_all_statuses"]),
])

OUT_MD.write_text("\n".join(md), encoding="utf-8")

# ------------------------------------------------------------------
# Console summary
# ------------------------------------------------------------------
print(json.dumps(totals, indent=2))
print(f"\n✅ Written: {OUT_JSON}")
print(f"✅ Written: {OUT_MD}")