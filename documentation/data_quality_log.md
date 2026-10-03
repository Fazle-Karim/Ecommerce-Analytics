# Data Quality Log — Olist Dataset

**Analyst:** Fazle Karim
**Date:** October 2026
**Dataset:** Olist Brazilian E-commerce (Kaggle) — ~100k orders, 2016–2018
**Purpose:** Document every data-quality finding that drives downstream
cleaning and modeling decisions in this project.

> **Method:** Every number in this log is copied from reproducible Python
> scripts (`python/profile_data.py`, `python/gap_analysis.py`,
> `python/repeat_and_reconcile.py`). Raw script output is committed alongside
> this file. Every percentage states its denominator inline.

---

## 1. Row Counts & Referential Integrity

| Table | Rows | Columns | Duplicate rows |
|-------|-----:|--------:|---------------:|
| orders | 99,441 | 8 | 0 |
| order_items | 112,650 | 7 | 0 |
| payments | 103,886 | 5 | 0 |
| reviews | 99,224 | 7 | 0 |
| customers | 99,441 | 5 | 0 |
| sellers | 3,095 | 4 | 0 |
| products | 32,951 | 9 | 0 |
| geolocation | 1,000,163 | 5 | 261,831 |
| category_translation | 71 | 2 | 0 |

**Referential integrity: 100% clean across all 6 core foreign-key relationships.**

| Relationship | Orphan rows |
|--------------|------------:|
| order_items.order_id → orders.order_id | 0 |
| payments.order_id → orders.order_id | 0 |
| reviews.order_id → orders.order_id | 0 |
| orders.customer_id → customers.customer_id | 0 |
| order_items.product_id → products.product_id | 0 |
| order_items.seller_id → sellers.seller_id | 0 |

**Extended FK checks (geolocation):**

| Relationship | Result |
|--------------|-------:|
| Customer zip prefixes NOT present in geolocation | **157** |
| Seller zip prefixes NOT present in geolocation | **7** |
| Customer rows that would be dropped by INNER JOIN | **278** |

**Decision:** The geography dimension will use `LEFT JOIN` on zip prefix so no
customer or seller is silently dropped.

---

## 2. Customer Identity — The Critical Trap

| Metric | Value | Denominator |
|--------|------:|-------------|
| Unique `customer_id` | 99,441 | — |
| Unique `customer_unique_id` | 96,096 | — |
| Repeat customers (>1 distinct order) | **2,997** | 96,096 |
| Repeat rate | **3.12%** | 96,096 |

**Distribution of orders per customer:**

| Orders | Customers |
|-------:|----------:|
| 1 | 93,099 |
| 2 | 2,745 |
| 3 | 203 |
| 4 | 30 |
| 5 | 8 |
| 6 | 6 |
| 7 | 3 |
| 9 | 1 |
| 17 | 1 |

**Interpretation:** Olist is essentially a one-purchase marketplace. The
repeat rate is **3.12% of unique customers** — about 1 in 32 customers places
a second order. One outlier placed 17 orders; worth noting in the RFM
analysis but not representative of the base.

**Critical modeling note:** The dataset contains two customer identifiers.
`customer_id` is unique **per order**, while `customer_unique_id` identifies
the actual person. All RFM, cohort, and repeat-purchase analysis must use
`customer_unique_id`. Using `customer_id` would show a 100% one-time-buyer
rate and invalidate the retention analysis.

---

## 3. Payments

| Metric | Value | Denominator |
|--------|------:|-------------|
| Distinct orders in payments | 99,440 | — |
| Orders with exactly 1 payment row | 96,479 | 99,440 |
| Orders with >1 payment rows | **2,961** | 99,440 |
| Multi-payment share | **2.98%** | 99,440 |
| Max payment rows for one order | 29 | — |

**Payment type distribution:**

| Type | Count | % of payment rows |
|------|------:|------------------:|
| credit_card | 76,795 | 73.92% |
| boleto | 19,784 | 19.04% |
| voucher | 5,775 | 5.56% |
| debit_card | 1,529 | 1.47% |
| not_defined | 3 | 0.003% |

**Missing-payment order:** One order
(`bfbd0f9bdef84302105ad712db648a6c`) has **no payment row** and a status of
`delivered`. In the fact table this order will carry `payment_value = NULL`.
It will be flagged in the load reconciliation but not removed.

**Implication:** Payment values must be aggregated to order level
(`SUM(payment_value) GROUP BY order_id`) before joining to any fact table.
Joining at row level would inflate revenue for the 2.98% of split-payment
orders.

---

## 4. Reviews

| Metric | Value | Denominator |
|--------|------:|-------------|
| Rows in reviews | 99,224 | — |
| Unique `review_id` | 98,410 | — |
| Duplicate `review_id` rows | 814 | 99,224 |
| Unique `order_id` in reviews | 98,673 | — |
| Orders with >1 review | 547 | — |
| Orders with no review at all | **768** | 99,441 |
| Orders with no review — % | **0.77%** | 99,441 |

**Review score distribution (of 99,224 rows):**

| Score | Count | % |
|-------|------:|----:|
| 1★ | 11,424 | 11.51% |
| 2★ | 3,151 | 3.18% |
| 3★ | 8,179 | 8.24% |
| 4★ | 19,142 | 19.29% |
| 5★ | 57,328 | 57.78% |

**Null analysis:**

- `review_comment_title`: 88.34% null
- `review_comment_message`: 58.70% null
- `review_score`: never null

**Decision:** Deduplicate by partitioning on `order_id` only — `review_id` is
not a reliable key because it has 814 duplicate values. Within each
partition, keep the row with the most recent `review_creation_date`; ties
broken by `review_answer_timestamp DESC` so the result is deterministic.

**Interpretation notes:**

- Average review score is computed over reviewed orders only.
- The 768 orders without any review retain a NULL score in the fact table.
- The score itself is never null — missingness only affects the comment text.

---

## 5. Order Statuses

| Status | Count | % of orders |
|--------|------:|------------:|
| delivered | 96,478 | 97.02% |
| shipped | 1,107 | 1.11% |
| canceled | 625 | 0.63% |
| unavailable | 609 | 0.61% |
| invoiced | 314 | 0.32% |
| processing | 301 | 0.30% |
| created | 5 | 0.01% |
| approved | 2 | 0.00% |

**Decision:** GMV includes only
{delivered, shipped, invoiced, processing, approved}.
Excludes {canceled, unavailable, created}.

**Effective in-scope universe: 98,202 orders** (99,441 − 625 − 609 − 5).

**Naming convention:** The metric will be documented as
**"GMV (excluding canceled, unavailable, created)"** everywhere it appears.
Delivery and review metrics use **delivered orders only** (96,478).

---

## 6. Date Coverage

**Purchase date range:** 2016-09-04 → 2018-10-17
**Time axis:** `order_purchase_timestamp` throughout.

Monthly order counts reveal three regimes:

| Period | Total orders | Characteristic |
|--------|-------------:|----------------|
| 2016-09 to 2016-12 | 329 | Ramp-up — exclude from trends |
| 2017-01 to 2018-08 | 98,892 | Stable production |
| 2018-09 to 2018-10 | 20 | Incomplete tail — exclude |

**Early 2017 was slow, not steady.** Monthly orders:
Jan 800 · Feb 1,780 · Mar 2,682 · Apr 2,404 · May 3,700 · Jun 3,245 ·
Jul 4,026 · Aug 4,331 · Sep 4,285 · Oct 4,631 · Nov 7,544 · Dec 5,673.

**Effective trend window: 2017-01 → 2018-08 (20 months).**
**YoY comparison: 2017-01..08 vs 2018-01..08.**

---

## 7. Products & Categories

| Metric | Value |
|--------|------:|
| Unique `product_category_name` in products | 73 |
| Rows in `category_translation` | 71 |
| Categories with no English translation | 2 |

**Missing translations — exact snake_case values to be added:**

- `pc_gamer` → `pc_gamer`
- `portateis_cozinha_e_preparadores_de_alimentos` → `kitchen_food_prep_portables`

**Products with no category at all:** 610 (1.85% of 32,951). Label as
`unknown` (lowercase, single word) in `product_category_name`. The display
column renders it as `Unknown`.

**Implementation decision:** Preserve snake_case in the raw column; add a
separate display column that Title Cases all 73 categories consistently.
This keeps the raw data clean and lets the report consume human-readable
labels by construction.

**Products with missing physical dimensions but a valid category:** 2. Kept.

---

## 8. Geolocation

| Metric | Value | Denominator |
|--------|------:|-------------|
| Total rows | 1,000,163 | — |
| Unique zip prefixes | **19,015** | — |
| Row reduction after dedup | **98.10%** | — |

**Decision:** Aggregate to one row per `zip_code_prefix` using mean lat/lng.
Join to `dim_geography` via `LEFT JOIN` to preserve all customers and
sellers (see §1 for the 157 customer zips and 7 seller zips that have no
geolocation row).

---

## 9. Basket Size

| Metric | Value | Denominator |
|--------|------:|-------------|
| Total orders in order_items | 98,666 | — |
| Orders with exactly 1 item row | 88,863 | 98,666 |
| Orders with >1 item rows | **9,803** | 98,666 |
| Multi-item share | **9.94%** | 98,666 |
| Max items in one order | 21 | — |
| Average items per order | 1.14 | — |

**Note:** 98,666 distinct orders appear in `order_items`, but `orders` has
99,441. The remaining **775 orders have no item rows at all** — investigate
in the cleaning step (likely canceled/unavailable orders that never reached
fulfillment).

---

## 10. Payments vs Order Items — Reconciliation

Aggregated order_items and payments to order level, then compared
`SUM(payment_value)` against `SUM(price + freight_value)` on in-scope orders.

| Metric | Value |
|--------|------:|
| In-scope orders in reconciliation | 99,441 |
| Order totals matching within 1 cent | **97,822 (98.37%)** |
| Order totals that differ | 1,619 (1.63%) |

**Aggregate reconciliation:**

| Component | Amount (R$) |
|-----------|------------:|
| Sum of order_items (price only) | 13,494,400.74 |
| Sum of order_items (freight) | 2,241,126.29 |
| Sum of order_items (price + freight) | 15,735,527.03 |
| Sum of payments (payment_value) | 16,008,872.12 |
| **Total difference (payments − items + freight)** | **2,838.38** |

**Difference as % of payments: 0.018%.**

**Likely causes of the per-order differences (1,619 orders):**

- Voucher/coupon redemptions not reflected in item prices
- Rounding at payment time vs order time
- Payment adjustments (partial refunds, top-ups)

**Cross-check:** Sum of payments minus sum of item prices alone is
**R$ 2,514,471.38**. This is essentially the total freight value plus the
residual discrepancy — confirming that `payment_value` corresponds to
**price + freight**, not to price alone.

**Metric design decisions:**

- **GMV** = item price only (freight excluded).
- **Freight Revenue** tracked as a separate measure.
- **Total Customer Paid** = GMV + Freight Revenue.
- No "pass-through cost" language — the dataset has no cost data.

---

## 11. 2018 Trend Analysis — Hypothesis Tested

Hypothesis: 2018 is flat-to-slightly-down. Tested against three metrics.

**Monthly orders — 2018 (all statuses):**

| Month | Orders |
|-------|-------:|
| Jan | 7,269 |
| Feb | 6,728 |
| Mar | 7,211 |
| Apr | 6,939 |
| May | 6,873 |
| Jun | 6,167 |
| Jul | 6,292 |
| Aug | 6,512 |

**Monthly GMV (item price only, in-scope orders), 2018:**

| Month | GMV (R$) |
|-------|---------:|
| Jan | 945,456.29 |
| Feb | 837,895.43 |
| Mar | 981,051.06 |
| Apr | 993,592.98 |
| May | 992,871.75 |
| Jun | 863,265.53 |
| Jul | 878,044.27 |
| Aug | 848,860.10 |

**Verdict:** Both order volume and GMV **peak around March–May 2018** and
decline **~10–15% by August**. The decline appears in raw orders, in-scope
orders, and GMV — not just one metric. **The hypothesis holds.**

**Caveats to state in the report:**

- Only **8 months of 2018** are available.
- There is **no prior-year baseline** to distinguish decline from seasonality.
- The **+138% YoY growth** figure (Jan–Aug) is dominated by the marketplace
  ramp-up, not organic growth, and should not be headlined.

---

## 12. Summary — What Changes Because of This Log

Every downstream cleaning decision traces to a specific finding:

| Finding | Cleaning action |
|---------|-----------------|
| `customer_unique_id` is the real customer key | Use only this for RFM/cohorts |
| Repeat rate is 3.12% | Report will describe the small loyal segment carefully |
| Payments split across rows (2.98%) | Aggregate to order level before joins |
| One order has no payment row | Retain with NULL `payment_value`; flag |
| 814 duplicate `review_id` values | Dedup: partition by `order_id`, order by `review_creation_date DESC`, `review_answer_timestamp DESC` |
| 768 orders have no review | Retain with NULL score |
| 609 unavailable + 625 canceled + 5 created | Exclude from GMV |
| 2016 & late-2018 incomplete | Exclude from trends |
| 2 categories missing translation | Add snake_case translation + display column |
| 610 products missing category | Label `unknown` |
| 1M → 19,015 unique zips | Dedup by zip_prefix; `LEFT JOIN` into dims |
| 157 customer zips missing in geo | `LEFT JOIN` required; no customer dropped |
| Payment reconciliation diff = 0.018% | Price+freight matches payments; GMV is price only |

---

## 13. Data-Quality Rules Adopted

Going forward, in every SQL script, DAX measure, and report element:

1. Every percentage states its denominator inline.
2. Every number is copied from script output, not hand-calculated.
3. Every metric is defined in `documentation/metric_definitions.md` before
   it appears in a query.
4. Every cleaning decision is traceable to a specific finding in this log.

---

*Last updated: October 2026*
*Companion files: `gap_analysis.txt`, `repeat_and_reconcile.txt`,*
*`metric_definitions.md`.*