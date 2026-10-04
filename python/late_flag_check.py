"""
late_flag_check.py
Purpose: Verify the assumptions behind the late-order flag before it's
         frozen into metric definitions. Answer four specific questions:
           1. Is order_estimated_delivery_date always at midnight?
           2. Do raw-timestamp vs date comparisons misclassify same-day?
           3. Do delivered orders ever have a null delivery date?
           4. Do canceled/unavailable orders have a delivery date or payment?
Output:  documentation/late_flag_check.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/late_flag_check.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

log(f"Late-flag assumptions check — {pd.Timestamp.now()}")
log("=" * 72)

orders   = load("olist_orders_dataset.csv")
payments = load("olist_order_payments_dataset.csv")

orders["purchase_dt"]       = pd.to_datetime(orders["order_purchase_timestamp"],       errors="coerce")
orders["delivered_dt"]      = pd.to_datetime(orders["order_delivered_customer_date"],  errors="coerce")
orders["estimated_dt"]      = pd.to_datetime(orders["order_estimated_delivery_date"],  errors="coerce")
payments["payment_value"]   = pd.to_numeric(payments["payment_value"], errors="coerce")

# ------------------------------------------------------------------
# Q1 — Is order_estimated_delivery_date always at midnight?
# ------------------------------------------------------------------
log("\n## Q1 — IS order_estimated_delivery_date ALWAYS AT MIDNIGHT?")

non_midnight = orders[
    orders["estimated_dt"].notna() &
    ((orders["estimated_dt"].dt.hour   != 0) |
     (orders["estimated_dt"].dt.minute != 0) |
     (orders["estimated_dt"].dt.second != 0))
]
log(f"\n  Rows with non-midnight estimated date: {len(non_midnight):,}")
log(f"  Rows with estimated date present:      {orders['estimated_dt'].notna().sum():,}")
log(f"  → Estimated date is {'ALWAYS at midnight' if len(non_midnight) == 0 else 'NOT always at midnight'}")

# ------------------------------------------------------------------
# Q2 — Do raw-timestamp vs date comparisons misclassify same-day?
# ------------------------------------------------------------------
log("\n## Q2 — RAW TIMESTAMP vs DATE COMPARISON")

delivered = orders[orders["order_status"] == "delivered"].copy()
delivered = delivered[delivered["delivered_dt"].notna() & delivered["estimated_dt"].notna()]

# Raw comparison (timestamps, naive)
delivered["late_raw"]  = delivered["delivered_dt"] > delivered["estimated_dt"]

# Date comparison (cast both to dates)
delivered["delivered_date"] = delivered["delivered_dt"].dt.normalize()
delivered["estimated_date"] = delivered["estimated_dt"].dt.normalize()
delivered["late_date"] = delivered["delivered_date"] > delivered["estimated_date"]

n_raw  = delivered["late_raw"].sum()
n_date = delivered["late_date"].sum()

log(f"\n  Delivered orders with both dates present: {len(delivered):,}")
log(f"  Late via raw timestamp comparison:        {n_raw:,}  ({n_raw/len(delivered)*100:.2f}%)")
log(f"  Late via date-only comparison:            {n_date:,}  ({n_date/len(delivered)*100:.2f}%)")
log(f"  Difference:                               {n_raw - n_date:,}")

if n_raw == n_date:
    log("  → No misclassification. Timestamp vs date comparison gives same answer.")
else:
    log(f"  → DATE comparison is correct — raw timestamp comparison overcounts by {n_raw - n_date:,}.")

# Show a sample of the misclassified rows
if n_raw != n_date:
    mis = delivered[delivered["late_raw"] != delivered["late_date"]].head(5)
    log(f"\n  Sample of misclassified rows (raw ≠ date):")
    log(mis[["order_id", "delivered_dt", "estimated_dt"]].to_string(index=False))

# ------------------------------------------------------------------
# Q3 — Do delivered orders ever have a null delivery date?
# ------------------------------------------------------------------
log("\n## Q3 — DELIVERED ORDERS WITH NULL DELIVERY DATE")

delivered_all = orders[orders["order_status"] == "delivered"]
null_deliv = delivered_all[delivered_all["delivered_dt"].isna()]

log(f"\n  Total delivered orders:           {len(delivered_all):,}")
log(f"  Delivered with null delivery date:{len(null_deliv):,}  ({len(null_deliv)/len(delivered_all)*100:.4f}%)")

if len(null_deliv) > 0:
    log(f"\n  → These must be EXCLUDED from late-rate denominator.")
    log(f"    They stay in Order Count but not in Late Rate.")
else:
    log(f"  → None. All delivered orders have a delivery date.")

# ------------------------------------------------------------------
# Q4 — Canceled/unavailable with delivery date or payment?
# ------------------------------------------------------------------
log("\n## Q4 — CANCELED / UNAVAILABLE: DELIVERY DATE OR PAYMENT?")

for status in ["canceled", "unavailable", "created"]:
    sub = orders[orders["order_status"] == status]
    n_total = len(sub)
    n_with_deliv = sub["delivered_dt"].notna().sum()
    orders_with_pay = set(payments["order_id"])
    n_with_pay = sub["order_id"].isin(orders_with_pay).sum()
    pay_sum = payments[payments["order_id"].isin(sub["order_id"])]["payment_value"].sum()

    log(f"\n  Status: {status}")
    log(f"    Total orders:                {n_total:,}")
    log(f"    With a delivery date:        {n_with_deliv:,}  ({n_with_deliv/n_total*100:.2f}%)")
    log(f"    With a payment row:          {n_with_pay:,}  ({n_with_pay/n_total*100:.2f}%)")
    log(f"    Total payments on these:     BRL {pay_sum:,.2f}")

# Cross-check: does any "canceled" order have a delivered date AND a payment?
canceled = orders[orders["order_status"] == "canceled"].copy()
canceled_with_both = canceled[
    canceled["delivered_dt"].notna() &
    canceled["order_id"].isin(payments["order_id"])
]
log(f"\n  Canceled orders with BOTH delivery date AND payment: {len(canceled_with_both):,}")

# ------------------------------------------------------------------
# Q5 — Late rate: what denominator?
# ------------------------------------------------------------------
log("\n## Q5 — PROPOSED LATE-RATE DENOMINATOR")

# In-scope, in-window, delivered only
IN_SCOPE     = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")

in_pop = orders[
    orders["order_status"].isin(IN_SCOPE) &
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END)
].copy()

delivered_pop = in_pop[in_pop["order_status"] == "delivered"]
delivered_pop_nonull = delivered_pop[delivered_pop["delivered_dt"].notna()]

log(f"\n  In-scope, in-window, delivered:              {len(delivered_pop):,}")
log(f"  Delivered with non-null delivery date:       {len(delivered_pop_nonull):,}")
log(f"  → Late Rate denominator: {len(delivered_pop_nonull):,}")

# Compute late rate on the correct population
delivered_pop_nonull = delivered_pop_nonull.copy()
delivered_pop_nonull["late_flag"] = (
    delivered_pop_nonull["delivered_dt"].dt.normalize() >
    delivered_pop_nonull["estimated_dt"].dt.normalize()
)
n_late = delivered_pop_nonull["late_flag"].sum()
log(f"  Late orders:                                 {n_late:,}")
log(f"  Late Rate:                                   {n_late/len(delivered_pop_nonull)*100:.2f}%")

log(f"\n\nLate-flag check complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")