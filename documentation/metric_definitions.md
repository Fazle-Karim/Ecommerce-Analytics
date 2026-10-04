# Metric Definitions — Olist Analytics

**Analyst:** Fazle Karim
**Date:** October 2026
**Version:** 1.1
**Purpose:** Every metric used in SQL, DAX, or the report is defined here
before it appears in a query. Once frozen, changes require a version bump
and a note in the changelog.

> **Rule:** No metric appears in a SQL script or DAX measure until it is
> defined in this document. Any ambiguity in a metric's formula is a bug,
> not a style choice.

> **Markdown note:** Where currency values appear in tables, they are written
> as `BRL` or wrapped in backticks to prevent GitHub from rendering the `$`
> character as math.

---

## 1. Population Funnel

Every metric in this document operates on a well-defined order population.
The population is derived once and reused everywhere.

| Step | Filter | Orders |
|------|--------|-------:|
| 0 | All orders in the dataset | 99,441 |
| 1 | Status in {delivered, shipped, invoiced, processing, approved} | 98,202 |
| 2 | `order_purchase_timestamp` in [2017-01-01, 2018-09-01) | 97,905 |
| 3 | Order has at least one row in `order_items` | 97,905 |

**Analytic population = 97,905 orders** (98.46% of raw).

This is the denominator for GMV, Order Count, AOV, Items per Order, and all
customer-level metrics. Any metric that uses a different population says so
explicitly.

**Independent verification** of every step is reproducible via
`python/order_funnel.py`.

---

## 2. Base Filters

Two ordered filters apply by default to every metric. They must be applied
in this order.

| Filter | Definition | Rationale |
|--------|------------|-----------|
| **Time filter** | `order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-31'` | 2016 is ramp-up (329 orders); 2018-09/10 has 1 order in-scope. |
| **In-scope filter** | `order_status IN ('delivered','shipped','invoiced','processing','approved')` | Excludes `canceled` (625), `unavailable` (609), `created` (5) — verified to have been charged and refunded, not revenue. |
| **Delivered filter** | `order_status = 'delivered'` AND `order_delivered_customer_date IS NOT NULL` | Used for delivery and review metrics. Excludes 8 delivered orders with a null delivery date. |

**Default:** unless otherwise stated, a metric uses the **Time filter** and
the **In-scope filter**. Delivery metrics additionally use the **Delivered
filter** and say so.

---

## 3. Core Metrics

### 3.1 GMV — Gross Merchandise Value (excluding canceled, unavailable, created)

- **Formula:** `SUM(order_items.price)`
- **Source table:** `analytics.fact_order_items`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL
- **Excludes:** freight, canceled orders, unavailable orders, created orders
- **Rationale:** Item price is the revenue attributable to the product sale.
  Freight is tracked separately (§3.4).

### 3.2 Order Count

- **Formula:** `COUNT(DISTINCT orders.order_id)`
- **Source table:** `analytics.fact_orders`
- **Filter:** Time filter + In-scope filter
- **Unit:** integer
- **Note:** Counts distinct orders, never item rows. An order with 3 items
  is 1 order.

### 3.3 AOV — Average Order Value

- **Formula:** `GMV ÷ Order Count`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL
- **Note:** Uses order-level count, not item-level count.

### 3.4 Freight Charged

- **Formula:** `SUM(order_items.freight_value)`
- **Source table:** `analytics.fact_order_items`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL
- **Note:** Tracked as a separate measure, never rolled into GMV.
  **Not** labeled "revenue" — there is no cost data to determine margin.

### 3.5 Total Customer Paid

- **Formula:** `GMV + Freight Charged`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL
- **Reconciliation:** This total matches `SUM(payments.payment_value)` to
  within **0.018%** net, **0.019%** absolute, on the analytic population.
  See `documentation/reconcile_payments_v2.txt` for detail.

### 3.6 Items per Order

- **Formula:** `COUNT(fact_order_items rows) ÷ COUNT(DISTINCT orders.order_id)`
- **Filter:** Time filter + In-scope filter
- **Unit:** decimal
- **Expected value:** ~1.14

---

## 4. Customer Metrics

All customer metrics use **`customer_unique_id`** as the customer key — never
`customer_id`. Rationale in `data_quality_log.md` §2.

### 4.1 Unique Customers

- **Formula:** `COUNT(DISTINCT customer_unique_id)`
- **Filter:** Full dataset (no time filter), In-scope filter
- **Unit:** integer
- **Note:** Includes customers whose only purchase was outside the trend
  window. This is intentional — it is the total customer base.

### 4.2 New Customers

- **Definition:** A customer whose **first-ever** order falls inside the
  current period.
- **Formula:** `COUNT(DISTINCT customer_unique_id)` where
  `first_order_date BETWEEN period_start AND period_end`
- **Filter:** Time filter + In-scope filter
- **Note:** "First-ever" is computed across the customer's full history.

### 4.3 Returning Customers

- **Definition:** A customer who placed an order in the current period and
  had at least one **prior** order before the period start.
- **Formula:** `COUNT(DISTINCT customer_unique_id)` where
  `first_order_date < period_start` AND customer has an order in the current period
- **Filter:** Time filter + In-scope filter

### 4.4 Repeat Purchase Rate

- **Formula:** `(Repeat customers) ÷ (Total unique customers)`
  - Repeat customers: `COUNT(DISTINCT customer_unique_id HAVING >1 order)`
  - Total unique customers: `COUNT(DISTINCT customer_unique_id)`
- **Filter:** **Full dataset** — all dates, all in-scope statuses.
  This is a customer-base property, not a per-period metric.
- **Unit:** percentage
- **Verified value:** **3.12%** (2,997 of 96,096 customers).

> **Clarification:** §4.4 uses the full dataset, not the trend window. It
> describes the customer base as a whole. §4.1 also uses the full dataset
> for consistency. All other customer metrics in this section use the
> trend window.

### 4.5 RFM Segments

- **Recency:** Days since the customer's most recent order, measured against
  the **trend window end date** (2018-08-31), not the dataset end.
  Rationale: keeps recency consistent with the period the report describes.
- **Frequency:** Count of distinct orders per `customer_unique_id`.
  Because 96.9% of customers have exactly one order, frequency is
  **rule-based, not quintile-based**:
  - 1 order → band "1"
  - 2 orders → band "2"
  - 3+ orders → band "3+"
  NTILE and quintile scoring are **not used** for frequency — ties would be
  split arbitrarily across 93,099 customers with a single order.
- **Monetary:** Sum of GMV per `customer_unique_id`, binned into quintiles.
- **Recency scoring:** Quintiles of the recency distribution (5 = most recent).
- **Segment rules:** To be defined after inspecting the score distribution
  in Step 4.

---

## 5. Time Intelligence

### 5.1 Time Axis

- **Column:** `order_purchase_timestamp` (from `orders`)
- **Granularity:** Month and Year
- **Time zone:** as stored (no conversion)

### 5.2 YoY Comparison Window

- **Current period:** 2018-01-01 to 2018-08-31
- **Prior period:** 2017-01-01 to 2017-08-31
- **Rationale:** Only Jan–Aug is comparable — 2018-09/10 is incomplete, and
  2017-11/12 has no 2018 counterpart.
- **Reporting language:** "Jan–Aug comparison", never just "YoY".

### 5.3 MoM Growth

- **Formula:** `(current_month_value − prior_month_value) ÷ prior_month_value`
- **Filter:** Time filter + In-scope filter
- **Note:** Partial months are excluded from MoM charts.

### 5.4 Rolling 12-Month

- **Formula:** `SUM` over trailing 12 months from the current period end
- **Note:** The first full rolling-12-month window ends in **2017-12**
  (needs 12 complete months from 2017-01).

---

## 6. Delivery & Satisfaction Metrics

All metrics in this section use the **Delivered filter**:
`order_status = 'delivered'` AND `order_delivered_customer_date IS NOT NULL`,
and also the **Time filter** and **In-scope filter**.

**Late-rate denominator = 96,203 orders** (verified in
`python/late_flag_check.py`).

### 6.1 Delivery Time

- **Formula:** `DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date)`
- **Unit:** days
- **Note:** Only rows with both dates present are counted.

### 6.2 Late Order

- **Definition:** An order delivered **after** its
  `order_estimated_delivery_date`.
- **Comparison:** **Date-only** — both sides are normalized to midnight
  before comparison. `order_estimated_delivery_date` is always midnight
  (verified), and comparing raw timestamps against it would misclassify
  same-day deliveries (verified: 1,292 orders).
- **Flag:** `1` if `DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)`, else `0`
- **Unit:** binary

### 6.3 Late Order Rate

- **Formula:** `(Late orders) ÷ (Delivered orders with non-null delivery date)`
- **Filter:** Delivered filter + Time filter + In-scope filter
- **Denominator:** 96,203
- **Verified value:** **6.79%** (6,531 late orders).

### 6.4 Average Review Score

- **Formula:** `AVG(reviews.review_score)`
- **Source table:** `analytics.fact_orders` joined to deduplicated reviews
- **Filter:** Delivered filter + Time filter + In-scope filter + review present
- **Unit:** decimal (1.0–5.0)
- **Note:** Computed **over reviewed orders only**. Orders without any review
  (768 total, all statuses) are excluded — not counted as 0.

### 6.5 Late vs On-Time Review Gap

- **Formula:** `AVG(review_score for late orders) − AVG(review_score for on-time orders)`
- **Filter:** Delivered filter + Time filter + In-scope filter + review present
- **Unit:** decimal points (e.g., −0.8 means late orders score 0.8 points lower)

---

## 7. Product & Category Metrics

### 7.1 Category Revenue

- **Formula:** GMV grouped by `dim_product.category_name_english_display`
- **Filter:** Time filter + In-scope filter
- **Note:** Uses the display column, not the raw snake_case column.

### 7.2 Seller Revenue

- **Formula:** GMV grouped by `dim_seller.seller_id`
- **Filter:** Time filter + In-scope filter

### 7.3 Seller Late Rate

- **Formula:** Late Order Rate grouped by `dim_seller.seller_id`
- **Filter:** Delivered filter + Time filter + In-scope filter

---

## 8. Comparison Rules

### 8.1 Like-for-Like

Any comparison (YoY, MoM, region vs region) must use the **same date range
and same status filter** on both sides. Mixing windows is a bug.

### 8.2 Population Consistency

Any two numbers that appear in a comparison must come from the **same
population**. If they don't, the difference is a population mismatch, not
a result. The reconciliation script (`reconcile_payments_v2.py`) enforces
this with an assertion.

### 8.3 Denominators

Every percentage in the report must state its denominator — either in the
label, the tooltip, or the accompanying text.

### 8.4 Rounding

- Currency: 2 decimals
- Percentages: 2 decimals
- Averages: 2 decimals
- Counts: integers only

### 8.5 Currency Formatting in Markdown

To prevent GitHub from rendering `$` as math syntax, currency values in
markdown files use `BRL` or are wrapped in backticks: `` `BRL 273,345.09` ``.

---

## 9. Known Exclusions

These rows are **not** counted in any metric unless stated otherwise:

| Exclusion | Count | Reason |
|-----------|------:|--------|
| Canceled orders | 625 | Charged and refunded; did not complete as a sale |
| Unavailable orders | 609 | Charged and refunded; did not complete as a sale |
| Created orders | 5 | Charged and refunded; did not complete as a sale |
| Orders before 2017-01 | 296 | Ramp-up period |
| Orders on/after 2018-09 | 1 | Incomplete tail |
| Delivered orders with null delivery date | 8 | Late rate only; kept in order count |
| Orders with no review | 768 | Review score only; excluded from avg review |

**Total in-scope and out-of-scope exclusions from the analytic population:**
99,441 − 97,905 = 1,536 orders (1.54%).

---

## 10. Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0 | October 2026 | Initial freeze |
| 1.1 | October 2026 | Corrected §3.5 reconciliation figure (net 0.018%, absolute 0.019%). Added §1 Population Funnel. Clarified §4.1 and §4.4 filter scope. Replaced RFM frequency quintiles with rule-based bands (§4.5). Set RFM recency snapshot to 2018-08-31 (§4.5). Renamed "Freight Revenue" → "Freight Charged" (§3.4). Corrected §5.4 rolling-12-month note. Defined late flag as date-comparison, not timestamp (§6.2). Late-rate denominator = 96,203, verified 6.79% (§6.3). Added §8.2 population-consistency rule. Added §8.5 currency formatting rule. Reworded §9 "never generated revenue" → "did not complete as a sale". |

---

*Companion files: `data_quality_log.md`, `decision_log.md`,*
*`order_funnel.txt`, `reconcile_payments_v2.txt`, `late_flag_check.txt`.*