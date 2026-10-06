# Decision Log — Olist Analytics

**Analyst:** Fazle Karim
**Date:** October 2026
**Version:** 1.5
**Purpose:** A running log of every non-obvious modeling, metric, or
cleaning decision made during this project. Each entry includes what was
decided, why, and what alternative was rejected.

Entries are added in chronological order. Once a decision is logged it is
considered frozen unless a later entry supersedes it.

> **Rule:** every number referenced below is pinned in
> `documentation/control_totals.json` and verified by
> `python/verify_control_totals.py`.

> **Markdown note:** Currency values are written as `BRL` or backticks.

---

## 2026-10 — Step 2 Data Exploration

### D-001: Use `customer_unique_id` as the customer key

**Decision:** All RFM, cohort, repeat-purchase, and customer-level analysis
uses `customer_unique_id`, never `customer_id`.

**Why:** `customer_id` is unique per order; only `customer_unique_id`
identifies the person. Using `customer_id` would have shown a 100%
one-time-buyer rate.

**Evidence:** `data_quality_log.md` §3 — 99,441 `customer_id` vs 96,096
`customer_unique_id`.

---

### D-002: GMV scope excludes canceled, unavailable, created orders

**Decision:** GMV includes only `delivered`, `shipped`, `invoiced`,
`processing`, `approved`.

**Why:** Every order with an excluded status has a payment record, but the
dataset contains no refund data. The order status indicates the order did
not complete.

**Evidence:** `data_quality_log.md` §6.

---

### D-003: GMV defined as item price only; freight tracked separately

**Decision:** `GMV = SUM(order_items.price)`. Freight is `Freight Charged`.

**Why:** Item price is the revenue attributable to the product sale.
Freight is a component of what the customer paid but is not called
"revenue".

**Reconciliation:** `SUM(payment_value)` matches `Total Customer Paid` to
within `BRL 2,762.33` net (0.0176%) on the analytic population.

---

### D-004: Trend window is 2017-01-01 to 2018-08-31

**Decision:** All trend analysis uses half-open interval
`>= '2017-01-01' AND < '2018-09-01'`.

**Why:** 2016 ramp-up (329 orders); 2018-09/10 incomplete (20 orders).

**Evidence:** `data_quality_log.md` §7; `control_totals.json` year_splits.

---

### D-005: Deduplicate reviews by `order_id`, not `review_id`

**Decision:** Partition on `order_id`, keep the row with the most recent
`review_creation_date`; ties broken by `review_answer_timestamp DESC`.

**Why:** `review_id` has 814 duplicate values. `order_id` is the correct
partition key.

---

### D-006: Aggregate payments to order level before joining

**Decision:** `SUM(payment_value) GROUP BY order_id` before joining.

**Why:** 2.98% of orders have multiple payment rows.

---

### D-007: Geography dimension uses `LEFT JOIN` on zip prefix

**Decision:** Join customers and sellers to geolocation via `LEFT JOIN` on
`zip_code_prefix`.

**Why:** 157 customer zips and 7 seller zips have no matching geolocation
row. An `INNER JOIN` would drop 278 customer rows.

---

### D-008: Category names preserved in snake_case; display column added

**Decision:** `dim_product.product_category_name` retains the source
snake_case. `category_display_name` applies Title Case with a `PC Gamer`
override.

---

### D-009: 2018 trend treated as hypothesis

**Decision:** The "2018 flat-to-slightly-down" observation is presented as
a hypothesis, not a headline.

**Why:** Only 8 months of 2018; no prior-year baseline for seasonality.

---

### D-010: Reconciliation fix — population mismatch, not netting

**Decision:** The rebuilt reconciliation defines the population once as a
single order-id list, computes both sums by joining to that list, and
asserts the two sides match.

**Why:** The original script compared items-in-scope against payments via an
outer join that pulled in payments from orders outside the population. The
`BRL 273,345.09` gap was a population mismatch. Correct net residual:
`BRL 2,762.33` (0.0176%).

**Note:** Initial diagnosis was "netting of residuals", which is
mathematically wrong. A review caught this. The diagnosis script
`diagnose_reconciliation.py` confirms the correct cause.

---

### D-011: Analytic population = 97,905 orders

**Decision:** In-scope AND in-window AND has item rows.

**Evidence:** `data_quality_log.md` §2; `order_funnel.txt`.

---

### D-012: Late flag compares dates, not timestamps

**Decision:** `DATE(delivered) > DATE(estimated)`.

**Why:** `order_estimated_delivery_date` is always midnight. Raw timestamp
comparison misclassifies 1,292 orders.

---

### D-013: Verify payment record for excluded statuses

**Decision:** All 1,239 excluded-status orders have a payment row
(`BRL 270,423.21` total). No refund data exists.

**Additional:** 6 canceled orders have a delivery date. Kept excluded.

---

## 2026-10 — Step 4 / Step 5 Corrections

### D-014: Repeat-rate population = analytic population (3.03%)

**Decision:** The reported repeat purchase rate is **3.03%** (2,874 of
94,703), computed over the analytic population.

**Why:** All customer metrics in the model (RFM, cohorts, new vs returning)
operate on the analytic population. Using a different denominator for
repeat rate would make the report internally inconsistent.

**Alternatives documented but not reported:**
- Full customer base (all statuses, all dates): 3.12% (2,997 of 96,096)
- In-scope statuses (all dates): 3.04% (2,887 of 94,986)

**Evidence:** `control_totals.json` → `rfm.repeat_rate_in_population_pct`.

---

### D-015: Round to cents before comparing in reconciliation

**Decision:** Both sides rounded to 2 decimals before subtracting.

**Why:** Removes floating-point noise (`1e-13`).

**Effect:** `orders_exact_match` = 97,336; `orders_differ_one_cent` = 273.

---

### D-016: Date windows use half-open intervals

**Decision:** `>= start AND < end` everywhere. Never `BETWEEN`.

---

### D-017: Unique constraints on dimensions and facts

**Decision:** UNIQUE on `dim_customer.customer_unique_id`,
`dim_product.product_id`, `dim_seller.seller_id`,
`fact_orders.order_id`, `fact_order_items(order_id, order_item_id)`.

**Why:** Turns silent duplicates into a failed load.

---

### D-018: `is_late` uses NULL for not-measurable

**Decision:** `is_late BIT NULL`. Value is 1 (late), 0 (on-time), or NULL
(not measurable). Same on both fact tables.

**Why:** A default of 0 conflated "on-time" with "not applicable". With
NULL, `AVG(is_late)` gives 6.79% directly without extra filtering.

---

### D-019: `delivery_days` uses elapsed seconds

**Decision:** `FLOOR(DATEDIFF(SECOND, purchase, delivered) / 86400.0)`.

**Why:** `DATEDIFF(DAY)` counts midnight boundaries; pandas `.dt.days` floors
elapsed time. Only the elapsed-seconds form matches both.

**Alternative rejected:** `DATEDIFF(DAY, ...)` would diverge from pandas by
up to 1 day per order.

**Pinned value:** avg = `12.0739` over `96,203` measurable orders.

---

### D-020: Full-history cohorts and pre-2017 bucket

**Decision:** Cohort month = month of the customer's **first-ever in-scope
order across all dates** (from `clean.orders`, not `fact_orders`). Customers
whose first order predates 2017-01-01 go into a single `pre-2017` sentinel
row (10 customers).

**Why:** A customer whose first order was in 2016 would otherwise be placed
in a 2017 cohort, polluting early cohorts.

**Effect:** Matrix customers = 94,693; sentinel = 10; total = 94,703.

---

### D-021: Cohort matrix is the full triangle with zero-fill

**Decision:** Generate every observable `(cohort_month, month_offset)` cell,
including those with zero returning customers. 210 cells.

**Why:** Omitting zero cells biased average retention upward.

**Implementation:** `GENERATE_SERIES` replaces the undocumented
`master..spt_values`.

---

### D-022: Segment renames — Recent one-time and Lapsed one-time

**Decision:** Rename "New" → **Recent one-time** and "Lost" → **Lapsed
one-time**.

**Why:** 58% of customers fell into "Lost" — misleading name. "New"
included purchases months before the snapshot. The new names describe what
the data shows.

**Effect:** No change to row counts, only labels.

---

### D-023: bi schema with views; RFM merged into dim_customer

**Decision:** Power BI imports **only** the `bi` schema views. `bi.dim_customer`
merges the RFM columns. `bi.cohort_retention` excludes the pre-2017 sentinel;
`bi.cohort_pre2017` exposes it separately. `bi.customer_rfm` dropped.

**Why:** Slim model, no redundant 1:1 relationship, heatmap not polluted by
the sentinel.

---

### D-024: SQLCMD variables for window and snapshot

**Decision:** Declare `:setvar WindowStart`, `WindowEnd`, `SnapshotDate`,
`SnapshotMonth` once at the top of `06_rfm_cohorts.sql`.

**Why:** Single source of truth for the constants; no literals scattered
through the script.

---

### D-025: No relationship between the two fact tables

**Decision:** `fact_orders` and `fact_order_items` both connect directly to
shared dimensions. No fact-to-fact relationship.

**Why:** Avoids ambiguous filter paths in Power BI. `order_key` on items is
for counting only.

**Documented:** In the fact table header in `05_facts.sql`.

---

## How to Add an Entry

Use this template:

D-NNN: Short title
Decision: What was decided.

Why: The reasoning, including the alternative rejected.

Evidence: Where the supporting numbers live (file and section).

text

Number sequentially. Do not delete or edit prior entries — if a decision is
later reversed, add a new entry that supersedes it and reference the old one.