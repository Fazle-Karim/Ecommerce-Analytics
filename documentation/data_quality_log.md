# Data Quality Log — Olist Dataset

**Analyst:** Fazle Karim
**Date:** October 2026
**Version:** 3.0
**Dataset:** Olist Brazilian E-commerce (Kaggle) — ~100k orders, 2016–2018
**Purpose:** Document every data-quality finding that drives downstream
cleaning and modeling decisions in this project.

> **Method:** Every number in this log is copied from reproducible Python
> scripts in `python/`. Raw script output is committed alongside this file
> in `documentation/`. Every percentage states its denominator inline.
> Where currency values appear, they are labeled `BRL` to avoid Markdown
> math rendering.

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

**Core referential integrity: 100% clean across all 6 foreign-key relationships.**

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
| Customer zip prefixes NOT present in geolocation | 157 |
| Seller zip prefixes NOT present in geolocation | 7 |
| Customer rows dropped by INNER JOIN | 278 |

**Decision:** The geography dimension uses `LEFT JOIN` on zip prefix so no
customer or seller is silently dropped.

---

## 2. Order Funnel — From Raw to Analytic Population

Every metric in this project operates on a well-defined order population.
The funnel below shows how 99,441 raw orders narrow to 97,905.

| Step | Filter | Orders |
|------|--------|-------:|
| 0 | All orders in dataset | 99,441 |
| 1 | Status in {delivered, shipped, invoiced, processing, approved} | 98,202 |
| 2 | `order_purchase_timestamp` in [2017-01-01, 2018-09-01) | 97,905 |
| 3 | Order has at least one row in `order_items` | 97,905 |

**Analytic population = 97,905 orders (98.46% of raw).**

**Step-by-step deltas:**
- Step 0 → 1: −1,239 orders (excluded statuses)
- Step 1 → 2: −297 orders (outside time window)
- Step 2 → 3: −0 orders (no item rows)

**Independent verification: every step matches a separately computed count
(`python/order_funnel.py`).**

**Breakdown of excluded statuses:** canceled 625, unavailable 609, created 5.
**Breakdown of out-of-window orders:** 2016-10 (293), 2016-09 (2), 2016-12 (1),
2018-09 (1).

**All in-scope, in-window orders have item rows** — the 775 raw orders with
no items are all out-of-scope status or outside the window.

---

## 3. Customer Identity — The Critical Trap

| Metric | Value | Denominator |
|--------|------:|-------------|
| Unique `customer_id` | 99,441 | — |
| Unique `customer_unique_id` | 96,096 | — |
| Repeat customers (>1 distinct order) | 2,997 | 96,096 |
| Repeat rate | 3.12% | 96,096 |

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
repeat rate is 3.12% of unique customers — about 1 in 32 customers places a
second order. One outlier placed 17 orders; worth noting in the RFM
analysis but not representative of the base.

**Critical modeling note:** The dataset contains two customer identifiers.
`customer_id` is unique per order; `customer_unique_id` identifies the
actual person. All RFM, cohort, and repeat-purchase analysis uses
`customer_unique_id`. Using `customer_id` would show a 100% one-time-buyer
rate and invalidate the retention analysis.

---

## 4. Payments

| Metric | Value | Denominator |
|--------|------:|-------------|
| Distinct orders in payments | 99,440 | — |
| Orders with exactly 1 payment row | 96,479 | 99,440 |
| Orders with >1 payment rows | 2,961 | 99,440 |
| Multi-payment share | 2.98% | 99,440 |
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
(`bfbd0f9bdef84302105ad712db648a6c`) has no payment row and a status of
`delivered`. In the fact table this order carries `payment_value = NULL`.
It is flagged in the load reconciliation but not removed.

**Implication:** Payment values are aggregated to order level
(`SUM(payment_value) GROUP BY order_id`) before joining to any fact table.
Joining at row level would inflate revenue for the 2.98% of split-payment
orders.

---

## 5. Reviews

| Metric | Value | Denominator |
|--------|------:|-------------|
| Rows in reviews | 99,224 | — |
| Unique `review_id` | 98,410 | — |
| Duplicate `review_id` rows | 814 | 99,224 |
| Unique `order_id` in reviews | 98,673 | — |
| Orders with >1 review | 547 | — |
| Orders with no review at all | 768 | 99,441 |
| Orders with no review — % | 0.77% | 99,441 |

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

**Decision:** Deduplicate by partitioning on `order_id` only — `review_id`
has 814 duplicate values, so it is not a reliable key. Within each
partition, keep the row with the most recent `review_creation_date`; ties
broken by `review_answer_timestamp DESC` so the result is deterministic.

**Interpretation notes:**
- Average review score is computed over reviewed orders only.
- The 768 orders without any review retain a NULL score in the fact table.
- The score itself is never null — missingness only affects comment text.

---

## 6. Order Statuses — Verified Refunds

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

**Refund verification (from `python/late_flag_check.py`):**

| Status | Orders | With payment row | Payments on these |
|--------|-------:|-----------------:|------------------:|
| canceled | 625 | 625 (100%) | `BRL 143,255.60` |
| unavailable | 609 | 609 (100%) | `BRL 126,479.51` |
| created | 5 | 5 (100%) | `BRL 688.10` |

**Total payments on excluded statuses: `BRL 270,423.21`.**

These orders were charged and refunded — they did not complete as a sale.
This confirms the decision to exclude them from GMV, Order Count, and all
revenue metrics.

**Additionally:** 6 canceled orders have a delivery date. These are edge
cases and are excluded along with all other canceled orders.

**Decision:** GMV includes only
{delivered, shipped, invoiced, processing, approved}.
Excludes {canceled, unavailable, created}.

**Naming convention:** Documented as **"GMV (excluding canceled, unavailable,
created)"** everywhere it appears. Delivery and review metrics use delivered
orders only.

---

## 7. Date Coverage

**Purchase date range:** 2016-09-04 → 2018-10-17
**Time axis:** `order_purchase_timestamp` throughout.

Monthly order counts reveal three regimes:

| Period | Total orders | Characteristic |
|--------|-------------:|----------------|
| 2016-09 to 2016-12 | 329 | Ramp-up — excluded from trends |
| 2017-01 to 2018-08 | 98,892 | Stable production |
| 2018-09 to 2018-10 | 20 | Incomplete tail — excluded |

**Early 2017 was slow, not steady.** Monthly orders by month:
Jan 800 · Feb 1,780 · Mar 2,682 · Apr 2,404 · May 3,700 · Jun 3,245 ·
Jul 4,026 · Aug 4,331 · Sep 4,285 · Oct 4,631 · Nov 7,544 · Dec 5,673.

**Effective trend window: 2017-01 → 2018-08 (20 months).**
**YoY comparison: 2017-01..08 vs 2018-01..08.**

---

## 8. Products & Categories

| Metric | Value |
|--------|------:|
| Unique `product_category_name` in products | 73 |
| Rows in `category_translation` | 71 |
| Categories with no English translation | 2 |

**Missing translations — exact snake_case values added:**

| Raw (Portuguese) | Added translation (snake_case) |
|------------------|--------------------------------|
| `pc_gamer` | `pc_gamer` |
| `portateis_cozinha_e_preparadores_de_alimentos` | `kitchen_food_prep_portables` |

**Products with no category at all:** 610 (1.85% of 32,951). Labeled as
`unknown` (lowercase, single word) in `product_category_name`. The display
column renders it as `Unknown`.

**Display-name overrides:** Title-casing the raw snake_case produces
`Pc Gamer` for `pc_gamer`, which reads poorly. A single override entry
forces `PC Gamer` in the display column. All other categories use the
simple Title Case rule.

**Products with missing physical dimensions but a valid category:** 2. Kept.

---

## 9. Geolocation

| Metric | Value | Denominator |
|--------|------:|-------------|
| Total rows | 1,000,163 | — |
| Unique zip prefixes | 19,015 | — |
| Row reduction after dedup | 98.10% | — |

**Decision:** Aggregate to one row per `zip_code_prefix` using mean lat/lng.
Join to `dim_geography` via `LEFT JOIN` to preserve all customers and
sellers (see §1 for the 157 customer zips and 7 seller zips with no
geolocation row).

---

## 10. Basket Size

| Metric | Value | Denominator |
|--------|------:|-------------|
| Total orders in order_items | 98,666 | — |
| Orders with exactly 1 item row | 88,863 | 98,666 |
| Orders with >1 item rows | 9,803 | 98,666 |
| Multi-item share | 9.94% | 98,666 |
| Max items in one order | 21 | — |
| Average items per order | 1.14 | — |

**Note:** 98,666 distinct orders appear in `order_items`, but `orders` has
99,441. The 775 orders not in `order_items` are all out-of-scope status or
outside the trend window — none are in the analytic population (§2).

---

## 11. Payments vs Order Items — Reconciliation (v2)

The initial reconciliation reported a false headline residual of
`BRL 2,838.38` (0.018%) because the two totals were computed on two
different populations. This section reports the corrected reconciliation
from `python/reconcile_payments_v2.py`.

### 11.1 Root Cause of the Original Bug

The old script computed:
- **LEFT total** — `SUM(order_items.price + freight)` restricted to in-scope
  statuses (98,199 orders, `BRL 15,735,527.03`)
- **RIGHT total** — `SUM(payments.payment_value)` from an **outer-joined**
  table against the LEFT population, which silently added payments from
  orders outside that population (99,440 orders, `BRL 16,008,872.12`)

The `BRL 273,345.09` gap was a population mismatch, not a revenue gap.

### 11.2 Four-Part Attribution of the Original Gap

From `python/diagnose_reconciliation.py`:

| Category | Payments |
|----------|---------:|
| A — orders with no item rows | `BRL 162,591.95` |
| B — out-of-scope statuses | `BRL 108,058.22` |
| C — outside time window | `BRL 51,752.88` |
| D — correct population | `BRL 15,686,469.07` |
| **Total (A + B + C + D)** | **`BRL 16,008,872.12`** ✅ |

The attribution sums exactly to the difference between the two original
totals, confirming the population-mismatch diagnosis.

### 11.3 Corrected Reconciliation — Analytic Population

Population: in-scope status AND in trend window AND has item rows = **97,905 orders**.

| Metric | Value |
|--------|------:|
| `SUM(payment_total)` | `BRL 15,686,469.07` |
| `SUM(item_total)` | `BRL 15,683,706.74` |
| **NET difference** | **`BRL 2,762.33` (0.0176%)** |
| **SUM of absolute differences** | **`BRL 3,033.13` (0.0193%)** |
| Orders matching within 1 cent | 97,534 (99.62%) |
| Orders with any difference | 371 |

### 11.4 Residual Breakdown

**By payment_type mix:**

| Type mix | Orders | Net residual | Abs residual |
|----------|-------:|-------------:|-------------:|
| credit_card | 73,181 | `BRL 2,797.02` | `BRL 2,962.68` |
| debit_card | 1,512 | −`BRL 51.99` | `BRL 52.01` |
| credit_card\|voucher | 2,205 | `BRL 17.44` | `BRL 17.56` |
| boleto | 19,477 | −`BRL 0.13` | `BRL 0.87` |
| voucher | 1,529 | −`BRL 0.01` | `BRL 0.01` |

**By installment count (top 5 by absolute residual):**

| Installments | Orders | Net residual |
|-------------:|-------:|-------------:|
| 10 | 5,194 | `BRL 919.80` |
| 12 | 131 | `BRL 347.62` |
| 6 | 3,852 | `BRL 261.69` |
| 8 | 4,209 | `BRL 240.29` |
| 5 | 5,149 | `BRL 189.16` |

### 11.5 Interpretation

The residual is **not a data-quality problem.** It is concentrated in
credit_card orders with installments > 1. Boleto — a single-installment
bank slip with no interest — matches essentially exactly. This pattern is
consistent with **installment interest charged to the customer but not
paid to the seller**, which is normal in the Brazilian
credit-card market.

**Metric design decisions:**
- **GMV** = item price only (freight excluded).
- **Freight Charged** = separate measure, not called revenue.
- **Total Customer Paid** = GMV + Freight Charged.
- Reconciliation is reported with both net and absolute differences.

---

## 12. Late-Order Flag — Assumption Verification

From `python/late_flag_check.py`. Four assumptions were tested before the
late flag was frozen into metric definitions.

### 12.1 Is `order_estimated_delivery_date` always at midnight?

**Yes.** 0 of 99,441 rows have a non-midnight time component. The estimated
date is a pure calendar date.

### 12.2 Timestamp vs date comparison

| Comparison | Late orders | Rate |
|------------|-----------:|-----:|
| Raw timestamp (`delivered_dt > estimated_dt`) | 7,826 | 8.11% |
| **Date-only** (`DATE(delivered) > DATE(estimated)`) | **6,534** | **6.77%** |
| Difference | **1,292** | 1.34 pp |

**Decision:** The late flag compares **dates**, not timestamps. A raw
timestamp comparison misclassifies 1,292 orders as late because the
estimated date sits at midnight. Example: delivery at `2018-03-20 00:59:25`
against an estimated date of `2018-03-20` is on time, not late.

### 12.3 Delivered orders with a null delivery date

**8 delivered orders (0.0083%)** have no `order_delivered_customer_date`.
These are excluded from the late-rate denominator but kept in Order Count.

### 12.4 Late-rate denominator on the analytic population

| Metric | Value |
|--------|------:|
| In-scope, in-window, delivered | 96,211 |
| Delivered with non-null delivery date | **96,203** |
| Late orders (date-based) | 6,531 |
| **Late rate** | **6.79%** |

---

## 13. 2018 Trend Analysis — Hypothesis Tested

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

| Month | GMV (BRL) |
|-------|----------:|
| Jan | 945,456.29 |
| Feb | 837,895.43 |
| Mar | 981,051.06 |
| Apr | 993,592.98 |
| May | 992,871.75 |
| Jun | 863,265.53 |
| Jul | 878,044.27 |
| Aug | 848,860.10 |

**Verdict:** Both order volume and GMV peak around March–May 2018 and
decline ~10–15% by August. The decline appears in raw orders, in-scope
orders, and GMV. The hypothesis holds.

**Caveats to state in the report:**
- Only 8 months of 2018 are available.
- There is no prior-year baseline to distinguish decline from seasonality.
- The +138% YoY growth figure (Jan–Aug) is dominated by the marketplace
  ramp-up, not organic growth, and should not be headlined.

---

## 14. Summary — What Changes Because of This Log

| Finding | Cleaning action |
|---------|-----------------|
| `customer_unique_id` is the real customer key | Use only this for RFM/cohorts |
| Repeat rate is 3.12% | Report will describe the small loyal segment carefully |
| Payments split across rows (2.98%) | Aggregate to order level before joins |
| One order has no payment row | Retain with NULL `payment_value`; flag |
| 814 duplicate `review_id` values | Dedup: partition by `order_id`, order by `review_creation_date DESC`, `review_answer_timestamp DESC` |
| 768 orders have no review | Retain with NULL score |
| Canceled / unavailable / created verified refunded | Exclude from GMV; not "never sold" but "did not complete as a sale" |
| 2016 & late-2018 incomplete | Exclude from trends |
| 2 categories missing translation | Add snake_case translation + display column with one override |
| 610 products missing category | Label `unknown` |
| 1M → 19,015 unique zips | Dedup by zip_prefix; `LEFT JOIN` into dims |
| 157 customer zips missing in geo | `LEFT JOIN` required; no customer dropped |
| Reconciliation net 0.0176%, abs 0.0193% | Installment interest; not a data issue |
| Late flag must compare dates, not timestamps | Prevents 1,292 false positives |
| Late rate = 6.79% | Denominator = 96,203 (delivered, non-null delivery date) |
| 8 delivered orders have null delivery date | Excluded from late rate; kept in order count |

---

## 15. Rules Adopted

Going forward, in every SQL script, DAX measure, and report element:

1. Every percentage states its denominator inline.
2. Every number is copied from script output, not hand-calculated.
3. Every metric is defined in `metric_definitions.md` before it appears in
   a query.
4. Every cleaning decision is traceable to a specific finding in this log.
5. Any two numbers appearing in a comparison must come from the same
   population. Population mismatches are bugs, not results.
6. Currency values in markdown use `BRL` or backticks to avoid `$` being
   interpreted as math.

---

## 16. Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0 | October 2026 | Initial draft |
| 2.0 | October 2026 | Corrected repeat-customer count, multi-payment share, missing-review count, multi-item count. Added extended FK checks, payments reconciliation, 2018 hypothesis. |
| 3.0 | October 2026 | Added order funnel (§2). Corrected reconciliation with root-cause analysis and four-part attribution (§11). Added refund verification for excluded statuses (§6). Added late-flag assumption checks (§12). Added population-consistency and currency-formatting rules (§15). Updated summary table (§14). |

---

*Companion files: `metric_definitions.md`, `decision_log.md`,*
*`order_funnel.txt`, `reconcile_payments_v2.txt`, `diagnose_reconciliation.txt`,*
*`late_flag_check.txt`.*