# Test Reference Coverage

**Generated:** 2026-10-06 02:40:57.358479
**Sources:** `documentation/control_totals.json`, `documentation/rfm_cohorts_reference.json`

> "Referenced" means a test file contains a line naming this test. It does not
> mean the test currently passes — pass/fail is verified when the test suites run.

---

## Summary

| Metric | Count |
|--------|------:|
| JSON leaves (excluding metadata) | 165 |
| Leaves whose test is referenced in `sql/tests/*.sql` | 165 |
| **Leaves with no test reference** | **0** |

## Full leaf-by-leaf table

| Leaf | Test name | Referenced |
|------|-----------|:----------:|
| `cohort.cohort_months` | `cohort.distinct_months` | yes |
| `cohort.matrix_customers` | `cohort.matrix_plus_pre2017` | yes |
| `cohort.matrix_rows` | `cohort.matrix_rows` | yes |
| `cohort.pre_2017_customers` | `cohort.pre_2017_size` | yes |
| `customers.repeat_customers_all_statuses` | `rfm.repeat_customers` | yes |
| `customers.repeat_customers_in_population` | `rfm.repeat_customers` | yes |
| `customers.repeat_customers_in_scope` | `rfm.repeat_customers` | yes |
| `customers.repeat_rate_all_statuses_pct` | `rfm.repeat_customers` | yes |
| `customers.repeat_rate_in_population_pct` | `rfm.repeat_customers` | yes |
| `customers.repeat_rate_in_scope_pct` | `rfm.repeat_customers` | yes |
| `customers.unique_customers_all_statuses` | `rfm.row_count` | yes |
| `customers.unique_customers_in_population` | `rfm.row_count` | yes |
| `customers.unique_customers_in_scope` | `rfm.row_count` | yes |
| `delivery.avg_delivery_days` | `delivery.avg_delivery_days` | yes |
| `delivery.delivery_measurable_orders` | `delivery.measurable_orders` | yes |
| `excluded_statuses.payments_total` | `excluded.out_of_scope_status` | yes |
| `f_ge_2_total` | `rfm.repeat_customers` | yes |
| `funnel.analytic_population` | `funnel.in_scope_and_in_window` | yes |
| `funnel.in_scope_and_in_window` | `funnel.in_scope_and_in_window` | yes |
| `funnel.in_scope_status` | `funnel.in_scope_status` | yes |
| `funnel.raw_orders` | `funnel.raw_total` | yes |
| `late_rate.denominator` | `late.denominator` | yes |
| `late_rate.late_orders` | `late.orders` | yes |
| `late_rate.late_rate_pct` | `late.rate_pct` | yes |
| `monthly_window.2017-01.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-01.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-01.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-02.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-02.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-02.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-03.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-03.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-03.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-04.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-04.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-04.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-05.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-05.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-05.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-06.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-06.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-06.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-07.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-07.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-07.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-08.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-08.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-08.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-09.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-09.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-09.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-10.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-10.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-10.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-11.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-11.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-11.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2017-12.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2017-12.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2017-12.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-01.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-01.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-01.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-02.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-02.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-02.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-03.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-03.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-03.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-04.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-04.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-04.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-05.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-05.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-05.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-06.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-06.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-06.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-07.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-07.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-07.orders_in_scope` | `monthly.all_months` | yes |
| `monthly_window.2018-08.gmv_item_price_only` | `monthly.all_months` | yes |
| `monthly_window.2018-08.orders_all_statuses` | `monthly.all_months` | yes |
| `monthly_window.2018-08.orders_in_scope` | `monthly.all_months` | yes |
| `payments_reconciliation.absolute_residual` | `payment.residual` | yes |
| `payments_reconciliation.items_total` | `analytic.items_total` | yes |
| `payments_reconciliation.net_residual` | `payment.residual` | yes |
| `payments_reconciliation.orders_compared` | `payment.residual` | yes |
| `payments_reconciliation.orders_differ_one_cent` | `payment.residual` | yes |
| `payments_reconciliation.orders_exact_match` | `payment.residual` | yes |
| `payments_reconciliation.orders_with_larger_diff` | `payment.residual` | yes |
| `payments_reconciliation.orders_within_one_cent` | `payment.residual` | yes |
| `payments_reconciliation.payments_total` | `analytic.payment_total` | yes |
| `raw_level.category_translation_row_count` | `row_count.category_translation` | yes |
| `raw_level.customers_distinct_unique_id` | `rfm.distinct_keys` | yes |
| `raw_level.customers_row_count` | `row_count.customers` | yes |
| `raw_level.geolocation_row_count` | `geolocation.identity_raw_equals_clean_and_filtered` | yes |
| `raw_level.order_items_distinct_order_item` | `row_count.order_items` | yes |
| `raw_level.order_items_row_count` | `row_count.order_items` | yes |
| `raw_level.orders_distinct_order_id` | `row_count.orders` | yes |
| `raw_level.orders_row_count` | `row_count.orders` | yes |
| `raw_level.payments_row_count` | `row_count.payments` | yes |
| `raw_level.products_distinct_product_id` | `row_count.products` | yes |
| `raw_level.products_row_count` | `row_count.products` | yes |
| `raw_level.raw_sum_freight_value` | `sum.freight.clean_equals_pinned` | yes |
| `raw_level.raw_sum_payment_value` | `sum.payment.clean_equals_pinned` | yes |
| `raw_level.raw_sum_price` | `sum.price.clean_equals_pinned` | yes |
| `raw_level.reviews_row_count` | `row_count.reviews` | yes |
| `raw_level.sellers_distinct_seller_id` | `row_count.sellers` | yes |
| `raw_level.sellers_row_count` | `row_count.sellers` | yes |
| `revenue_on_population.freight_charged` | `freight.fact_order_items` | yes |
| `revenue_on_population.gmv_item_price_only` | `gmv.fact_order_items` | yes |
| `revenue_on_population.total_customer_paid` | `analytic.items_total` | yes |
| `reviews.average_review_score_all_orders` | `review.avg_all_orders` | yes |
| `reviews.average_review_score_delivered_in_window_late` | `review.avg_late` | yes |
| `reviews.average_review_score_delivered_in_window_on_time` | `review.avg_on_time` | yes |
| `reviews.late_review_count_delivered_in_window` | `analytic.review_late_group` | yes |
| `reviews.late_vs_on_time_gap_delivered_in_window` | `review.avg_late` | yes |
| `reviews.on_time_review_count_delivered_in_window` | `analytic.review_on_time_group` | yes |
| `reviews.orders_with_deduped_review_all_orders` | `review.avg_all_orders` | yes |
| `rfm.customer_count` | `rfm.row_count` | yes |
| `rfm.f_band_1` | `rfm.f_band_1` | yes |
| `rfm.f_band_2` | `rfm.f_band_2` | yes |
| `rfm.f_band_3_plus` | `rfm.f_band_3_plus` | yes |
| `rfm.repeat_customers` | `rfm.repeat_customers` | yes |
| `rfm.segment_at_risk` | `rfm.segment_at_risk` | yes |
| `rfm.segment_champions` | `rfm.segment_champions` | yes |
| `rfm.segment_lapsed_one_time` | `rfm.segment_lapsed_one_time` | yes |
| `rfm.segment_loyal` | `rfm.segment_loyal` | yes |
| `rfm.segment_recent_one_time` | `rfm.segment_recent_one_time` | yes |
| `rfm.segment_unclassified` | `rfm.segment_unclassified` | yes |
| `segments_total` | `rfm.segments_sum` | yes |
| `top_categories_gmv[0].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[0].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[0].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[1].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[1].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[1].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[2].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[2].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[2].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[3].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[3].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[3].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[4].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[4].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[4].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[5].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[5].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[5].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[6].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[6].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[6].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[7].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[7].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[7].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[8].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[8].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[8].gmv` | `top_categories.all` | yes |
| `top_categories_gmv[9].category_name_en` | `top_categories.all` | yes |
| `top_categories_gmv[9].category_name_pt` | `top_categories.all` | yes |
| `top_categories_gmv[9].gmv` | `top_categories.all` | yes |
| `year_splits.in_window_orders_2017` | `year_splits.in_window_orders_2017` | yes |
| `year_splits.in_window_orders_2017_2018_all_statuses` | `year_splits.in_window_orders_2017_2018_all_statuses` | yes |
| `year_splits.in_window_orders_2018` | `year_splits.in_window_orders_2018` | yes |
