# Cleaning Reconciliation — Step 4

**Analyst:** Fazle Karim
**Date:** October 2026
**Purpose:** Prove that the clean layer reproduces the pinned control totals,
that rules were applied as specified, and that zero unparseable values
survived TRY_CONVERT.

> All expected values are sourced from `documentation/control_totals.json`.
> The test suite `sql/tests/03_cleaning_tests.sql` produces 35 checks, all
> of which pass on the current clean layer. Expected values are loaded into
> `clean.test_expected_values` from a script generated out of the JSON — no
> literal is hand-entered.

---

## 1. Row Counts

| Table | Raw Rows | Clean Rows | Delta | Reason |
|-------|---------:|-----------:|------:|--------|
| customers | 99,441 | 99,441 | 0 | Type cast only |
| sellers | 3,095 | 3,095 | 0 | Type cast only |
| geolocation | 1,000,163 | 19,015 | −981,148 | Aggregated to one row per zip prefix |
| orders | 99,441 | 99,441 | 0 | Type cast only |
| order_items | 112,650 | 112,650 | 0 | Type cast + flags |
| payments | 103,886 | 103,886 | 0 | Type cast + flags |
| category_translation | 71 | 74 | +3 | +2 overrides +1 unknown |
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
| GEOLOCATION_DEDUP | geolocation | 1,000,163 | 19,015 | 31 | Coords outside Brazil bbox filtered before averaging |
| GEOLOCATION_MISSING_COORDS | geolocation | 4 | 4 | 4 | 4 prefixes retained with NULL coords |
| ORDERS_TYPED | orders | 99,441 | 99,441 | 0 | Timestamps → DATETIME2 |
| ORDER_ITEMS_TYPED | order_items | 112,650 | 112,650 | 4 | 4 shipping_limit_date > 2018-12-31 |
| PAYMENTS_TYPED | payments | 103,886 | 103,886 | 3 | 3 `not_defined` payment types |
| CATEGORY_TRANSLATION | category_translation | 71 | 74 | 0 | +2 overrides +1 unknown +5 typo fixes + display name |
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
primary key. `review_id` is preserved but is not guaranteed to be unique
across orders — the source contains duplicate `review_id` values, and the
same `review_id` can appear on multiple orders after deduplication.
`clean.reviews` therefore has no unique constraint on `review_id`.

The exact count of distinct `review_id` values in `clean.reviews` is
available via:

    SELECT COUNT(DISTINCT review_id) FROM clean.reviews;

---

## 4. Geolocation Reduction

Raw geolocation has 1,000,163 rows. After aggregation to one row per zip
prefix, the clean table has **19,015 rows** — matching the raw distinct
zip-prefix count. No zip prefix is dropped.

**Bounding box filter:** Coordinates outside Brazil's bounding box are
excluded before averaging:

| Bounds | Range |
|--------|-------|
| Latitude | −34.0 to +5.5 |
| Longitude | −74.0 to −32.0 |

The eastern edge (−32.0) includes **Fernando de Noronha**, a Brazilian
archipelago at ~−32.42 lng.

**31 coordinate rows were filtered** for being outside the bounds
(`filtered_count` sums to 31 across all prefixes).

**4 zip prefixes** have **all** their coordinates outside the bounds. They
are retained in `clean.geolocation` with `is_coordinates_missing = 1` and
`NULL` lat/lng. Retaining them keeps the dimension complete; downstream
`LEFT JOIN`s can still find these prefixes and show coordinates as
"unavailable."

**No city or state is stored on `clean.geolocation`.** City and state
come from `clean.customers` and `clean.sellers` directly. Geolocation
provides coordinates only.

**Identity check:** `SUM(sample_count + filtered_count) = 1,000,163` — the
raw row count. Verified by the test
`geolocation.identity_raw_equals_clean_and_filtered`.

---

## 5. Category Translation

Raw has 71 translations. Clean has **74**:

- 71 base rows from `product_category_name_translation.csv`
- **+ 1** manual override: `pc_gamer` → `pc_gamer`
- **+ 1** manual override: `portateis_cozinha_e_preparadores_de_alimentos` → `kitchen_food_prep_portables`
- **+ 1** `unknown` bucket for products with no category

Each row carries a `display_name` (space-separated Title Case) and an
`is_manual_override` flag.

**5 English typos fixed in the source CSV:**

| Wrong (source) | Corrected | Portuguese name |
|----------------|-----------|-----------------|
| `fashio_female_clothing` | `fashion_female_clothing` | `fashion_roupa_feminina` |
| `costruction_tools_garden` | `construction_tools_garden` | `construcao_ferramentas_jardim` |
| `costruction_tools_tools` | `construction_tools_tools` | `construcao_ferramentas_ferramentas` |
| `home_confort` | `home_comfort` | `casa_conforto` |
| `arts_and_craftmanship` | `arts_and_craftsmanship` | `artes_e_artesanato` |

Each correction is marked with `is_manual_override = 1`. The rule is logged
as `CATEGORY_TRANSLATION`.

---

## 6. Products

Raw → clean transformations:

- `product_name_lenght` → `product_name_length` (typo fixed)
- `product_description_lenght` → `product_description_length` (typo fixed)
- All numeric columns cast to INT via `TRY_CONVERT`
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

Casting via `TRY_CONVERT` did not lose values. Clean sums equal pinned
control totals **to the cent**:

| Metric | Expected (JSON) | Actual (clean) |
|--------|----------------:|---------------:|
| `SUM(price)` | 13,591,643.70 | 13,591,643.70 |
| `SUM(freight_value)` | 2,251,909.54 | 2,251,909.54 |
| `SUM(payment_value)` | 16,008,872.12 | 16,008,872.12 |

Sum tests compare `clean.*` to the pinned values in
`clean.test_expected_values` — not to `TRY_CAST` on raw.

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

Every text → typed conversion uses `TRY_CONVERT`. Zero unparseable values
were detected in the columns where raw values existed:

| Check | Expected | Actual |
|-------|---------:|-------:|
| Non-empty `order_purchase_timestamp` that became NULL | 0 | 0 |
| Non-empty `price` that became NULL | 0 | 0 |
| Non-empty `review_score` that became NULL | 0 | 0 |

The following typed columns were also checked via the test suite and
match their expected values exactly:

- `clean.orders.order_purchase_timestamp`, `.order_approved_at`,
  `.order_delivered_carrier_date`, `.order_delivered_customer_date`,
  `.order_estimated_delivery_date`
- `clean.order_items.shipping_limit_date`, `.price`, `.freight_value`
- `clean.payments.payment_installments`, `.payment_value`
- `clean.products.product_name_length`, `.product_description_length`,
  `.product_photos_qty`, `.product_weight_g`, `.product_length_cm`,
  `.product_height_cm`, `.product_width_cm`
- `clean.reviews.review_score`, `.review_creation_date`,
  `.review_answer_timestamp`

The `TRY_CONVERT` casts did not silently drop any non-empty source value.

---

## 11. Zip Prefix Padding Evidence

Raw source zip prefixes are all 5 digits — no padding needed in practice.
The 5-digit `RIGHT('00000' + LTRIM(RTRIM(prefix)), 5)` normalization is
still applied to all three tables to make the rule explicit and to guard
against any future data where leading zeros are lost.

**Raw length distribution:**

| Table | Length | Rows |
|-------|-------:|-----:|
| raw.customers | 5 | 99,441 |
| raw.sellers | 5 | 3,095 |
| raw.geolocation | 5 | 1,000,163 |

**Clean state:** all prefixes have `LEN() = 5`. Verified by 3 tests
(`zip.customers_len5`, `zip.sellers_len5`, `zip.geolocation_len5`).

---

## 12. Foreign Keys

Zero orphan rows across the clean layer:

| Relationship | Orphans |
|--------------|--------:|
| `clean.order_items.order_id` → `clean.orders.order_id` | 0 |
| `clean.orders.customer_id` → `clean.customers.customer_id` | 0 |
| `clean.order_items.product_id` → `clean.products.product_id` | 0 |
| `clean.order_items.seller_id` → `clean.sellers.seller_id` | 0 |
| `clean.payments.order_id` → `clean.orders.order_id` | 0 |
| `clean.reviews.order_id` → `clean.orders.order_id` | 0 |

---

## 13. Test Suite Coverage

`sql/tests/03_cleaning_tests.sql` produces 35 checks:

- 9 row-count checks
- 3 sum checks (clean vs pinned JSON values)
- 3 unparseable-value checks
- 3 funnel checks
- 2 GMV and freight checks
- 3 flag-count checks
- 3 zip-length checks
- 6 foreign-key checks
- 2 geolocation identity + missing-coords checks
- 1 category integrity check (no non-null source category maps to `unknown`)

Expected values come from `clean.test_expected_values`, generated by
`python/generate_test_expected_values_sql.py` from
`documentation/control_totals.json`. No literal is hand-entered.

Test results are persisted to `clean.test_results` with a `run_id`. The
script raises a `THROW` if any test fails.

**35 PASS / 0 FAIL.**

---

## 14. Step 3 Carry-Over Status

Four items from the Step 3 review are confirmed complete:

| Item | Status | Evidence |
|------|:------:|----------|
| Sellers byte note — `C2 B4` (acute accent), not `C3` | ✅ | `load_reconciliation.md` §7 |
| Emoji preservation — direct check (SQL 294 = Python 294) | ✅ | `load_reconciliation.md` §7 |
| Per-run counts pivot in §3 | ✅ | `load_reconciliation.md` §3 |
| SQL-literal check against `control_totals.json` | ✅ | `python/check_sql_literals.py` |

The direct emoji check counted reviews containing supplementary characters
(surrogate pairs in UTF-16) in both SQL and Python. Both returned 294,
proving emoji survived the NVARCHAR load.

---

## 15. Reproducibility

To reproduce:

1. Run `sql/01_raw_tables.sql` — creates database, schemas, empty raw tables.
2. Run `sql/02_load_raw.sql` — loads 9 CSVs, logs to `raw.load_log`.
3. Run `sql/03_cleaning.sql` — builds clean layer, logs to `clean.cleaning_log`.
4. Run `sql/test_expected_values.sql` — loads 43 expected values from JSON.
5. Run `sql/tests/03_cleaning_tests.sql` — runs 35 checks.

Expected: all tests pass, all counts match the tables above.

---

*Companion files: `sql/03_cleaning.sql`, `sql/tests/03_cleaning_tests.sql`,*
*`sql/test_expected_values.sql`, `python/generate_test_expected_values_sql.py`,*
*`documentation/cleaning_test_output.txt`, `documentation/control_totals.json`.*