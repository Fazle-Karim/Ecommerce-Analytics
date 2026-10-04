# Cleaning Reconciliation — Step 4

**Analyst:** Fazle Karim
**Date:** October 2026
**Purpose:** Prove that the clean layer reproduces the pinned control totals,
that rules were applied as specified, and that zero unparseable values
survived TRY_CONVERT.

> All expected values are sourced from `documentation/control_totals.json`.
> The test suite `sql/tests/03_cleaning_tests.sql` produces 30 checks, all
> of which pass on the current clean layer.

---

## 1. Row Counts

| Table | Raw Rows | Clean Rows | Delta | Reason |
|-------|---------:|-----------:|------:|--------|
| customers | 99,441 | 99,441 | 0 | Type cast only |
| sellers | 3,095 | 3,095 | 0 | Type cast only |
| geolocation | 1,000,163 | 19,011 | −981,152 | Aggregated to one row per zip prefix |
| orders | 99,441 | 99,441 | 0 | Type cast only |
| order_items | 112,650 | 112,650 | 0 | Type cast + flags |
| payments | 103,886 | 103,886 | 0 | Type cast + flags |
| category_translation | 71 | 74 | +3 | + 2 manual overrides + 1 `unknown` |
| products | 32,951 | 32,951 | 0 | Type cast + rename + flags |
| reviews | 99,224 | 98,673 | −551 | Deduplicated by `order_id` |

**Two tables reduce rows (geolocation, reviews). The rest preserve raw grain.**

---

## 2. Cleaning Rules Applied

Every rule is logged in `clean.cleaning_log` with a `run_id`, `rule_id`,
and `rows_in`/`rows_out`/`rows_flagged` counts.

| rule_id | table | rows_in | rows_out | rows_flagged | Note |
|---------|-------|--------:|---------:|-------------:|------|
| CUSTOMERS_TYPED | customers | 99,441 | 99,441 | 0 | Zip padded to 5, city lower, state upper |
| SELLERS_TYPED | sellers | 3,095 | 3,095 | 0 | Same |
| GEOLOCATION_DEDUP | geolocation | 1,000,163 | 19,011 | 26 | Coordinates outside Brazil bbox filtered before averaging |
| GEOLOCATION_DROPPED_PREFIXES | geolocation | 4 | 0 | 4 | 4 prefixes had ALL coordinates outside bbox |
| ORDERS_TYPED | orders | 99,441 | 99,441 | 0 | Timestamps → DATETIME2 |
| ORDER_ITEMS_TYPED | order_items | 112,650 | 112,650 | 4 | 4 shipping_limit_date > 2018-12-31 |
| PAYMENTS_TYPED | payments | 103,886 | 103,886 | 3 | 3 `not_defined` payment types |
| CATEGORY_TRANSLATION | category_translation | 71 | 74 | 0 | + 2 overrides + 1 `unknown` + display name |
| PRODUCTS_TYPED | products | 32,951 | 32,951 | 2 | `lenght` → `length`; 2 missing dimensions |
| REVIEWS_DEDUP | reviews | 99,224 | 98,673 | 0 | 551 rows removed |

---

## 3. Review Deduplication

Reviews were deduplicated by partitioning on `order_id` and keeping one row
per order, ordered by:

1. `review_creation_date DESC`
2. `review_answer_timestamp DESC`
3. `review_id ASC` (final deterministic tiebreak)

**Result: 99,224 raw rows → 98,673 clean rows.** Exactly **551 rows removed**, matching the expected delta.

The grain of `clean.reviews` is one row per `order_id`. That column is the
primary key. `review_id` is preserved but is not unique across orders —
814 duplicate `review_id` values exist in the source, and 149 of them fall
across different orders after dedup.

---

## 4. Geolocation Reduction

Raw geolocation has 1,000,163 rows. After aggregation to one row per zip
prefix, the clean table has **19,011 rows**.

**Bounding box filter:** Coordinates outside Brazil were excluded before
averaging:

| Bounds | Range |
|--------|-------|
| Latitude | −34.0 to +5.5 |
| Longitude | −74.0 to −32.0 |

The eastern edge (−32.0) includes **Fernando de Noronha**, a Brazilian
archipelago at ~−32.42 lng. An earlier attempt with −34.0 as the eastern
edge incorrectly dropped its zip prefix.

**26 coordinate rows were filtered** for being outside the bounds. 4 zip
prefixes had ALL of their coordinates outside the bounds — they are logged
in `GEOLOCATION_DROPPED_PREFIXES`. Their zip codes do not appear in
`clean.geolocation`. Downstream joins via `LEFT JOIN` preserve customers
or sellers who might share those zips.

---

## 5. Category Translation

Raw has 71 translations. Clean has **74**:

- 71 base rows from `product_category_name_translation.csv`
- **+ 1** manual override: `pc_gamer` → `pc_gamer` (unchanged, but added because raw lacks it)
- **+ 1** manual override: `portateis_cozinha_e_preparadores_de_alimentos` → `kitchen_food_prep_portables`
- **+ 1** `unknown` bucket for products with no category

Each row carries a `display_name` (Title Case) and an `is_manual_override` flag.

---

## 6. Products

Raw → clean transformations:

- `product_name_lenght` → `product_name_length` (typo fixed)
- `product_description_lenght` → `product_description_length` (typo fixed)
- All numeric columns cast to INT via TRY_CONVERT
- Category resolved by joining to `clean.category_translation`; missing categories become `unknown`
- **2 products** have missing physical dimensions (weight, length, height, or width) — flagged, not removed

---

## 7. Anomalies Flagged (Not Deleted)

Per the decision to preserve flagged rows for analysis rather than silently delete:

| Anomaly | Count | Flag column | Table |
|---------|------:|-------------|-------|
| `shipping_limit_date` > 2018-12-31 | 4 | `flag_shipping_limit_anomaly` | clean.order_items |
| `not_defined` payment type | 3 | `flag_undefined_type` | clean.payments |
| Products missing physical dimensions | 2 | `flag_missing_dimensions` | clean.products |

---

## 8. Sums Preserved

Casting via `TRY_CONVERT` did not lose values. Clean sums equal raw sums **to the cent**:

| Metric | Raw | Clean |
|--------|----:|------:|
| `SUM(price)` | 13,591,643.70 | 13,591,643.70 |
| `SUM(freight_value)` | 2,251,909.54 | 2,251,909.54 |
| `SUM(payment_value)` | 16,008,872.12 | 16,008,872.12 |

---

## 9. Analytic Population

Reproduced from `clean.orders`:

| Step | Filter | Orders |
|------|--------|-------:|
| Raw | All | 99,441 |
| In-scope | Status in {delivered, shipped, invoiced, processing, approved} | 98,202 |
| In-window | `>= '2017-01-01' AND < '2018-09-01'` | 97,905 |

**GMV for this population:** `BRL 13,449,529.68`
**Freight for this population:** `BRL 2,234,177.06`

Both match `control_totals.json` exactly.

---

## 10. Unparseable Values

Every text → typed conversion used `TRY_CONVERT`. Zero unparseable values were detected:

| Check | Expected | Actual |
|-------|---------:|-------:|
| Non-empty `order_purchase_timestamp` that became NULL | 0 | 0 |
| Non-empty `price` that became NULL | 0 | 0 |
| Non-empty `review_score` that became NULL | 0 | 0 |

---

## 11. Zip Prefix Normalization

All zip prefixes in `clean.customers`, `clean.sellers`, and `clean.geolocation` are exactly 5 characters. This uses `RIGHT('00000' + LTRIM(RTRIM(prefix)), 5)` on all three tables, so joins by zip prefix cannot silently fail due to lost leading zeros.

Verification counts:

| Table | Rows with 5-char prefix | Total rows |
|-------|------------------------:|-----------:|
| clean.customers | 99,441 | 99,441 |
| clean.sellers | 3,095 | 3,095 |
| clean.geolocation | 19,011 | 19,011 |

---

## 12. Foreign Keys

Zero orphan rows across the clean layer:

| Relationship | Orphans |
|--------------|--------:|
| `clean.order_items.order_id` → `clean.orders.order_id` | 0 |
| `clean.orders.customer_id` → `clean.customers.customer_id` | 0 |
| `clean.order_items.product_id` → `clean.products.product_id` | 0 |
| `clean.order_items.seller_id` → `clean.sellers.seller_id` | 0 |

---

## 13. Test Suite Results

`sql/tests/03_cleaning_tests.sql` runs 30 checks. All pass:

- 9 row-count checks
- 3 sum checks
- 3 unparseable-value checks
- 3 funnel checks
- 2 GMV/freight checks
- 3 flag-count checks
- 3 zip-length checks
- 4 foreign-key checks

**30 PASS / 0 FAIL.**

Raw output saved as `documentation/cleaning_test_output.txt`.

---

## 14. Reproducibility

To reproduce:

1. Run `sql/01_raw_tables.sql` — creates database, schemas, empty raw tables.
2. Run `sql/02_load_raw.sql` — loads 9 CSVs, logs to `raw.load_log`.
3. Run `sql/03_cleaning.sql` — builds clean layer, logs to `clean.cleaning_log`.
4. Run `sql/tests/03_cleaning_tests.sql` — runs 30 checks.

Expected: all tests pass, all counts match the tables above.

---

*Companion files: `sql/03_cleaning.sql`, `sql/tests/03_cleaning_tests.sql`,*
*`documentation/cleaning_test_output.txt`, `documentation/control_totals.json`.*