# Metric Definitions — Olist Analytics

**Analyst:** Fazle Karim
**Date:** October 2026
**Version:** 1.0 (frozen)
**Purpose:** Every metric used in SQL, DAX, or the report is defined here
before it appears in a query. Once frozen, changes require a version bump
and a note in the changelog.

> **Rule:** No metric appears in a SQL script or DAX measure until it is
> defined in this document. Any ambiguity in a metric's formula is a bug,
> not a style choice.

---

## 1. Base Filters

Three ordered filters apply to every metric. They must be applied in this
order, and every metric is defined in terms of them.

| Filter | Definition | Rationale |
|--------|------------|-----------|
| **Time filter** | `order_purchase_timestamp` between `2017-01-01` and `2018-08-31` (default trend window) | 2016 is ramp-up (329 orders); 2018-09/10 are incomplete (20 orders). |
| **In-scope filter** | `order_status IN ('delivered','shipped','invoiced','processing','approved')` | Excludes `canceled`, `unavailable`, `created` — never generated real revenue. |
| **Delivered filter** | `order_status = 'delivered'` | Used for delivery and review metrics only. |

**Default**: unless otherwise stated, a metric uses the **Time filter** and
the **In-scope filter**. Delivered-filter metrics say so explicitly.

---

## 2. Core Metrics

### 2.1 GMV — Gross Merchandise Value (excluding canceled, unavailable, created)

- **Formula:** `SUM(order_items.price)`
- **Source table:** `analytics.fact_order_items` (one row per item)
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL (R$)
- **Excludes:** freight, canceled orders, unavailable orders, created orders
- **Rationale:** Item price is the revenue attributable to the product sale.
  Freight is tracked separately (§2.4).

### 2.2 Order Count

- **Formula:** `COUNT(DISTINCT orders.order_id)`
- **Source table:** `analytics.fact_orders`
- **Filter:** Time filter + In-scope filter
- **Unit:** integer
- **Note:** Counts distinct orders, never item rows. An order with 3 items
  is 1 order.

### 2.3 AOV — Average Order Value

- **Formula:** `GMV ÷ Order Count`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL (R$)
- **Note:** Uses order-level count, not item-level count.

### 2.4 Freight Revenue

- **Formula:** `SUM(order_items.freight_value)`
- **Source table:** `analytics.fact_order_items`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL (R$)
- **Note:** Tracked as a separate measure, never rolled into GMV.

### 2.5 Total Customer Paid

- **Formula:** `GMV + Freight Revenue`
- **Filter:** Time filter + In-scope filter
- **Unit:** BRL (R$)
- **Reconciliation:** This total should match `SUM(payments.payment_value)`
  to within 0.02% (verified in Step 2). Any larger gap indicates a join bug.

### 2.6 Items per Order

- **Formula:** `COUNT(fact_order_items rows) ÷ COUNT(DISTINCT orders.order_id)`
- **Filter:** Time filter + In-scope filter
- **Unit:** decimal
- **Expected value:** ~1.14 (from data quality log §9)

---

## 3. Customer Metrics

All customer metrics use **`customer_unique_id`** as the customer key — never
`customer_id`. See data quality log §2 for the reasoning.

### 3.1 Unique Customers

- **Formula:** `COUNT(DISTINCT customer_unique_id)`
- **Filter:** Time filter + In-scope filter
- **Unit:** integer

### 3.2 New Customers

- **Definition:** A customer whose **first-ever** order falls inside the
  current period.
- **Formula:** `COUNT(DISTINCT customer_unique_id)` where
  `first_order_date BETWEEN period_start AND period_end`
- **Filter:** Time filter + In-scope filter
- **Note:** "First-ever" is computed across the customer's full history,
  not just the current period.

### 3.3 Returning Customers

- **Definition:** A customer who placed an order in the current period and
  had at least one **prior** order before the period start.
- **Formula:** `COUNT(DISTINCT customer_unique_id)` where
  `first_order_date < period_start` AND customer has an order in current period
- **Filter:** Time filter + In-scope filter

### 3.4 Repeat Purchase Rate

- **Formula:** `(Repeat customers) ÷ (Total unique customers)`
  - Repeat customers: `COUNT(DISTINCT customer_unique_id HAVING >1 order)`
  - Total unique customers: `COUNT(DISTINCT customer_unique_id)`
- **Filter:** Time filter + In-scope filter (full dataset, not per-period)
- **Unit:** percentage
- **Expected value:** 3.12% (from data quality log §2)

### 3.5 RFM Segments

- **Recency:** Days since the customer's most recent order, as of the
  dataset's max `order_purchase_timestamp` (2018-10-17). Lower is better.
- **Frequency:** Count of distinct orders per `customer_unique_id`.
- **Monetary:** Sum of GMV per `customer_unique_id`.
- **Scoring:** Each dimension scored 1–5 using **quintiles** of the
  customer base (5 = best).
- **Segment rules:** To be defined after seeing the score distribution.

---

## 4. Time Intelligence

### 4.1 Time Axis

- **Column:** `order_purchase_timestamp` (from `orders`)
- **Granularity:** Month and Year
- **Time zone:** as stored (no conversion)

### 4.2 YoY Comparison Window

- **Current period:** 2018-01-01 to 2018-08-31
- **Prior period:** 2017-01-01 to 2017-08-31
- **Rationale:** Only Jan–Aug is comparable — 2018-09/10 is incomplete,
  and 2017-11/12 has no 2018 counterpart.
- **Reporting language:** "Jan–Aug comparison", never just "YoY".

### 4.3 MoM Growth

- **Formula:** `(current_month_value − prior_month_value) ÷ prior_month_value`
- **Filter:** Time filter + In-scope filter
- **Note:** Partial months (2018-09, 2018-10) are excluded from MoM charts.

### 4.4 Rolling 12-Month

- **Formula:** `SUM` over trailing 12 months from the current period end
- **Note:** Only meaningful from 2018-01 onwards (given the 2016 ramp-up).

---

## 5. Delivery & Satisfaction Metrics

All metrics in this section use the **Delivered filter** (`order_status = 'delivered'`).

### 5.1 Delivery Time

- **Formula:** `DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date)`
- **Unit:** days
- **Note:** Only rows with both dates present are counted.

### 5.2 Late Order

- **Definition:** An order delivered **after** its
  `order_estimated_delivery_date`.
- **Flag:** `1` if `order_delivered_customer_date > order_estimated_delivery_date`, else `0`
- **Unit:** binary

### 5.3 Late Order Rate

- **Formula:** `(Late orders) ÷ (Delivered orders)`
- **Filter:** Delivered filter
- **Unit:** percentage

### 5.4 Average Review Score

- **Formula:** `AVG(reviews.review_score)`
- **Source table:** `analytics.fact_orders` joined to deduped reviews
- **Filter:** Delivered filter + review present
- **Unit:** decimal (1.0–5.0)
- **Note:** Computed **over reviewed orders only**. The 768 orders without
  any review (data quality log §4) are excluded, not counted as 0.

### 5.5 Late vs On-Time Review Gap

- **Formula:** `AVG(review_score for late orders) − AVG(review_score for on-time orders)`
- **Filter:** Delivered filter + review present
- **Unit:** decimal points (e.g., −0.8 means late orders score 0.8 points lower)

---

## 6. Product & Category Metrics

### 6.1 Category Revenue

- **Formula:** GMV grouped by `dim_product.category_name_english`
- **Filter:** Time filter + In-scope filter
- **Note:** Uses the display column, not the raw snake_case.

### 6.2 Seller Revenue

- **Formula:** GMV grouped by `dim_seller.seller_id`
- **Filter:** Time filter + In-scope filter

### 6.3 Seller Late Rate

- **Formula:** Late Order Rate grouped by `dim_seller.seller_id`
- **Filter:** Delivered filter

---

## 7. Comparison Rules

### 7.1 Like-for-Like

Any comparison (YoY, MoM, region vs region) must use the **same date range
and same status filter** on both sides. Mixing windows is a bug.

### 7.2 Denominators

Every percentage in the report must state its denominator — either in the
label, the tooltip, or the accompanying text.

### 7.3 Rounding

- Currency: 2 decimals
- Percentages: 2 decimals
- Averages: 2 decimals
- Counts: integers only

---

## 8. Known Exclusions

These rows are **not** counted in any metric unless stated otherwise:

| Exclusion | Count | Reason |
|-----------|------:|--------|
| Canceled orders | 625 | Never generated revenue |
| Unavailable orders | 609 | Never reached fulfillment |
| Created orders | 5 | Never progressed |
| Orders before 2017-01 | 329 | Ramp-up, not representative |
| Orders after 2018-08 | 20 | Incomplete tail |
| Orders with no review | 768 | Counted only in review metrics; excluded from avg review score |

---

## 9. Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0 | October 2026 | Initial freeze. All metrics defined ahead of Step 4 cleaning SQL. |

---

*Companion files: `data_quality_log.md`, `gap_analysis.txt`,*
*`repeat_and_reconcile.txt`.*