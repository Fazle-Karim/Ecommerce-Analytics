"""
gap_analysis.py
Purpose: Answer the specific data quality questions the supervisor asked.
Output:  documentation/gap_analysis.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/gap_analysis.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def load(fname):
    return pd.read_csv(RAW / fname, dtype=str, encoding="utf-8")

log(f"Olist Gap Analysis — generated {pd.Timestamp.now()}")
log("=" * 70)

orders    = load("olist_orders_dataset.csv")
items     = load("olist_order_items_dataset.csv")
payments  = load("olist_order_payments_dataset.csv")
reviews   = load("olist_order_reviews_dataset.csv")
customers = load("olist_customers_dataset.csv")
sellers   = load("olist_sellers_dataset.csv")
products  = load("olist_products_dataset.csv")
geo       = load("olist_geolocation_dataset.csv")
trans     = load("product_category_name_translation.csv")

# -------- 1. Customer identity --------
log("\n## 1. CUSTOMER IDENTITY")
log(f"Unique customer_id:        {customers['customer_id'].nunique():,}")
log(f"Unique customer_unique_id: {customers['customer_unique_id'].nunique():,}")
log(f"Orders per real customer (avg): {len(orders) / customers['customer_unique_id'].nunique():.2f}")

# -------- 2. Payments --------
log("\n## 2. PAYMENTS")
pay_per_order = payments.groupby("order_id").size()
log(f"Orders with 1 payment row:  {(pay_per_order == 1).sum():,}")
log(f"Orders with >1 payment rows:{(pay_per_order > 1).sum():,} ({(pay_per_order > 1).mean() * 100:.2f}%)")
log(f"Max payment rows for one order: {pay_per_order.max()}")
log(f"\nPayment type distribution:")
log(payments['payment_type'].value_counts().to_string())

# -------- 3. Reviews --------
log("\n## 3. REVIEWS")
log(f"Rows in reviews:                    {len(reviews):,}")
log(f"Unique review_id:                   {reviews['review_id'].nunique():,}")
log(f"Duplicate review_id rows:           {len(reviews) - reviews['review_id'].nunique():,}")
log(f"Unique order_id in reviews:         {reviews['order_id'].nunique():,}")
log(f"Orders with >1 review:              {(reviews.groupby('order_id').size() > 1).sum():,}")
log(f"\nReview score distribution:")
log(reviews['review_score'].value_counts().sort_index().to_string())

# -------- 4. Order statuses --------
log("\n## 4. ORDER STATUSES")
log(orders['order_status'].value_counts().to_string())
log(f"\nStatus % of total:")
log((orders['order_status'].value_counts(normalize=True) * 100).round(2).to_string())

# -------- 5. Date coverage --------
log("\n## 5. DATE COVERAGE")
orders['purchase_dt'] = pd.to_datetime(orders['order_purchase_timestamp'], errors="coerce")
orders['year_month']  = orders['purchase_dt'].dt.to_period('M').astype(str)
log(f"Purchase date range: {orders['purchase_dt'].min()} → {orders['purchase_dt'].max()}")
log(f"\nOrders per month (top/bottom):")
monthly = orders['year_month'].value_counts().sort_index()
log(monthly.to_string())

# -------- 6. Categories --------
log("\n## 6. CATEGORIES")
log(f"Unique product_category_name in products: {products['product_category_name'].nunique()}")
log(f"Rows in category_translation:              {len(trans)}")
missing_translation = set(products['product_category_name'].dropna()) - set(trans['product_category_name'])
log(f"Categories with no English translation:    {len(missing_translation)}")
if missing_translation:
    log(f"  → {sorted(missing_translation)}")

# -------- 7. Referential integrity --------
log("\n## 7. REFERENTIAL INTEGRITY")
order_ids     = set(orders['order_id'])
cust_ids      = set(customers['customer_id'])
product_ids   = set(products['product_id'])
seller_ids    = set(sellers['seller_id'])

log(f"order_items.order_id NOT in orders:       {len(set(items['order_id']) - order_ids):,}")
log(f"payments.order_id NOT in orders:          {len(set(payments['order_id']) - order_ids):,}")
log(f"reviews.order_id NOT in orders:           {len(set(reviews['order_id']) - order_ids):,}")
log(f"orders.customer_id NOT in customers:      {len(set(orders['customer_id']) - cust_ids):,}")
log(f"order_items.product_id NOT in products:   {len(set(items['product_id']) - product_ids):,}")
log(f"order_items.seller_id NOT in sellers:     {len(set(items['seller_id']) - seller_ids):,}")

# -------- 8. Geolocation dedup --------
log("\n## 8. GEOLOCATION")
log(f"Total rows:               {len(geo):,}")
log(f"Unique zip prefixes:      {geo['geolocation_zip_code_prefix'].nunique():,}")
log(f"Row reduction after dedup: {len(geo):,} → {geo['geolocation_zip_code_prefix'].nunique():,}")

# -------- 9. Shipping limit date anomaly --------
log("\n## 9. SHIPPING LIMIT DATE ANOMALY")
items['ship_dt'] = pd.to_datetime(items['shipping_limit_date'], errors="coerce")
after_2018 = items[items['ship_dt'] > '2018-12-31']
log(f"order_items with shipping_limit_date after 2018-12-31: {len(after_2018)}")

# -------- 10. Order items per order --------
log("\n## 10. BASKET SIZE")
items_per_order = items.groupby('order_id').size()
log(f"Avg items per order:       {items_per_order.mean():.2f}")
log(f"Max items in one order:    {items_per_order.max()}")
log(f"Orders with 1 item:        {(items_per_order == 1).sum():,} ({(items_per_order == 1).mean() * 100:.1f}%)")

log("\n\nGap analysis complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")