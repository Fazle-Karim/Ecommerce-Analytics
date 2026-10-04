"""
diagnose_reconciliation.py
Purpose: Find why two reconciliation totals disagreed by R$ 273,345.09.
         Attribute the difference to four categories and check it sums.
Output:  documentation/diagnose_reconciliation.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/diagnose_reconciliation.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

log(f"Reconciliation diagnosis — {pd.Timestamp.now()}")
log("=" * 72)

orders    = load("olist_orders_dataset.csv")
items     = load("olist_order_items_dataset.csv")
payments  = load("olist_order_payments_dataset.csv")

# ------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------
orders["purchase_dt"] = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")
items["price"]         = pd.to_numeric(items["price"],         errors="coerce")
items["freight_value"] = pd.to_numeric(items["freight_value"], errors="coerce")
items["line_total"]    = items["price"] + items["freight_value"]
payments["payment_value"] = pd.to_numeric(payments["payment_value"], errors="coerce")

IN_SCOPE     = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")   # exclusive

# ------------------------------------------------------------------
# Step 1 — Reproduce the two conflicting totals
# ------------------------------------------------------------------
log("\n## STEP 1 — REPRODUCE THE TWO TOTALS")

items_with_status = items.merge(
    orders[["order_id", "order_status", "purchase_dt"]], on="order_id", how="left"
)

items_in_scope = items_with_status[items_with_status["order_status"].isin(IN_SCOPE)]

left_total  = items_in_scope["line_total"].sum()
left_orders = items_in_scope["order_id"].nunique()

log(f"\nLEFT  (items_in_scope):")
log(f"  total  = BRL {left_total:,.2f}")
log(f"  orders = {left_orders:,}")

# Right side: payments via outer-joined recon (as in the original buggy script)
items_in_scope_agg = (
    items_in_scope.groupby("order_id")["line_total"].sum().rename("item_total")
)
payments_agg = (
    payments.groupby("order_id")["payment_value"].sum().rename("payment_total")
)
recon_outer = items_in_scope_agg.to_frame().join(payments_agg, how="outer")

right_total  = recon_outer["payment_total"].sum()
right_orders = recon_outer["payment_total"].notna().sum()

log(f"\nRIGHT (payments via outer-joined recon):")
log(f"  total  = BRL {right_total:,.2f}")
log(f"  orders = {right_orders:,}")

log(f"\nDiscrepancy to explain: BRL {right_total - left_total:,.2f}")

# ------------------------------------------------------------------
# Step 2 — Four-part attribution
# ------------------------------------------------------------------
log("\n## STEP 2 — FOUR-PART ATTRIBUTION")

orders_in_scope = orders[orders["order_status"].isin(IN_SCOPE)].copy()
orders_in_window = orders_in_scope[
    (orders_in_scope["purchase_dt"] >= WINDOW_START) &
    (orders_in_scope["purchase_dt"] <  WINDOW_END)
].copy()

order_ids_with_items = set(items["order_id"])
correct_population = set(
    orders_in_window[orders_in_window["order_id"].isin(order_ids_with_items)]["order_id"]
)

log(f"\nCorrect population (in-scope AND in-window AND has item rows):")
log(f"  {len(correct_population):,} orders")

all_order_ids = set(orders["order_id"])
orders_by_status = orders.set_index("order_id")["order_status"].to_dict()

cat_A_orders = all_order_ids - order_ids_with_items

cat_B_orders = {
    oid for oid in all_order_ids
    if oid in order_ids_with_items
    and oid not in correct_population
    and orders_by_status.get(oid) not in IN_SCOPE
}

cat_C_orders = {
    oid for oid in all_order_ids
    if oid in order_ids_with_items
    and oid not in correct_population
    and orders_by_status.get(oid) in IN_SCOPE
}

cat_D_orders = correct_population

union_ABCD = cat_A_orders | cat_B_orders | cat_C_orders | cat_D_orders
overlap = (cat_A_orders & cat_B_orders) | (cat_A_orders & cat_C_orders) | (cat_B_orders & cat_C_orders)
log(f"\nPartition check:")
log(f"  Total orders: {len(all_order_ids):,}")
log(f"  A ∪ B ∪ C ∪ D: {len(union_ABCD):,}")
log(f"  Overlaps between A/B/C: {len(overlap):,}")

def pay_total(order_set):
    return payments[payments["order_id"].isin(order_set)]["payment_value"].sum()

pay_A = pay_total(cat_A_orders)
pay_B = pay_total(cat_B_orders)
pay_C = pay_total(cat_C_orders)
pay_D = pay_total(cat_D_orders)

log(f"\nPayments attributed to each category:")
log(f"  A (no item rows):              BRL {pay_A:>15,.2f}")
log(f"  B (out-of-scope status):       BRL {pay_B:>15,.2f}")
log(f"  C (outside time window):       BRL {pay_C:>15,.2f}")
log(f"  D (correct population):        BRL {pay_D:>15,.2f}")
log(f"  ---")
log(f"  A + B + C + D:                 BRL {pay_A + pay_B + pay_C + pay_D:>15,.2f}")
log(f"  Total payments (all orders):   BRL {payments['payment_value'].sum():>15,.2f}")

items_correct = items[items["order_id"].isin(correct_population)]
items_correct_total = items_correct["line_total"].sum()

log(f"\nGenuine residual inside the correct population:")
log(f"  Payments (D):       BRL {pay_D:,.2f}")
log(f"  Items in correct:   BRL {items_correct_total:,.2f}")
log(f"  Residual:           BRL {pay_D - items_correct_total:,.2f}")
log(f"  Residual % of D:    {(pay_D - items_correct_total) / pay_D * 100:.4f}%")

# ------------------------------------------------------------------
# Step 3 — Does the attribution sum to the discrepancy?
# ------------------------------------------------------------------
log("\n## STEP 3 — DOES THE ATTRIBUTION SUM TO THE DISCREPANCY?")

items_in_scope_total = items_in_scope["line_total"].sum()

decomposed = pay_A + pay_B + pay_C + (pay_D - items_in_scope_total)
log(f"\nOriginal discrepancy (right_total - left_total): BRL {right_total - left_total:,.2f}")
log(f"Decomposed via 4-part attribution:                BRL {decomposed:,.2f}")
log(f"Difference:                                       BRL {(right_total - left_total) - decomposed:,.2f}")

if abs((right_total - left_total) - decomposed) < 0.01:
    log("\n✅ Attribution sums correctly. The gap is fully explained.")
else:
    log("\n❌ Attribution does NOT sum. There is a fifth cause to find.")

# ------------------------------------------------------------------
# Step 4 — CORRECTED residual breakdown (order-level aggregation FIRST)
# ------------------------------------------------------------------
log("\n## STEP 4 — RESIDUAL BREAKDOWN (correct population, order-level)")

# Aggregate each side to ORDER level FIRST — never join raw multi-row tables.
items_by_order = (
    items[items["order_id"].isin(correct_population)]
    .groupby("order_id")["line_total"].sum()
    .rename("item_total")
)
pay_by_order = (
    payments[payments["order_id"].isin(correct_population)]
    .groupby("order_id")["payment_value"].sum()
    .rename("payment_total")
)

# INNER join — only orders present on BOTH sides
merged = items_by_order.to_frame().join(pay_by_order, how="inner")

# Assertion: both sides must cover the same orders after the join
assert len(merged) == len(pay_by_order), (
    f"Population mismatch: merged={len(merged)} pay={len(pay_by_order)}"
)
assert len(merged) == len(items_by_order), (
    f"Population mismatch: merged={len(merged)} items={len(items_by_order)}"
)

merged["diff"]     = merged["payment_total"] - merged["item_total"]
merged["abs_diff"] = merged["diff"].abs()

log(f"\nOrders present on BOTH sides:  {len(merged):,}")
log(f"SUM(payment_total):            BRL {merged['payment_total'].sum():,.2f}")
log(f"SUM(item_total):               BRL {merged['item_total'].sum():,.2f}")
log(f"NET difference:                BRL {merged['diff'].sum():,.2f}")
log(f"SUM of absolute differences:   BRL {merged['abs_diff'].sum():,.2f}")
log(f"NET diff % of payments:        {merged['diff'].sum() / merged['payment_total'].sum() * 100:.4f}%")

# ------------------------------------------------------------------
# Step 4b — Residual breakdown by payment_type mix (order-level)
# ------------------------------------------------------------------
log("\n## STEP 4b — RESIDUAL BY PAYMENT_TYPE MIX")

# Order-level payment_type mix and max installments — aggregate BEFORE joining
pay_meta = (
    payments[payments["order_id"].isin(correct_population)]
    .groupby("order_id")
    .agg(
        types=("payment_type", lambda s: "|".join(sorted(set(s)))),
        installments=("payment_installments",
                      lambda s: int(pd.to_numeric(s, errors="coerce").max() or 0)),
    )
)

merged_meta = merged.join(pay_meta, how="left")

mix_summary = (
    merged_meta.groupby("types")
    .agg(
        orders=("diff", "count"),
        net_diff=("diff", "sum"),
        abs_diff=("abs_diff", "sum"),
    )
    .sort_values("abs_diff", ascending=False)
    .head(10)
)
log("\nTop 10 payment_type mixes by absolute residual:")
log(mix_summary.to_string())

log("\n## STEP 4c — RESIDUAL BY INSTALLMENT COUNT")

inst_summary = (
    merged_meta.groupby("installments")
    .agg(
        orders=("diff", "count"),
        net_diff=("diff", "sum"),
        abs_diff=("abs_diff", "sum"),
    )
    .sort_values("abs_diff", ascending=False)
)
log("\nAll installment levels:")
log(inst_summary.to_string())

log(f"\n\nDiagnosis complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")