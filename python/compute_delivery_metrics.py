"""
compute_delivery_metrics.py
Purpose: Compute the pinned values for delivery_days from raw CSVs, using
         the same floored-elapsed-days definition that the SQL will use.
         Writes two keys back into control_totals.json:
           - avg_delivery_days
           - delivery_measurable_orders
Output:  documentation/control_totals.json (updated in place)
"""

import json
import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
JSON_PATH = Path("documentation/control_totals.json")

IN_SCOPE     = {"delivered", "shipped", "invoiced", "processing", "approved"}
WINDOW_START = pd.Timestamp("2017-01-01")
WINDOW_END   = pd.Timestamp("2018-09-01")

# Load
orders = pd.read_csv(RAW / "olist_orders_dataset.csv", dtype=str, encoding="utf-8")

orders["purchase_dt"]  = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")
orders["delivered_dt"] = pd.to_datetime(orders["order_delivered_customer_date"], errors="coerce")

# Analytic population
pop = orders[
    orders["order_status"].isin(IN_SCOPE) &
    (orders["purchase_dt"] >= WINDOW_START) &
    (orders["purchase_dt"] <  WINDOW_END)
].copy()

# Measurable orders: delivered status, non-null delivery, non-negative delta
pop["is_measurable"] = (
    (pop["order_status"] == "delivered") &
    pop["delivered_dt"].notna() &
    (pop["delivered_dt"] >= pop["purchase_dt"])
)

measured = pop[pop["is_measurable"]].copy()

# Floored elapsed days (matches SQL: DATEDIFF(SECOND, ...) / 86400)
measured["delivery_seconds"] = (measured["delivered_dt"] - measured["purchase_dt"]).dt.total_seconds()
measured["delivery_days"]    = (measured["delivery_seconds"] // 86400).astype(int)

avg_delivery_days = round(measured["delivery_days"].mean(), 4)
measurable_count  = int(len(measured))

# Sanity: no negative deltas
negative = (measured["delivered_dt"] < measured["purchase_dt"]).sum()
print(f"Measurable orders: {measurable_count}")
print(f"Average delivery days (floored): {avg_delivery_days}")
print(f"Negative deltas (should be 0):   {negative}")

# Update JSON
data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
data.setdefault("delivery", {})
data["delivery"]["avg_delivery_days"]             = float(avg_delivery_days)
data["delivery"]["delivery_measurable_orders"]    = int(measurable_count)

JSON_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
print(f"\nUpdated {JSON_PATH}")