# Test Coverage — JSON Expected Values to Test Names

**Generated:** 2026-10-05 11:00:20.120933
**Source:** `python/generate_test_expected_values_sql.py` and `sql/tests/*.sql`

---

## Summary

| Metric | Count |
|--------|------:|
| Expected keys in generator | 74 |
| Referenced test names | 129 |
| Covered | 74 |
| Uncovered | 0 |
| Ghosts (referenced, not generated) | 55 |
| **Coverage** | **100.0%** |

## Ghost references

These test names are referenced but not generated:

- `cohort.active_le_size`
- `cohort.distinct_months`
- `cohort.matrix_plus_pre2017`
- `cohort.offset_0_is_100pct`
- `cohort.pre_2017_row_present`
- `cohort.pre_2017_size`
- `constraint.dim_customer.unique_unique_id`
- `constraint.dim_product.unique_product_id`
- `constraint.dim_seller.unique_seller_id`
- `constraint.fact_order_items.unique_natural`
- `constraint.fact_orders.unique_order_id`
- `delivery.no_negative_days`
- `dim_customer.row_count`
- `dim_date.row_count`
- `dim_product.row_count`
- `dim_seller.row_count`
- `excluded_orders.row_count`
- `fact_order_items.no_duplicates`
- `fact_order_items.row_count`
- `fact_orders.row_count`
- `fact_plus_excluded`
- `fk.fact_order_items.customer_key`
- `fk.fact_order_items.date_key`
- `fk.fact_order_items.order_key`
- `fk.fact_order_items.product_key`
- `fk.fact_order_items.seller_key`
- `fk.fact_orders.customer_key`
- `fk.fact_orders.date_key`
- `freight.fact_order_items`
- `gmv.fact_order_items`
- `late.denominator`
- `late.orders`
- `late.rate_pct`
- `monthly.2017_01.in_scope`
- `monthly.2017_11.in_scope`
- `monthly.2018_08.in_scope`
- `payment.residual`
- `review.avg_all_orders`
- `review.avg_late`
- `review.avg_on_time`
- `rfm.at_risk_semantics`
- `rfm.champions_semantics`
- `rfm.distinct_keys`
- `rfm.every_dim_customer_has_rfm`
- `rfm.fk_customer_key`
- `rfm.lapsed_one_time_semantics`
- `rfm.loyal_semantics`
- `rfm.recent_one_time_semantics`
- `rfm.row_count`
- `rfm.segments_sum`
- `seq.all_orders_have_seq`
- `seq.at_most_one_first_order_per_customer`
- `seq.flag_consistency`
- `seq.no_duplicate_seq_per_customer`
- `seq.no_false_first_order_from_earlier`

## Full coverage table

| Expected key | Referenced in tests |
|--------------|:-------------------:|
| `analytic.avg_review_late` | yes |
| `analytic.avg_review_on_time` | yes |
| `analytic.avg_review_score` | yes |
| `analytic.dim_customer` | yes |
| `analytic.dim_date` | yes |
| `analytic.dim_product` | yes |
| `analytic.dim_seller` | yes |
| `analytic.excluded_orders` | yes |
| `analytic.fact_order_items_rows` | yes |
| `analytic.fact_orders` | yes |
| `analytic.fact_plus_excluded` | yes |
| `analytic.items_total` | yes |
| `analytic.late_denominator` | yes |
| `analytic.late_orders` | yes |
| `analytic.late_rate_pct` | yes |
| `analytic.payment_residual` | yes |
| `analytic.payment_total` | yes |
| `analytic.review_late_group` | yes |
| `analytic.review_on_time_group` | yes |
| `category.no_unknown_from_nonnull_raw` | yes |
| `cohort.cohort_months` | yes |
| `cohort.matrix_rows` | yes |
| `cohort.pre_2017_customers` | yes |
| `delivery.avg_delivery_days` | yes |
| `delivery.delivered_before_purchase_count` | yes |
| `delivery.measurable_orders` | yes |
| `excluded.out_of_scope_status` | yes |
| `excluded.out_of_window` | yes |
| `excluded.unclassified` | yes |
| `fk.order_items.order_id_in_orders` | yes |
| `fk.order_items.product_id_in_products` | yes |
| `fk.order_items.seller_id_in_sellers` | yes |
| `fk.orders.customer_id_in_customers` | yes |
| `fk.payments.order_id_in_orders` | yes |
| `fk.reviews.order_id_in_orders` | yes |
| `flags.payments_undefined_type` | yes |
| `flags.products_missing_dimensions` | yes |
| `flags.shipping_limit_anomalies` | yes |
| `freight.analytic_population` | yes |
| `funnel.in_scope_and_in_window` | yes |
| `funnel.in_scope_status` | yes |
| `funnel.raw_total` | yes |
| `geolocation.identity_raw_equals_clean_and_filtered` | yes |
| `geolocation.prefixes_missing_coords` | yes |
| `gmv.analytic_population` | yes |
| `rfm.customer_count` | yes |
| `rfm.f_band_1` | yes |
| `rfm.f_band_2` | yes |
| `rfm.f_band_3_plus` | yes |
| `rfm.repeat_customers` | yes |
| `rfm.segment_at_risk` | yes |
| `rfm.segment_champions` | yes |
| `rfm.segment_lapsed_one_time` | yes |
| `rfm.segment_loyal` | yes |
| `rfm.segment_recent_one_time` | yes |
| `rfm.segment_unclassified` | yes |
| `row_count.category_translation` | yes |
| `row_count.customers` | yes |
| `row_count.geolocation` | yes |
| `row_count.order_items` | yes |
| `row_count.orders` | yes |
| `row_count.payments` | yes |
| `row_count.products` | yes |
| `row_count.reviews` | yes |
| `row_count.sellers` | yes |
| `sum.freight.clean_equals_pinned` | yes |
| `sum.payment.clean_equals_pinned` | yes |
| `sum.price.clean_equals_pinned` | yes |
| `unparseable.order_purchase_timestamp` | yes |
| `unparseable.price` | yes |
| `unparseable.review_score` | yes |
| `zip.customers_len5` | yes |
| `zip.geolocation_len5` | yes |
| `zip.sellers_len5` | yes |
