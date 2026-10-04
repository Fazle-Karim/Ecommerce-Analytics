"""
order_funnel.py
Purpose: Show how the raw order count (99,441) narrows to the analytic
         population. Every step is a defensible filter, and the funnel is
         the source of truth for "how many orders does the report cover?"
Output:  documentation/order_funnel.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/order_funnel.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

log(f"Order funnel — {pd.Timestamp.now()}")
log("=" * 72)

orders = load("olist_orders_dataset.csv")
items  = load("olist_order_items_dataset.csv")

orders["purchase_dt"] = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")

IN_SCOPE = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")

order_ids_with_items = set(items["order_id"])

# Build the funnel step by step
step_0 = orders.copy()
n_0 = len(step_0)

step_1 = step_0[step_0["order_status"].isin(IN_SCOPE)]
n_1 = len(step_1)

step_2 = step_1[
    (step_1["purchase_dt"] >= WINDOW_START) &
    (step_1["purchase_dt"] <  WINDOW_END)
]
n_2 = len(step_2)

step_3 = step_2[step_2["order_id"].isin(order_ids_with_items)]
n_3 = len(step_3)

log("\n## ORDER FUNNEL")
log(f"\n  Step 0 — All orders in dataset:                          {n_0:>7,}")
log(f"  Step 1 — In-scope status (exclude canceled/unavail/created): {n_1:>7,}")
log(f"  Step 2 — Within time window 2017-01 to 2018-08:          {n_2:>7,}")
log(f"  Step 3 — Have at least one item row:                     {n_3:>7,}")

log("\n## STEP-BY-STEP DELTAS")
log(f"\n  Step 0 → Step 1:  − {n_0 - n_1:>7,} orders  (excluded statuses)")
log(f"  Step 1 → Step 2:  − {n_1 - n_2:>7,} orders  (outside time window)")
log(f"  Step 2 → Step 3:  − {n_2 - n_3:>7,} orders  (no item rows)")
log(f"  ───────────────────────────────────────")
log(f"  Total reduction:  {n_0 - n_3:>9,} orders  ({(n_0 - n_3) / n_0 * 100:.2f}%)")
log(f"  Final population: {n_3:>9,} orders  ({n_3 / n_0 * 100:.2f}% of raw)")

log("\n## INDEPENDENT VERIFICATION")
log("Compare each step to an independently computed count.")

# Independent counts
n_excluded_statuses = (~orders["order_status"].isin(IN_SCOPE)).sum()
n_outside_window = (step_1["purchase_dt"].isna() |
                    (step_1["purchase_dt"] < WINDOW_START) |
                    (step_1["purchase_dt"] >= WINDOW_END)).sum()
n_no_items = (~step_2["order_id"].isin(order_ids_with_items)).sum()

log(f"\n  Excluded statuses (recomputed):  {n_excluded_statuses:>7,}  "
    f"({'✅' if n_excluded_statuses == n_0 - n_1 else '❌'})")
log(f"  Outside time window (recomputed): {n_outside_window:>7,}  "
    f"({'✅' if n_outside_window == n_1 - n_2 else '❌'})")
log(f"  No item rows (recomputed):       {n_no_items:>7,}  "
    f"({'✅' if n_no_items == n_2 - n_3 else '❌'})")

log("\n## BREAKDOWN OF EXCLUDED STATUSES")
excluded = orders[~orders["order_status"].isin(IN_SCOPE)]
log(f"\n  {excluded['order_status'].value_counts().to_string()}")

log("\n## BREAKDOWN OF ORDERS OUTSIDE WINDOW")
outside = step_1[
    (step_1["purchase_dt"].isna()) |
    (step_1["purchase_dt"] < WINDOW_START) |
    (step_1["purchase_dt"] >= WINDOW_END)
].copy()
outside["month"] = outside["purchase_dt"].dt.to_period("M").astype(str)
log(f"\n  {outside['month'].value_counts().sort_index().to_string()}")

log("\n## ORDERS WITH NO ITEM ROWS (in-scope, in-window)")
no_items = step_2[~step_2["order_id"].isin(order_ids_with_items)]
log(f"\n  Total: {len(no_items):,}")
log(f"\n  Status breakdown:")
log(f"  {no_items['order_status'].value_counts().to_string()}")

log("\n## FINAL ANALYTIC POPULATION")
log(f"\n  {n_3:,} orders  — this is the denominator for GMV, Order Count, AOV,")
log(f"                    Items per Order, and all customer-level metrics.")

log(f"\n\nFunnel complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")