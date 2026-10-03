"""
repeat_and_reconcile.py
Purpose: Produce the exact numbers required by supervisor's review of Step 2.
Output:  documentation/repeat_and_reconcile.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/repeat_and_reconcile.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

log(f"Repeat & Reconcile — generated {pd.Timestamp.now()}")
log("=" * 72)

orders    = load("olist_orders_dataset.csv")
items     = load("olist_order_items_dataset.csv")
payments  = load("olist_order_payments_dataset.csv")
reviews   = load("olist_order_reviews_dataset.csv")
customers = load("olist_customers_dataset.csv")
sellers   = load("olist_sellers_dataset.csv")
products  = load("olist_products_dataset.csv")
geo       = load("olist_geolocation_dataset.csv")

# ------------------------------------------------------------------
# 1. REPEAT CUSTOMERS — the corrected number
# ------------------------------------------------------------------
log("\n## 1. REPEAT CUSTOMERS (corrected)")

# join orders -> customers on customer_id, then group by customer_unique_id
orders_cust = orders[["order_id", "customer_id", "order_status"]].merge(
    customers[["customer_id", "customer_unique_id"]],
    on="customer_id", how="left"
)

per_person = orders_cust.groupby("customer_unique_id")["order_id"].nunique()

total_customers  = per_person.shape[0]
repeat_customers = (per_person > 1).sum()
repeat_rate_pct  = repeat_customers / total_customers * 100

log(f"Total unique customers (denominator): {total_customers:,}")
log(f"Repeat customers (>1 distinct order):  {repeat_customers:,}")
log(f"Repeat rate:                           {repeat_rate_pct:.2f}%")

log(f"\nDistribution of orders per customer:")
dist = per_person.value_counts().sort_index()
for k, v in dist.items():
    log(f"  {k} order(s): {v:,} customers")

log(f"\nComparison to earlier (incorrect) figure:")
log(f"  Incorrect (row count gap): 3,345")
log(f"  Correct (this script):     {repeat_customers:,}")
log(f"  Difference:                {3345 - repeat_customers:,} fewer repeat customers than reported")

# ------------------------------------------------------------------
# 2. MULTI-ITEM ORDERS — proper order-level count
# ------------------------------------------------------------------
log("\n## 2. MULTI-ITEM ORDERS")

items_per_order = items.groupby("order_id").size()
multi_item_orders = (items_per_order > 1).sum()
total_item_orders = items_per_order.shape[0]

log(f"Total orders present in order_items:       {total_item_orders:,}")
log(f"Orders with exactly 1 item row:            {(items_per_order == 1).sum():,}")
log(f"Orders with >1 item rows (denominator):    {total_item_orders:,}")
log(f"Orders with >1 item rows:                  {multi_item_orders:,} ({multi_item_orders / total_item_orders * 100:.2f}% of item orders)")
log(f"Max items in one order:                    {items_per_order.max()}")

# ------------------------------------------------------------------
# 3. MULTI-PAYMENT ORDERS — proper order-level count
# ------------------------------------------------------------------
log("\n## 3. MULTI-PAYMENT ORDERS")

pay_per_order = payments.groupby("order_id").size()
total_paid_orders = pay_per_order.shape[0]
multi_pay_orders  = (pay_per_order > 1).sum()

log(f"Total distinct orders in payments:         {total_paid_orders:,}")
log(f"Orders with exactly 1 payment row:         {(pay_per_order == 1).sum():,}")
log(f"Orders with >1 payment rows (denominator): {total_paid_orders:,}")
log(f"Orders with >1 payment rows:               {multi_pay_orders:,} ({multi_pay_orders / total_paid_orders * 100:.2f}% of paid orders)")
log(f"Max payment rows for one order:            {pay_per_order.max()}")

# ------------------------------------------------------------------
# 4. THE MISSING-PAYMENT ORDER
# ------------------------------------------------------------------
log("\n## 4. ORDERS WITHOUT PAYMENT ROWS")

orders_set   = set(orders["order_id"])
payments_set = set(payments["order_id"])
missing_pay  = orders_set - payments_set

log(f"Total orders:                 {len(orders_set):,}")
log(f"Orders with a payment row:    {len(payments_set):,}")
log(f"Orders WITHOUT a payment row: {len(missing_pay):,}")
if missing_pay:
    sample = list(missing_pay)[:5]
    log(f"Sample order_ids: {sample}")
    # Look up status of these orders
    missing_orders = orders[orders["order_id"].isin(missing_pay)]
    log(f"\nTheir order_status distribution:")
    log(missing_orders["order_status"].value_counts().to_string())

# ------------------------------------------------------------------
# 5. ORDERS WITHOUT REVIEWS
# ------------------------------------------------------------------
log("\n## 5. ORDERS WITHOUT REVIEWS")

reviews_order_set = set(reviews["order_id"])
missing_rev = orders_set - reviews_order_set

log(f"Total orders:                 {len(orders_set):,}")
log(f"Orders with at least 1 review:{len(reviews_order_set):,}")
log(f"Orders WITHOUT any review:    {len(missing_rev):,} ({len(missing_rev)/len(orders_set)*100:.2f}% of orders)")

log(f"\nReminder: average review score is computed over reviewed orders only.")
log(f"Unreviewed orders retain NULL score in the fact table (handled in Step 4).")

# ------------------------------------------------------------------
# 6. ADDITIONAL FK CHECKS (customer zip, seller zip)
# ------------------------------------------------------------------
log("\n## 6. ADDITIONAL FOREIGN-KEY CHECKS")

geo_zips       = set(geo["geolocation_zip_code_prefix"])
cust_zips      = set(customers["customer_zip_code_prefix"])
seller_zips    = set(sellers["seller_zip_code_prefix"])

cust_no_zip_match   = cust_zips - geo_zips
seller_no_zip_match = seller_zips - geo_zips

log(f"Unique customer zips:              {len(cust_zips):,}")
log(f"Unique seller zips:                {len(seller_zips):,}")
log(f"Unique geolocation zips:           {len(geo_zips):,}")
log(f"Customer zips NOT in geolocation:  {len(cust_no_zip_match):,}")
log(f"Seller zips NOT in geolocation:    {len(seller_no_zip_match):,}")

# How many customer rows would be dropped by an INNER JOIN
cust_dropped = customers["customer_zip_code_prefix"].isin(cust_no_zip_match).sum()
log(f"\nCustomer rows that would be dropped by INNER JOIN to geolocation: {cust_dropped:,}")
log(f"  → Geography dimension must use LEFT JOIN to preserve all customers.")

# ------------------------------------------------------------------
# 7. 2018 HYPOTHESIS — is the market actually flat?
# ------------------------------------------------------------------
log("\n## 7. 2018 FLAT-OR-DOWN HYPOTHESIS")

orders["purchase_dt"] = pd.to_datetime(orders["order_purchase_timestamp"], errors="coerce")
orders["month"]       = orders["purchase_dt"].dt.to_period("M").astype(str)

# In-scope statuses
IN_SCOPE = {"delivered", "shipped", "invoiced", "processing", "approved"}
DELIVERED_ONLY = {"delivered"}

in_scope = orders[orders["order_status"].isin(IN_SCOPE)].copy()

# Attach item prices to compute monthly GMV
items_num = items.copy()
items_num["price"] = pd.to_numeric(items_num["price"], errors="coerce")
items_num["freight_value"] = pd.to_numeric(items_num["freight_value"], errors="coerce")
items_num["total_value"] = items_num["price"] + items_num["freight_value"]

items_with_month = items_num.merge(
    orders[["order_id", "month", "order_status"]],
    on="order_id", how="left"
)

items_in_scope = items_with_month[items_with_month["order_status"].isin(IN_SCOPE)]
items_delivered = items_with_month[items_with_month["order_status"].isin(DELIVERED_ONLY)]

log("\nMonthly orders (all statuses), 2017-01 through 2018-10:")
monthly_all = orders.groupby("month").size().sort_index()
log(monthly_all.to_string())

log("\nMonthly orders (in-scope statuses only):")
monthly_in_scope = in_scope.groupby("month").size().sort_index()
log(monthly_in_scope.to_string())

log("\nMonthly GMV (item price only, in-scope orders):")
gmv_by_month = items_in_scope.groupby("month")["price"].sum().sort_index()
log(gmv_by_month.round(2).to_string())

log("\nMonthly GMV (item price only, delivered orders only):")
gmv_delivered = items_delivered.groupby("month")["price"].sum().sort_index()
log(gmv_delivered.round(2).to_string())

# Focus on the 2018 story
log("\nFocus — 2018 months, orders (all statuses):")
m2018 = monthly_all[monthly_all.index.str.startswith("2018-")]
log(m2018.to_string())

# ------------------------------------------------------------------
# 8. PRICE + FREIGHT vs PAYMENTS reconciliation
# ------------------------------------------------------------------
log("\n## 8. PRICE + FREIGHT vs PAYMENTS RECONCILIATION")

# Only in-scope orders
items_in_scope_agg = (
    items_with_month[items_with_month["order_status"].isin(IN_SCOPE)]
    .groupby("order_id")
    .agg(
        item_price_total=("price", "sum"),
        freight_total=("freight_value", "sum"),
        item_plus_freight=("total_value", "sum"),
    )
)

payments_num = payments.copy()
payments_num["payment_value"] = pd.to_numeric(payments_num["payment_value"], errors="coerce")
payments_agg = (
    payments_num.groupby("order_id")["payment_value"].sum().rename("payment_total")
)

recon = items_in_scope_agg.join(payments_agg, how="outer")
recon["difference"] = recon["payment_total"] - recon["item_plus_freight"]

matched    = recon["difference"].abs() < 0.01
mismatched = ~matched

log(f"In-scope orders in reconciliation:       {len(recon):,}")
log(f"Order totals matching within 1 cent:     {matched.sum():,} ({matched.mean()*100:.2f}%)")
log(f"Order totals that differ:                {mismatched.sum():,} ({mismatched.mean()*100:.2f}%)")

log(f"\nSum of order_items (price):              R$ {items_in_scope_agg['item_price_total'].sum():,.2f}")
log(f"Sum of order_items (freight):            R$ {items_in_scope_agg['freight_total'].sum():,.2f}")
log(f"Sum of order_items (price + freight):    R$ {items_in_scope_agg['item_plus_freight'].sum():,.2f}")
log(f"Sum of payments (payment_value):         R$ {recon['payment_total'].sum():,.2f}")
log(f"Total difference (payments − items+frt): R$ {recon['difference'].sum():,.2f}")

log(f"\nDistribution of differences (top 10 by absolute value):")
top_diff = recon.reindex(recon["difference"].abs().sort_values(ascending=False).index).head(10)
log(top_diff.to_string())

# Cross-check: reconcile with price-only
log(f"\nCross-check — price only vs payments:")
log(f"  Sum of order_items (price only):       R$ {items_in_scope_agg['item_price_total'].sum():,.2f}")
log(f"  Sum of payments:                       R$ {recon['payment_total'].sum():,.2f}")
log(f"  Difference:                            R$ {recon['payment_total'].sum() - items_in_scope_agg['item_price_total'].sum():,.2f}")

# ------------------------------------------------------------------
log(f"\n\nScript complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")