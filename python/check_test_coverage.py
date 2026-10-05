"""
check_test_coverage.py
Purpose: For every leaf in the canonical JSON files, report:
           - the leaf path
           - the test name it maps to
           - whether a test file references that test name
         Uses an explicit LEAF_TO_TEST mapping plus an IGNORE list for
         leaves that are not test targets (data-quality diagnostics).

         "Referenced" means a test file contains a line naming this key.
         It does NOT mean the test currently passes — that is verified
         separately when the test suite runs.

Output:  documentation/test_coverage.md
Exit:    non-zero if any leaf has no test reference
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
# 1. Flatten JSON
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

all_leaves = {}
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
# 2. Explicit mapping: leaf → test name (or None for structural-only)
# ---------------------------------------------------------------------------
LEAF_TO_TEST = {
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

    "funnel.raw_orders":              "funnel.raw_total",
    "funnel.in_scope_status":         "funnel.in_scope_status",
    "funnel.in_scope_and_in_window":  "funnel.in_scope_and_in_window",
    "funnel.analytic_population":     "funnel.in_scope_and_in_window",

    "revenue_on_population.gmv_item_price_only": "gmv.fact_order_items",
    "revenue_on_population.freight_charged":     "freight.fact_order_items",
    "revenue_on_population.total_customer_paid": "analytic.items_total",

    "payments_reconciliation.payments_total":   "analytic.payment_total",
    "payments_reconciliation.items_total":      "analytic.items_total",
    "payments_reconciliation.net_residual":     "payment.residual",
    "payments_reconciliation.absolute_residual": "payment.residual",
    "payments_reconciliation.orders_exact_match":     "payment.residual",
    "payments_reconciliation.orders_differ_one_cent": "payment.residual",
    "payments_reconciliation.orders_within_one_cent": "payment.residual",
    "payments_reconciliation.orders_with_larger_diff": "payment.residual",
    "payments_reconciliation.orders_compared":        "payment.residual",

    "customers.unique_customers_all_statuses":  "rfm.row_count",
    "customers.repeat_customers_all_statuses":  "rfm.repeat_customers",
    "customers.repeat_rate_all_statuses_pct":   "rfm.repeat_customers",
    "customers.unique_customers_in_scope":      "rfm.row_count",
    "customers.repeat_customers_in_scope":      "rfm.repeat_customers",
    "customers.repeat_rate_in_scope_pct":       "rfm.repeat_customers",
    "customers.unique_customers_in_population": "rfm.row_count",
    "customers.repeat_customers_in_population": "rfm.repeat_customers",
    "customers.repeat_rate_in_population_pct":  "rfm.repeat_customers",

    "late_rate.denominator":   "late.denominator",
    "late_rate.late_orders":   "late.orders",
    "late_rate.late_rate_pct": "late.rate_pct",

    "reviews.orders_with_deduped_review_all_orders":         "review.avg_all_orders",
    "reviews.average_review_score_all_orders":               "review.avg_all_orders",
    "reviews.average_review_score_delivered_in_window_late": "review.avg_late",
    "reviews.average_review_score_delivered_in_window_on_time": "review.avg_on_time",
    "reviews.late_vs_on_time_gap_delivered_in_window":       "review.avg_late",
    "reviews.late_review_count_delivered_in_window":         "analytic.review_late_group",
    "reviews.on_time_review_count_delivered_in_window":      "analytic.review_on_time_group",

    "delivery.avg_delivery_days":          "delivery.avg_delivery_days",
    "delivery.delivery_measurable_orders": "delivery.measurable_orders",

    "excluded_statuses.payments_total": "excluded.out_of_scope_status",

    "year_splits.in_window_orders_2017":                   "year_splits.in_window_orders_2017",
    "year_splits.in_window_orders_2018":                   "year_splits.in_window_orders_2018",
    "year_splits.in_window_orders_2017_2018_all_statuses": "year_splits.in_window_orders_2017_2018_all_statuses",

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

    "cohort.matrix_rows":         "cohort.matrix_rows",
    "cohort.cohort_months":       "cohort.distinct_months",
    "cohort.pre_2017_customers":  "cohort.pre_2017_size",
    "cohort.matrix_customers":    "cohort.matrix_plus_pre2017",

    "segments_total":  "rfm.segments_sum",
    "f_ge_2_total":    "rfm.repeat_customers",
}

# Leaves that don't require a test (data-quality diagnostics; used elsewhere)
IGNORE_LEAVES = set()

def is_monthly(path):
    return path.startswith("monthly_window.")

def is_top_category(path):
    return path.startswith("top_categories_gmv[")

# ---------------------------------------------------------------------------
# 3. Derive expected test names per leaf
# ---------------------------------------------------------------------------
leaf_records = []  # (leaf, test_name, in_referenced_set)
unmapped = []

# Collect referenced test names first
referenced = set()
for tf in sorted(TESTS_DIR.glob("*.sql")):
    text = tf.read_text(encoding="utf-8")
    for m in re.findall(r"test_name\s*=\s*'([^']+)'", text):
        referenced.add(m)
    for m in re.findall(r"SELECT\s+'([a-z][a-z0-9_.]+)'\s*,", text):
        referenced.add(m)

print(f"Referenced test names: {len(referenced)}")

for path in sorted(all_leaves.keys()):
    if path in IGNORE_LEAVES:
        continue
    if is_monthly(path):
        leaf_records.append((path, "monthly.all_months", "monthly.all_months" in referenced))
        continue
    if is_top_category(path):
        leaf_records.append((path, "top_categories.all", "top_categories.all" in referenced))
        continue
    if path in LEAF_TO_TEST:
        test = LEAF_TO_TEST[path]
        leaf_records.append((path, test, test in referenced))
    else:
        unmapped.append(path)
        leaf_records.append((path, "(unmapped)", False))

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
leaves_with_test = [r for r in leaf_records if r[1] != "(unmapped)"]
leaves_with_ref  = [r for r in leaf_records if r[2]]
leaves_without_ref = [r for r in leaf_records if not r[2]]

print(f"\nLeaves with a mapped test name:      {len(leaves_with_test)}")
print(f"Leaves whose test is referenced:     {len(leaves_with_ref)}")
print(f"Leaves with NO test reference:       {len(leaves_without_ref)}")
print(f"Unmapped leaves:                     {len(unmapped)}")

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------
lines = []
lines.append("# Test Reference Coverage")
lines.append("")
lines.append(f"**Generated:** {pd.Timestamp.now()}")
lines.append(f"**Sources:** `documentation/control_totals.json`, `documentation/rfm_cohorts_reference.json`")
lines.append("")
lines.append('> "Referenced" means a test file contains a line naming this test. It does not')
lines.append("> mean the test currently passes — pass/fail is verified when the test suites run.")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"| Metric | Count |")
lines.append(f"|--------|------:|")
lines.append(f"| JSON leaves (excluding metadata) | {len(leaf_records)} |")
lines.append(f"| Leaves whose test is referenced in `sql/tests/*.sql` | {len(leaves_with_ref)} |")
lines.append(f"| **Leaves with no test reference** | **{len(leaves_without_ref)}** |")
if unmapped:
    lines.append(f"| Leaves with no mapping | {len(unmapped)} |")
lines.append("")

if leaves_without_ref:
    lines.append("## Leaves with no test reference")
    lines.append("")
    lines.append("| Leaf | Test name |")
    lines.append("|------|-----------|")
    for leaf, test, _ in leaves_without_ref:
        lines.append(f"| `{leaf}` | `{test}` |")
    lines.append("")

if unmapped:
    lines.append("## Unmapped leaves")
    lines.append("")
    lines.append("These leaves have no entry in `LEAF_TO_TEST`. Add them to the map:")
    lines.append("")
    for u in unmapped:
        lines.append(f"- `{u}`")
    lines.append("")

lines.append("## Full leaf-by-leaf table")
lines.append("")
lines.append("| Leaf | Test name | Referenced |")
lines.append("|------|-----------|:----------:|")
for leaf, test, hit in leaf_records:
    mark = "yes" if hit else "**NO**"
    lines.append(f"| `{leaf}` | `{test}` | {mark} |")
lines.append("")

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\nWrote {OUT}")

if leaves_without_ref or unmapped:
    print(f"\n❌ {len(leaves_without_ref)} leaf/leaves without a test reference, {len(unmapped)} unmapped.")
    sys.exit(1)
else:
    print(f"\n✅ All {len(leaf_records)} leaves have a referenced test.")
    sys.exit(0)