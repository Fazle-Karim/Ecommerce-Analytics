# Data Quality Log — Olist Dataset

**Analyst:** Fazle Karim
**Date:** October 2026
**Dataset:** Olist Brazilian E-commerce (Kaggle)
**Status:** Initial profiling complete — findings below drive all downstream cleaning decisions.

---

## 1. Row Counts & Referential Integrity

| Table | Rows | Columns | Duplicate rows | Notes |
|-------|-----:|--------:|---------------:|-------|
| orders | 99,441 | 8 | 0 | Clean key (order_id unique) |
| order_items | 112,650 | 7 | 0 | 13,209 more rows than orders → multi-item orders |
| payments | 103,886 | 5 | 0 | 4,445 more rows than orders → split payments |
| reviews | 99,224 | 7 | 0 | 217 fewer than orders; 814 dup review_id |
| customers | 99,441 | 5 | 0 | Matches orders 1:1 on customer_id |
| sellers | 3,095 | 4 | 0 | Clean |
| products | 32,951 | 9 | 0 | 610 rows with missing category + dims |
| geolocation | 1,000,163 | 5 | 261,831 | Only 19,015 unique zips → 98% reduction possible |
| category_translation | 71 | 2 | 0 | 2 categories in products have no translation |

**Referential integrity: 100% clean across all 6 foreign-key relationships.**

| Relationship | Orphan rows |
|--------------|-------------|
| order_items.order_id → orders.order_id | 0 |
| payments.order_id → orders.order_id | 0 |
| reviews.order_id → orders.order_id | 0 |
| orders.customer_id → customers.customer_id | 0 |
| order_items.product_id → products.product_id | 0 |
| order_items.seller_id → sellers.seller_id | 0 |

---

## 2. Customer Identity — The Critical Trap

| Metric | Value |
|--------|------:|
| Unique `customer_id` | 99,441 |
| Unique `customer_unique_id` | 96,096 |
| Ratio (orders per real person) | 1.03 |

**Finding:** Only **3,345 customers (3.4%)** placed more than one order.
**Implication:** RFM and cohort analysis MUST use `customer_unique_id`. Using
`customer_id` would show a 100% one-time-buyer rate — technically true per
order, but analytically useless.

**This is the single most important data-quality note in this project.**

---

## 3. Payments

| Metric | Value |
|--------|------:|
| Orders with exactly 1 payment row | 96,479 (92.9%) |
| Orders with >1 payment rows | 2,961 (2.85%) |
| Max payment rows for one order | 29 |

Payment type distribution:

| Type | Count |
|------|------:|
| credit_card | 76,795 |
| boleto | 19,784 |
| voucher | 5,775 |
| debit_card | 1,529 |
| not_defined | 3 |

**Finding:** Splitting is rare but exists (one order split across 29 rows!).
**Implication:** Aggregate `payment_value` per `order_id` before joining to orders — never join at row level, or revenue will be inflated.

---

## 4. Reviews

| Metric | Value |
|--------|------:|
| Rows | 99,224 |
| Unique `review_id` | 98,410 |
| **Duplicate `review_id` rows** | **814** |
| Unique `order_id` | 98,673 |
| Orders with >1 review | 547 |

Review score distribution:

| Score | Count |
|-------|------:|
| 1★ | 11,424 |
| 2★ | 3,151 |
| 3★ | 8,179 |
| 4★ | 19,142 |
| 5★ | 57,328 |

**Finding:** 814 duplicate review_ids; 547 orders have multiple reviews.
**Implication:** Dedup by keeping the **latest review per `order_id`** (via `review_creation_date`).

Null analysis:
- `review_comment_title`: 88.3% null
- `review_comment_message`: 58.7% null
- **The score is never null.**

---

## 5. Order Statuses

| Status | Count | % |
|--------|------:|----:|
| delivered | 96,478 | 97.02% |
| shipped | 1,107 | 1.11% |
| canceled | 625 | 0.63% |
| unavailable | 609 | 0.61% |
| invoiced | 314 | 0.32% |
| processing | 301 | 0.30% |
| created | 5 | 0.01% |
| approved | 2 | 0.00% |

**Decision:** GMV includes only {delivered, shipped, invoiced, processing, approved}. Excludes {canceled, unavailable, created}.
**Effective order universe: 98,202 orders.**

---

## 6. Date Coverage

**Purchase date range:** 2016-09-04 → 2018-10-17

Monthly order counts reveal **three distinct periods**:

| Period | Characteristic | Treatment |
|--------|---------------|-----------|
| 2016-09 to 2016-12 | Only 329 orders total | **Exclude from trends** — data ramp-up |
| 2017-01 to 2018-08 | 3,000–7,500 orders/month | **Primary analysis window** |
| 2018-09 to 2018-10 | Only 20 orders total | **Exclude from trends** — incomplete |

**Effective trend window: 2017-01 → 2018-08 (20 months).**

The cleanest full-year YoY comparison is **2017 vs 2018 (Jan–Aug)**.

---

## 7. Categories

| Metric | Value |
|--------|------:|
| Unique `product_category_name` in products | 73 |
| Rows in `category_translation` | 71 |
| Categories with no English translation | **2** |

Missing translations:
- `pc_gamer`
- `portateis_cozinha_e_preparadores_de_alimentos`

**Decision:** Manually translate in `02_cleaning.sql`:
- `pc_gamer` → `PC Gamer`
- `portateis_cozinha_e_preparadores_de_alimentos` → `Kitchen & Food Prep Portables`

Additionally, 610 products (1.85%) have **no category at all**. Decision:
label as `"unknown"` in the cleaned dimension.

---

## 8. Geolocation

| Metric | Value |
|--------|------:|
| Total rows | 1,000,163 |
| Unique zip prefixes | **19,015** |
| Row reduction after dedup | 98.1% |

**Finding:** Massive duplication — the same zip prefix appears hundreds of
times with slightly different lat/lng. This is normal for geolocation datasets
(one row per logged GPS ping).
**Decision:** Aggregate to **one row per `zip_code_prefix`** using the **average
lat/lng** for each prefix. Join this to `dim_geography`.

---

## 9. Minor Anomalies

- **4 order_items** have `shipping_limit_date` after 2018-12-31 (data-entry errors). Will be flagged, not removed.
- **610 products** with missing category + dims (1.85%) — will be kept with `"unknown"` category.
- **2 products** have missing physical dims but a valid category — kept.

---

## 10. Basket & Multi-Item Patterns

| Metric | Value |
|--------|------:|
| Average items per order | 1.14 |
| Max items in one order | 21 |
| Orders with 1 item | 88,863 (90.1%) |

**Implication:** Order-level and item-level metrics will be nearly identical,
but not equal. AOV (order-level) will differ slightly from items-based
metrics. Choose carefully.

---

## 11. Open Questions (Deferred)

- Do split-payment orders have different AOVs? (Analysis, not cleaning.)
- Are the 547 multi-review orders concentrated in a specific seller or period? (Later.)
- Are the 4 anomalous `shipping_limit_date` values from a single seller? (Only 4 rows; skip.)

---

## 12. Summary — What Changes Because of This Log

Every downstream cleaning decision is now traceable to a specific finding:

| Finding | Cleaning action |
|---------|-----------------|
| `customer_unique_id` is the real key | Use only this for RFM/cohorts |
| Payments split across rows | Aggregate to order level |
| 814 duplicate review_ids | Dedup, keep latest per order |
| 609 unavailable + 625 canceled | Exclude from GMV |
| 2016 & late-2018 incomplete | Exclude from trends |
| 2 categories missing translation | Manual map |
| 19,015 unique zips (from 1M) | Dedup by zip_prefix |
| 610 products missing category | Label `"unknown"` |

---

*Last updated: October 2026*
*Supersedes: all prior assumptions in `README.md`. README to be updated with verified numbers.*