"""
generate_test_expected_values_sql.py
Purpose: Read control_totals.json and emit a SQL file that creates and
         populates clean.test_expected_values with every expected value
         used by the cleaning and analytics test suites.
Output:  sql/test_expected_values.sql
"""

import json
from pathlib import Path

JSON_PATH = Path("documentation/control_totals.json")
OUT = Path("sql/test_expected_values.sql")

baseline = json.loads(JSON_PATH.read_text(encoding="utf-8"))

expected_values = []
def add(name, value):
    expected_values.append((name, value))

# ---------- Clean-layer values ----------
rl = baseline["raw_level"]
add("row_count.customers",             rl["customers_row_count"])
add("row_count.sellers",               rl["sellers_row_count"])
add("row_count.geolocation",           19015)
add("row_count.orders",                rl["orders_row_count"])
add("row_count.order_items",           rl["order_items_row_count"])
add("row_count.payments",              rl["payments_row_count"])
add("row_count.category_translation",  74)
add("row_count.products",              rl["products_row_count"])
add("row_count.reviews",               98673)

add("sum.price.raw_equals_clean",      f"{rl['raw_sum_price']:.2f}")
add("sum.freight.raw_equals_clean",    f"{rl['raw_sum_freight_value']:.2f}")
add("sum.payment.raw_equals_clean",    f"{rl['raw_sum_payment_value']:.2f}")

add("unparseable.order_purchase_timestamp", 0)
add("unparseable.price",                     0)
add("unparseable.review_score",              0)

f = baseline["funnel"]
add("funnel.raw_total",              f["raw_orders"])
add("funnel.in_scope_status",        f["in_scope_status"])
add("funnel.in_scope_and_in_window", f["in_scope_and_in_window"])

r = baseline["revenue_on_population"]
add("gmv.analytic_population",     f"{r['gmv_item_price_only']:.2f}")
add("freight.analytic_population", f"{r['freight_charged']:.2f}")

add("flags.shipping_limit_anomalies",    4)
add("flags.payments_undefined_type",     3)
add("flags.products_missing_dimensions", 2)

add("zip.customers_len5",   rl["customers_row_count"])
add("zip.sellers_len5",     rl["sellers_row_count"])
add("zip.geolocation_len5", 19015)

add("fk.order_items.order_id_in_orders",      0)
add("fk.orders.customer_id_in_customers",     0)
add("fk.order_items.product_id_in_products",  0)
add("fk.order_items.seller_id_in_sellers",    0)
add("fk.payments.order_id_in_orders",         0)
add("fk.reviews.order_id_in_orders",          0)

add("geolocation.identity_raw_equals_clean_and_filtered", rl["geolocation_row_count"])
add("geolocation.prefixes_missing_coords", 4)

add("category.no_unknown_from_nonnull_raw", 0)

# ---------- Analytics-layer values ----------
add("analytic.fact_orders",           f["in_scope_and_in_window"])            # 97905
add("analytic.excluded_orders",       1536)
add("analytic.fact_plus_excluded",    f["raw_orders"])                         # 99441

add("analytic.dim_date",              1096)
add("analytic.dim_customer",          94703)
add("analytic.dim_product",           32578)
add("analytic.dim_seller",            3029)

lr = baseline["late_rate"]
add("analytic.late_orders",           lr["late_orders"])                       # 6531
add("analytic.late_denominator",      lr["denominator"])                       # 96203
add("analytic.late_rate_pct",         f"{lr['late_rate_pct']:.2f}")            # 6.79

rv = baseline["reviews"]
add("analytic.avg_review_score",      f"{rv['average_review_score_all_orders']:.4f}")
add("analytic.avg_review_late",       f"{rv['average_review_score_delivered_in_window_late']:.4f}")
add("analytic.avg_review_on_time",    f"{rv['average_review_score_delivered_in_window_on_time']:.4f}")
add("analytic.review_late_group",     rv["late_review_count_delivered_in_window"])
add("analytic.review_on_time_group",  rv["on_time_review_count_delivered_in_window"])

pr = baseline["payments_reconciliation"]
add("analytic.payment_residual",      f"{pr['net_residual']:.2f}")
add("analytic.payment_total",         f"{pr['payments_total']:.2f}")
add("analytic.items_total",           f"{pr['items_total']:.2f}")

# Monthly window — one key per month (in-scope orders)
mw = baseline["monthly_window"]
for month, vals in mw.items():
    key = month.replace("-", "_")
    add(f"monthly.{key}.in_scope",  vals["orders_in_scope"])
    add(f"monthly.{key}.all_statuses", vals["orders_all_statuses"])
# Delivery metrics
d = baseline.get("delivery", {})
if d:
    add("delivery.avg_delivery_days",        f"{d['avg_delivery_days']:.4f}")
    add("delivery.measurable_orders",        d["delivery_measurable_orders"])
# Fact order items row count (computed in pandas from the analytic population)
# Computed independently: items whose order is in the analytic population
import pandas as _pd
_orders = _pd.read_csv("data/raw/olist_orders_dataset.csv", dtype=str, encoding="utf-8")
_orders["purchase_dt"] = _pd.to_datetime(_orders["order_purchase_timestamp"], errors="coerce")
_items  = _pd.read_csv("data/raw/olist_order_items_dataset.csv", dtype=str, encoding="utf-8")
_in_scope = {"delivered","shipped","invoiced","processing","approved"}
_pop_ids = set(
    _orders[
        _orders["order_status"].isin(_in_scope) &
        (_orders["purchase_dt"] >= _pd.Timestamp("2017-01-01")) &
        (_orders["purchase_dt"] <  _pd.Timestamp("2018-09-01"))
    ]["order_id"]
)
_fi_rows = int(_items[_items["order_id"].isin(_pop_ids)].shape[0])
add("analytic.fact_order_items_rows", _fi_rows)

# Exclusion reason breakdown
_excluded_statuses = {"canceled","unavailable","created"}
_n_out_of_scope = int((_orders["order_status"].isin(_excluded_statuses)).sum())
_n_out_of_window = int(
    (_orders["order_status"].isin(_in_scope) &
     ((_orders["purchase_dt"] < _pd.Timestamp("2017-01-01")) |
      (_orders["purchase_dt"] >= _pd.Timestamp("2018-09-01")))).sum()
)
add("excluded.out_of_scope_status", _n_out_of_scope)
add("excluded.out_of_window",      _n_out_of_window)
add("excluded.unclassified",       0)
# RFM aggregates (from control_totals.json -> rfm)
r = baseline.get("rfm", {})
if r:
    add("rfm.customer_count",             r["customer_count"])
    add("rfm.repeat_customers",           r["repeat_customers"])
    add("rfm.segment_champions",          r["segment_champions"])
    add("rfm.segment_loyal",              r["segment_loyal"])
    add("rfm.segment_at_risk",            r["segment_at_risk"])
    add("rfm.segment_new",                r["segment_new"])
    add("rfm.segment_lost",               r["segment_lost"])
    add("rfm.f_band_1",                   r["f_band_1"])
    add("rfm.f_band_2",                   r["f_band_2"])
    add("rfm.f_band_3_plus",              r["f_band_3_plus"])

# Cohort aggregates
c = baseline.get("cohort", {})
if c:
    add("cohort.matrix_rows",             c["matrix_rows"])
    add("cohort.cohort_months",           c["cohort_months"])

# ---------- Emit ----------
lines = []
lines.append("-- ===============================================================================")
lines.append("-- Script: test_expected_values.sql")
lines.append("-- GENERATED by python/generate_test_expected_values_sql.py")
lines.append("-- DO NOT EDIT BY HAND. Regenerate from control_totals.json instead.")
lines.append("-- ===============================================================================")
lines.append("")
lines.append("USE OlistAnalytics;")
lines.append("GO")
lines.append("")
lines.append("IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clean')")
lines.append("    EXEC('CREATE SCHEMA clean');")
lines.append("GO")
lines.append("")
lines.append("IF OBJECT_ID('clean.test_expected_values', 'U') IS NOT NULL")
lines.append("    DROP TABLE clean.test_expected_values;")
lines.append("GO")
lines.append("")
lines.append("CREATE TABLE clean.test_expected_values (")
lines.append("    test_name      NVARCHAR(100) NOT NULL PRIMARY KEY,")
lines.append("    expected_value NVARCHAR(50)  NOT NULL")
lines.append(");")
lines.append("GO")
lines.append("")
lines.append("INSERT INTO clean.test_expected_values (test_name, expected_value)")
lines.append("VALUES")
rows = []
for name, val in expected_values:
    rows.append(f"    (N'{name}', N'{val}')")
lines.append(",\n".join(rows) + ";")
lines.append("GO")
lines.append("")
lines.append(f"PRINT 'Loaded {len(expected_values)} expected values into clean.test_expected_values';")
lines.append("GO")

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {len(expected_values)} values to {OUT}")