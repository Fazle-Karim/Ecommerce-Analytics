# Rebuild Evidence — Full Pipeline From Empty Database

**Purpose:** Prove the entire SQL pipeline is reproducible from scratch.
**Environment:** SQL Server 2025 Express, OlistAnalytics database.
**Date:** October 2026

---

## Method

1. Dropped the `OlistAnalytics` database entirely.
2. Ran all scripts in order from a fresh SSMS session (SQLCMD mode ON).
3. Captured row counts and key metrics before and after.

**Scripts executed in order:**

| Step | Script |
|-----:|--------|
| 1 | `sql/01_raw_tables.sql` |
| 2 | `sql/02_load_raw.sql` |
| 3 | `sql/03_cleaning.sql` |
| 4 | `sql/test_expected_values.sql` |
| 5 | `sql/tests/03_cleaning_tests.sql` |
| 6 | `sql/04_dimensions.sql` |
| 7 | `sql/05_facts.sql` |
| 8 | `sql/tests/05_facts_tests.sql` |
| 9 | `sql/06_rfm_cohorts.sql` |
| 10 | `sql/tests/06_rfm_cohorts_tests.sql` |
| 11 | `sql/07_bi_views.sql` |
| 12 | `sql/tests/08_bi_views_tests.sql` |
| 13 | `sql/load_pandas_rfm.sql` |
| 14 | `sql/test_expected_cohort.sql` |
| 15 | `sql/tests/07_pandas_compare_tests.sql` |

---

## Row Count Reconciliation

| Table | Before | After | Match |
|-------|-------:|------:|:-----:|
| raw.orders | 99,441 | 99,441 | ✅ |
| raw.order_items | 112,650 | 112,650 | ✅ |
| raw.payments | 103,886 | 103,886 | ✅ |
| raw.reviews | 99,224 | 99,224 | ✅ |
| raw.customers | 99,441 | 99,441 | ✅ |
| raw.sellers | 3,095 | 3,095 | ✅ |
| raw.products | 32,951 | 32,951 | ✅ |
| raw.geolocation | 1,000,163 | 1,000,163 | ✅ |
| raw.category_translation | 71 | 71 | ✅ |
| clean.orders | 99,441 | 99,441 | ✅ |
| clean.reviews | 98,673 | 98,673 | ✅ |
| clean.geolocation | 19,015 | 19,015 | ✅ |
| analytics.fact_orders | 97,905 | 97,905 | ✅ |
| analytics.fact_order_items | 111,752 | 111,752 | ✅ |
| analytics.customer_rfm | 94,703 | 94,703 | ✅ |
| analytics.cohort_retention | 211 | 211 | ✅ |

**All 16 row counts match.**

---

## Test Suites After Rebuild

| Suite | Result |
|-------|:------:|
| `03_cleaning_tests.sql` | 35 PASS |
| `05_facts_tests.sql` | 52 PASS |
| `06_rfm_cohorts_tests.sql` | 29 PASS |
| `08_bi_views_tests.sql` | 21 PASS |
| `07_pandas_compare_tests.sql` | 6 PASS |
| **Total** | **143 PASS / 0 FAIL** |

---

## Conclusion

The pipeline is fully reproducible from an empty database. All counts match the "before" state exactly. All 143 tests pass on the rebuilt database.

The Power BI file can safely connect to this database knowing every number is pinned and verified.