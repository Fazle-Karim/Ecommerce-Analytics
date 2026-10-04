"""
verify_control_totals.py
Purpose: Independently re-derive every value in control_totals.json from the
         raw CSVs, using different code paths where possible. Aborts if any
         value differs. This makes control_totals.json self-verifying.
Output:  documentation/control_totals_verification.txt
"""

import json
import sys
import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
JSON_PATH = Path("documentation/control_totals.json")
OUT = Path("documentation/control_totals_verification.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

# ------------------------------------------------------------------
# Load JSON baseline
# ------------------------------------------------------------------
if not JSON_PATH.exists():
    print(f"❌ {JSON_PATH} missing — run control_totals.py first")
    sys.exit(1)

baseline = json.loads(JSON_PATH.read_text(encoding="utf-8"))

log(f"Control totals verification — {pd.Timestamp.now()}")
log(f"Baseline file: {JSON_PATH}")
log("=" * 72)

# ------------------------------------------------------------------
# Load raw
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
WINDOW_END   = pd.Timestamp("2018-09-01")

# ------------------------------------------------------------------
# Independent recomputation
# ------------------------------------------------------------------
checks = []

def check(name, expected, actual, tol=0.01):
    if isinstance(expected, float) and isinstance(actual, float):
        ok = abs(expected - actual) < tol
    else:
        ok = expected == actual
    status = "✅" if ok else "❌"
    checks.append((name, expected, actual, ok))
    log(f"{status}  {name:<55} expected={expected!r:>15}  actual={actual!r:>15}")

# Dataset
check("dataset.raw_orders",       baseline["dataset"]["raw_orders"],       len(orders))
check("dataset.raw_customers",    baseline["dataset"]["raw_customers"],    len(customers))
check("dataset.raw_items_rows",   baseline["dataset"]["raw_items_rows"],   len(items))
check("dataset.raw_payments_rows",baseline["dataset"]["raw_payments_rows"],len(payments))

# Funnel
n_in_scope = int((orders["order_status"].isin(IN_SCOPE)).sum())
check("funnel.in_scope_status",
      baseline["funnel"]["in_scope_status"], n_in_scope)

n_in_window = int((
    orders["order_status"].isin(IN_SCOPE) &
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END)
).sum())
check("funnel.in_scope_and_in_window",
      baseline["funnel"]["in_scope_and_in_window"], n_in_window)

order_ids_items = set(items["order_id"])
n_pop = int((
    orders["order_status"].isin(IN_SCOPE) &
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END) &
    orders["order_id"].isin(order_ids_items)
).sum())
check("funnel.analytic_population",
      baseline["funnel"]["analytic_population"], n_pop)

# Revenue on population
population_order_ids = set(
    orders[
        orders["order_status"].isin(IN_SCOPE) &
        (orders["purchase_dt"] >= WINDOW_START) &
        (orders["purchase_dt"] <  WINDOW_END) &
        orders["order_id"].isin(order_ids_items)
    ]["order_id"]
)
items_pop = items[items["order_id"].isin(population_order_ids)]
gmv_recomp     = round(items_pop["price"].sum(), 2)
freight_recomp = round(items_pop["freight_value"].sum(), 2)
check("revenue_on_population.gmv_item_price_only",
      baseline["revenue_on_population"]["gmv_item_price_only"], gmv_recomp)
check("revenue_on_population.freight_charged",
      baseline["revenue_on_population"]["freight_charged"], freight_recomp)

# Payments reconciliation
items_by_order = items_pop.groupby("order_id")["line_total"].sum().round(2)
payments_pop = payments[payments["order_id"].isin(population_order_ids)]
payments_by_order = payments_pop.groupby("order_id")["payment_value"].sum().round(2)
merged = items_by_order.to_frame("item_total").join(
    payments_by_order.to_frame("payment_total"), how="inner")
merged["diff"] = (merged["payment_total"] - merged["item_total"]).round(2)
check("payments_reconciliation.payments_total",
      baseline["payments_reconciliation"]["payments_total"],
      round(merged["payment_total"].sum(), 2))
check("payments_reconciliation.items_total",
      baseline["payments_reconciliation"]["items_total"],
      round(merged["item_total"].sum(), 2))
check("payments_reconciliation.net_residual",
      baseline["payments_reconciliation"]["net_residual"],
      round(merged["diff"].sum(), 2))
check("payments_reconciliation.absolute_residual",
      baseline["payments_reconciliation"]["absolute_residual"],
      round(merged["diff"].abs().sum(), 2))
check("payments_reconciliation.orders_exact_match",
      baseline["payments_reconciliation"]["orders_exact_match"],
      int((merged["diff"].abs() < 0.01).sum()))
check("payments_reconciliation.orders_compared",
      baseline["payments_reconciliation"]["orders_compared"],
      len(merged))

# Customers — all statuses
orders_cust = orders[["order_id", "customer_id"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
per_person_all = orders_cust.groupby("customer_unique_id")["order_id"].nunique()
check("customers.unique_customers_all_statuses",
      baseline["customers"]["unique_customers_all_statuses"], int(len(per_person_all)))
check("customers.repeat_customers_all_statuses",
      baseline["customers"]["repeat_customers_all_statuses"], int((per_person_all > 1).sum()))
rate_all = round(int((per_person_all > 1).sum()) / len(per_person_all) * 100, 2)
check("customers.repeat_rate_all_statuses_pct",
      baseline["customers"]["repeat_rate_all_statuses_pct"], rate_all)

# Customers — in-scope
orders_cust_scope = orders[["order_id", "customer_id", "order_status"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)
orders_cust_scope = orders_cust_scope[orders_cust_scope["order_status"].isin(IN_SCOPE)]
per_person_scope = orders_cust_scope.groupby("customer_unique_id")["order_id"].nunique()
check("customers.unique_customers_in_scope",
      baseline["customers"]["unique_customers_in_scope"], int(len(per_person_scope)))
check("customers.repeat_customers_in_scope",
      baseline["customers"]["repeat_customers_in_scope"], int((per_person_scope > 1).sum()))
rate_scope = round(int((per_person_scope > 1).sum()) / len(per_person_scope) * 100, 2)
check("customers.repeat_rate_in_scope_pct",
      baseline["customers"]["repeat_rate_in_scope_pct"], rate_scope)

# Late rate
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
check("late_rate.denominator",
      baseline["late_rate"]["denominator"], int(len(late_pop)))
check("late_rate.late_orders",
      baseline["late_rate"]["late_orders"], int(late_pop["late_flag"].sum()))
check("late_rate.late_rate_pct",
      baseline["late_rate"]["late_rate_pct"],
      round(int(late_pop["late_flag"].sum()) / len(late_pop) * 100, 2))

# Excluded statuses
excluded_statuses = {"canceled", "unavailable", "created"}
excl_orders = orders[orders["order_status"].isin(excluded_statuses)]
excl_payments = payments[payments["order_id"].isin(excl_orders["order_id"])]
check("excluded_statuses.payments_total",
      baseline["excluded_statuses"]["payments_total"],
      round(excl_payments["payment_value"].sum(), 2))

# Year splits
n_2017 = int((
    (orders["purchase_dt"] >= pd.Timestamp("2017-01-01")) &
    (orders["purchase_dt"] <  pd.Timestamp("2018-01-01")) &
    orders["order_status"].isin(IN_SCOPE)
).sum())
n_2018 = int((
    (orders["purchase_dt"] >= pd.Timestamp("2018-01-01")) &
    (orders["purchase_dt"] <  pd.Timestamp("2018-09-01")) &
    orders["order_status"].isin(IN_SCOPE)
).sum())
n_all = int((
    (orders["purchase_dt"] >= pd.Timestamp("2017-01-01")) &
    (orders["purchase_dt"] <  pd.Timestamp("2018-09-01"))
).sum())

check("year_splits.in_window_orders_2017",
      baseline["year_splits"]["in_window_orders_2017"], n_2017)
check("year_splits.in_window_orders_2018",
      baseline["year_splits"]["in_window_orders_2018"], n_2018)
check("year_splits.in_window_orders_2017_2018_all_statuses",
      baseline["year_splits"]["in_window_orders_2017_2018_all_statuses"], n_all)

# ------------------------------------------------------------------
# Result
# ------------------------------------------------------------------
failures = [c for c in checks if not c[3]]
log("")
log("=" * 72)
log(f"Total checks:   {len(checks)}")
log(f"Passed:         {len(checks) - len(failures)}")
log(f"Failed:         {len(failures)}")
log("")
if failures:
    log("❌ Verification FAILED. Aborting.")
    log("")
    for name, expected, actual, _ in failures:
        log(f"  {name}: expected={expected!r}  actual={actual!r}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    sys.exit(1)
else:
    log("✅ All checks passed. control_totals.json is verified.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")