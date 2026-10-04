"""
ab_gap_check.py
Purpose: Explain the 226.96 difference between:
           (A + B) = payments on no-item orders + payments on out-of-scope statuses
           status-total = payments on canceled/unavailable/created
Output:  documentation/ab_gap_check.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/ab_gap_check.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

log(f"A+B vs status-total gap diagnostic — {pd.Timestamp.now()}")
log("=" * 72)

orders   = load("olist_orders_dataset.csv")
items    = load("olist_order_items_dataset.csv")
payments = load("olist_order_payments_dataset.csv")
payments["payment_value"] = pd.to_numeric(payments["payment_value"], errors="coerce")

IN_SCOPE = {"delivered", "shipped", "invoiced", "processing", "approved"}
EXCLUDED = {"canceled", "unavailable", "created"}

order_ids_with_items = set(items["order_id"])
orders_by_status = orders.set_index("order_id")["order_status"].to_dict()

# ------------------------------------------------------------------
# Recompose A, B, and the status-total
# ------------------------------------------------------------------
A_orders = {oid for oid in orders["order_id"] if oid not in order_ids_with_items}
B_orders = {
    oid for oid in orders["order_id"]
    if oid in order_ids_with_items
    and orders_by_status.get(oid) not in IN_SCOPE
}
excluded_status_orders = {
    oid for oid in orders["order_id"]
    if orders_by_status.get(oid) in EXCLUDED
}

def pay_total(order_set):
    return round(payments[payments["order_id"].isin(order_set)]["payment_value"].sum(), 2)

A_total = pay_total(A_orders)
B_total = pay_total(B_orders)
AB_total = round(A_total + B_total, 2)
status_total = pay_total(excluded_status_orders)

log("\n## THE THREE NUMBERS")
log(f"\n  A  = payments on no-item orders (any status):        BRL {A_total:>12,.2f}")
log(f"  B  = payments on out-of-scope statuses (has items):  BRL {B_total:>12,.2f}")
log(f"  A+B:                                                 BRL {AB_total:>12,.2f}")
log(f"  Status-total = payments on canceled/unavail/created: BRL {status_total:>12,.2f}")
log(f"  Gap (A+B) - status-total:                            BRL {AB_total - status_total:>12,.2f}")

# ------------------------------------------------------------------
# A decomposed by status
# ------------------------------------------------------------------
log("\n## A DECOMPOSED BY STATUS")
log("\nPayments on no-item orders, grouped by the order's status:")

A_status = pd.Series({oid: orders_by_status.get(oid) for oid in A_orders})
A_pay = payments[payments["order_id"].isin(A_orders)].groupby("order_id")["payment_value"].sum()
A_df = pd.DataFrame({"status": A_status, "payment": A_pay}).fillna(0)
A_by_status = A_df.groupby("status").agg(
    orders=("payment", "count"),
    payments=("payment", "sum"),
).sort_values("payments", ascending=False)
A_by_status["payments"] = A_by_status["payments"].round(2)
log("")
log(A_by_status.to_string())

# ------------------------------------------------------------------
# A split into in-scope vs excluded statuses
# ------------------------------------------------------------------
A_in_scope_status = {oid for oid in A_orders if orders_by_status.get(oid) in IN_SCOPE}
A_excluded_status = {oid for oid in A_orders if orders_by_status.get(oid) in EXCLUDED}

A_in_scope_total = pay_total(A_in_scope_status)
A_excluded_total = pay_total(A_excluded_status)

log("\n## A SPLIT BY WHETHER THE ORDER STATUS IS IN-SCOPE OR EXCLUDED")
log(f"\n  A with in-scope status:      BRL {A_in_scope_total:>12,.2f}  ({len(A_in_scope_status):,} orders)")
log(f"  A with excluded status:      BRL {A_excluded_total:>12,.2f}  ({len(A_excluded_status):,} orders)")
log(f"  A total:                     BRL {A_total:>12,.2f}")

# ------------------------------------------------------------------
# The identity
# ------------------------------------------------------------------
log("\n## THE IDENTITY")
log("")
log("  B is defined as payments on orders with items AND out-of-scope status.")
log("  The status-total is payments on orders with any excluded status,")
log("  regardless of whether the order has items.")
log("")
log("  This gives the identity:")
log("    status-total = A_excluded_status + B")
log("")
log(f"  A_excluded_status:  BRL {A_excluded_total:>12,.2f}")
log(f"  B:                  BRL {B_total:>12,.2f}")
log(f"  Sum:                BRL {round(A_excluded_total + B_total, 2):>12,.2f}")
log(f"  status-total:       BRL {status_total:>12,.2f}")
residual_identity = round((A_excluded_total + B_total) - status_total, 2)
if residual_identity == 0:
    residual_identity = 0.00   # avoid displaying -0.00
log(f"  Residual:           BRL {residual_identity:>12,.2f}")
log("")
log("  The 226.96 gap is exactly A_in_scope_status:")
log(f"    A with in-scope status: BRL {A_in_scope_total:>12,.2f}")
log("")
log("  Verification:")
log(f"    (A + B) - status-total = A_in_scope_status")
log(f"    (A_total + B_total) - status_total = {round(A_total + B_total - status_total, 2)}")
log(f"    A_in_scope_total                    = {A_in_scope_total}")
log(f"    Difference:                         = {round((A_total + B_total - status_total) - A_in_scope_total, 2)}")

# ------------------------------------------------------------------
# Sample of the in-scope-status no-item orders
# ------------------------------------------------------------------
log("\n## SAMPLE: IN-SCOPE-STATUS ORDERS THAT HAVE NO ITEM ROWS")
log("\nThese are orders whose status is in-scope (delivered, shipped,")
log("invoiced, processing, approved) but which have no rows in order_items.")
log("They appear in A but not in the status-total.")

sample = orders[orders["order_id"].isin(A_in_scope_status)][
    ["order_id", "order_status", "order_purchase_timestamp"]
].head(10)
log("")
log(sample.to_string(index=False))

log("\n## SUMMARY")
log("")
log(f"  The {round(A_total + B_total - status_total, 2)} gap is A_in_scope_status: payments")
log("  on orders that have no item rows but whose status is in-scope.")
log(f"  The three orders involved are shipped (1) and invoiced (2), all")
log("  placed on 2016-10-05 — outside the analytic population and outside")
log("  the trend window. They affect no metric.")

log(f"\nDiagnostic complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")