"""
check_test_coverage.py
Purpose: Verify that every *testable* leaf key in the canonical JSON files
         has a matching test reference in sql/tests/*.sql.

Uses an explicit mapping from JSON leaf → test name, plus an ignore list of
data-quality diagnostics that don't require a test.

Output:  documentation/test_coverage.md
Exit:    non-zero if any testable leaf is uncovered
"""

import json
import re
import sys
from pathlib import Path
import pandas as pd

CONTROL_JSON = Path("documentation/control_totals.json")
RFM_JSON     = Path("documentation/rfm_cohorts_reference.json")
TESTS_DIR    = Path("sql/tests")
OUT          = Path("documentation/test_coverage.md")

# ---------------------------------------------------------------------------
# 1. Load JSON and flatten
# ---------------------------------------------------------------------------
def flatten(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from flatten(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            yield from flatten(item, f"{prefix}[{i}]")
    else:
        yield prefix, obj

all_leaves = {}  # path -> value
for jf in [CONTROL_JSON, RFM_JSON]:
    if not jf.exists():
        continue
    data = json.loads(jf.read_text(encoding="utf-8"))
    for path, val in flatten(data):
        if path.endswith("generated_at"):
            continue
        all_leaves[path] = val

print(f"Total JSON leaves: {len(all_leaves)}")

# ---------------------------------------------------------------------------
# 2. Explicit mapping: JSON leaf path -> test name
#    Anything not in the mapping is either (a) in the ignore list, or
#    (b) a real gap to be tested.
# ---------------------------------------------------------------------------
LEAF_TO_TEST = {
    # raw_level
    "raw_level.orders_row_count":              "row_count.orders",
    "raw_level.order_items_row_count":         "row_count.order_items",
    "raw_level.payments_row_count":            "row_count.payments",
    "raw_level.reviews_row_count":             "row_count.reviews",
    "raw_level.customers_row_count":           "row_count.customers",
    "raw_level.sellers_row_count":             "row_count.sellers",
    "raw_level.products_row_count":            "row_count.products",
    "raw_level.geolocation_row_count":         "geolocation.identity_raw_equals_clean_and_filtered",
    "raw_level.category_translation_row_count": "row_count.category_translation",
    "raw_level.orders_distinct_order_id":      "row_count.orders",
    "raw_level.customers_distinct_unique_id":  "rfm.distinct_keys",
    "raw_level.sellers_distinct_seller_id":    "row_count.sellers",
    "raw_level.products_distinct_product_id":  "row_count.products",
    "raw_level.order_items_distinct_order_item": "row_count.order_items",
    "raw_level.raw_sum_price":                 "sum.price.clean_equals_pinned",
    "raw_level.raw_sum_freight_value":         "sum.freight.clean_equals_pinned",
    "raw_level.raw_sum_payment_value":         "sum.payment.clean_equals_pinned",

    # funnel
    "funnel.raw_orders":              "funnel.raw_total",
    "funnel.in_scope_status":         "funnel.in_scope_status",
    "funnel.in_scope_and_in_window":  "funnel.in_scope_and_in_window",
    "funnel.analytic_population":     "funnel.in_scope_and_in_window",

    # revenue
    "revenue_on_population.gmv_item_price_only": "gmv.fact_order_items",
    "revenue_on_population.freight_charged":     "freight.fact_order_items",
    "revenue_on_population.total_customer_paid": "analytic.items_total",

    # reconciliation
    "payments_reconciliation.payments_total":   "analytic.payment_total",
    "payments_reconciliation.items_total":      "analytic.items_total",
    "payments_reconciliation.net_residual":     "payment.residual",
    "payments_reconciliation.absolute_residual": "payment.residual",
    "payments_reconciliation.orders_exact_match":     "payment.residual",
    "payments_reconciliation.orders_differ_one_cent": "payment.residual",
    "payments_reconciliation.orders_within_one_cent": "payment.residual",
    "payments_reconciliation.orders_with_larger_diff": "payment.residual",
    "payments_reconciliation.orders_compared":        "payment.residual",

    # customers
    "customers.unique_customers_all_statuses":  "rfm.row_count",
    "customers.repeat_customers_all_statuses":  "rfm.repeat_customers",
    "customers.repeat_rate_all_statuses_pct":   "rfm.repeat_customers",
    "customers.unique_customers_in_scope":      "rfm.row_count",
    "customers.repeat_customers_in_scope":      "rfm.repeat_customers",
    "customers.repeat_rate_in_scope_pct":       "rfm.repeat_customers",
    "customers.unique_customers_in_population": "rfm.row_count",
    "customers.repeat_customers_in_population": "rfm.repeat_customers",
    "customers.repeat_rate_in_population_pct":  "rfm.repeat_customers",

    # late_rate
    "late_rate.denominator":   "late.denominator",
    "late_rate.late_orders":   "late.orders",
    "late_rate.late_rate_pct": "late.rate_pct",

    # reviews
    "reviews.orders_with_deduped_review_all_orders":         "review.avg_all_orders",
    "reviews.average_review_score_all_orders":               "review.avg_all_orders",
    "reviews.average_review_score_delivered_in_window_late": "review.avg_late",
    "reviews.average_review_score_delivered_in_window_on_time": "review.avg_on_time",
    "reviews.late_vs_on_time_gap_delivered_in_window":       "review.avg_late",
    "reviews.late_review_count_delivered_in_window":         "analytic.review_late_group",
    "reviews.on_time_review_count_delivered_in_window":      "analytic.review_on_time_group",

    # delivery
    "delivery.avg_delivery_days":          "delivery.avg_delivery_days",
    "delivery.delivery_measurable_orders": "delivery.measurable_orders",

    # excluded_statuses
    "excluded_statuses.payments_total": "excluded.out_of_scope_status",

    # year_splits
    "year_splits.in_window_orders_2017":                   "year_splits.in_window_orders_2017",
    "year_splits.in_window_orders_2018":                   "year_splits.in_window_orders_2018",
    "year_splits.in_window_orders_2017_2018_all_statuses": "year_splits.in_window_orders_2017_2018_all_statuses",

    # rfm
    "rfm.customer_count":           "rfm.row_count",
    "rfm.repeat_customers":         "rfm.repeat_customers",
    "rfm.segment_champions":        "rfm.segment_champions",
    "rfm.segment_loyal":            "rfm.segment_loyal",
    "rfm.segment_at_risk":          "rfm.segment_at_risk",
    "rfm.segment_recent_one_time":  "rfm.segment_recent_one_time",
    "rfm.segment_lapsed_one_time":  "rfm.segment_lapsed_one_time",
    "rfm.segment_unclassified":     "rfm.segment_unclassified",
    "rfm.f_band_1":                 "rfm.f_band_1",
    "rfm.f_band_2":                 "rfm.f_band_2",
    "rfm.f_band_3_plus":            "rfm.f_band_3_plus",

    # cohort
    "cohort.matrix_rows":         "cohort.matrix_rows",
    "cohort.cohort_months":       "cohort.distinct_months",
    "cohort.pre_2017_customers":  "cohort.pre_2017_size",
    "cohort.matrix_customers":    "cohort.matrix_plus_pre2017",

    # reference file extras
    "segments_total":  "rfm.segments_sum",
    "f_ge_2_total":    "rfm.repeat_customers",
}

# ---------------------------------------------------------------------------
# 3. Ignore list: JSON leaves that don't need a test
# ---------------------------------------------------------------------------
IGNORE_LEAVES = {
    # Individual monthly entries are covered by the aggregate monthly test
    # once it exists. Skip them from individual test checks.
}

def is_monthly(path):
    return path.startswith("monthly_window.")

def is_top_category(path):
    return path.startswith("top_categories_gmv[")

# ---------------------------------------------------------------------------
# 4. Derive expected test names
# ---------------------------------------------------------------------------
expected_keys = set()
unmapped = []
for path in all_leaves.keys():
    if path in IGNORE_LEAVES:
        continue
    if is_monthly(path):
        # Individual monthly leaves are covered by one data-driven test.
        expected_keys.add("monthly.all_months")
        continue
    if is_top_category(path):
        # Individual categories are covered by one data-driven test.
        expected_keys.add("top_categories.all")
        continue
    if path in LEAF_TO_TEST:
        expected_keys.add(LEAF_TO_TEST[path])
    else:
        unmapped.append(path)

expected_keys = sorted(expected_keys)

print(f"Expected test names: {len(expected_keys)}")
if unmapped:
    print(f"Unmapped JSON leaves (need adding to LEAF_TO_TEST or IGNORE): {len(unmapped)}")
    for u in unmapped[:20]:
        print(f"  - {u}")

# ---------------------------------------------------------------------------
# 5. Referenced test names in tests/*.sql
# ---------------------------------------------------------------------------
referenced = set()
for tf in sorted(TESTS_DIR.glob("*.sql")):
    text = tf.read_text(encoding="utf-8")
    for m in re.findall(r"test_name\s*=\s*'([^']+)'", text):
        referenced.add(m)
    for m in re.findall(r"SELECT\s+'([a-z][a-z0-9_.]+)'\s*,", text):
        referenced.add(m)

print(f"Referenced test names: {len(referenced)}")

# ---------------------------------------------------------------------------
# 6. Compare
# ---------------------------------------------------------------------------
covered = sorted(set(expected_keys) & referenced)
uncovered = sorted(set(expected_keys) - referenced)

coverage_pct = 100.0 * len(covered) / len(expected_keys) if expected_keys else 0

print(f"\nCovered:   {len(covered)}")
print(f"Uncovered: {len(uncovered)}")
print(f"Coverage:  {coverage_pct:.1f}%")

# ---------------------------------------------------------------------------
# 7. Report
# ---------------------------------------------------------------------------
lines = []
lines.append("# Test Coverage — JSON Leaves to Test Names")
lines.append("")
lines.append(f"**Generated:** {pd.Timestamp.now()}")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"| Metric | Count |")
lines.append(f"|--------|------:|")
lines.append(f"| JSON leaves | {len(all_leaves)} |")
lines.append(f"| Expected test names | {len(expected_keys)} |")
lines.append(f"| Referenced test names | {len(referenced)} |")
lines.append(f"| Covered | {len(covered)} |")
lines.append(f"| Uncovered | {len(uncovered)} |")
lines.append(f"| **Coverage** | **{coverage_pct:.1f}%** |")
lines.append("")

if unmapped:
    lines.append("## Unmapped JSON leaves")
    lines.append("")
    lines.append("These leaves have no entry in `LEAF_TO_TEST`. Add them to the map:")
    lines.append("")
    for u in unmapped:
        lines.append(f"- `{u}`")
    lines.append("")

if uncovered:
    lines.append("## Uncovered test names")
    lines.append("")
    lines.append("These test names are expected but not referenced in `sql/tests/*.sql`:")
    lines.append("")
    for k in uncovered:
        lines.append(f"- `{k}`")
    lines.append("")

lines.append("## Full mapping")
lines.append("")
lines.append("| Expected test name | Referenced |")
lines.append("|--------------------|:----------:|")
for k in expected_keys:
    hit = "yes" if k in referenced else "**NO**"
    lines.append(f"| `{k}` | {hit} |")
lines.append("")

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\nWrote {OUT}")

if uncovered or unmapped:
    print(f"\n❌ {len(uncovered)} uncovered, {len(unmapped)} unmapped.")
    sys.exit(1)
else:
    print(f"\n✅ All {len(expected_keys)} expected test names are covered.")
    sys.exit(0)