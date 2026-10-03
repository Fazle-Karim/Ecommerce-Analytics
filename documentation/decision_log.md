# Decision Log — Olist Analytics

**Purpose:** A running log of every non-obvious modeling, metric, or cleaning
decision made during this project. Each entry includes what was decided, why,
and what alternative was rejected. Interviewers ask "why did you do it this
way?" — this file is the answer.

Entries are added in chronological order. Once a decision is logged it is
considered frozen unless a later entry supersedes it.

---

## 2026-10 — Step 2 Data Exploration

### D-001: Use `customer_unique_id` as the customer key

**Decision:** All RFM, cohort, repeat-purchase, and customer-level analysis
uses `customer_unique_id`, never `customer_id`.

**Why:** `customer_id` is unique per order; only `customer_unique_id`
identifies the person. Using `customer_id` would have shown a 100%
one-time-buyer rate and made the retention analysis meaningless.

**Evidence:** `data_quality_log.md` §2 — 99,441 `customer_id` vs 96,096
`customer_unique_id`.

---

### D-002: GMV scope excludes canceled, unavailable, created orders

**Decision:** GMV includes only `delivered`, `shipped`, `invoiced`,
`processing`, `approved` order statuses. Excludes `canceled` (625),
`unavailable` (609), and `created` (5).

**Why:** Canceled and unavailable orders never generated revenue. `created`
is a transient state that never progressed to payment.

**Effect:** Effective in-scope universe is 98,202 orders.

**Evidence:** `data_quality_log.md` §5.

---

### D-003: GMV defined as item price only; freight tracked separately

**Decision:** `GMV = SUM(order_items.price)`. Freight is a separate measure
(`Freight Revenue`). Their sum is `Total Customer Paid`.

**Why:** Item price is the revenue attributable to the product sale. Freight
is a component of what the customer paid but does not represent product
revenue. The dataset contains no cost data, so no claim is made about
freight's margin contribution.

**Reconciliation:** `SUM(payment_value)` matches
`SUM(price + freight_value)` to within 0.018%. This confirms payments cover
both components.

**Evidence:** `data_quality_log.md` §10.

---

### D-004: Trend window is 2017-01 to 2018-08

**Decision:** All trend analysis uses `order_purchase_timestamp` between
`2017-01-01` and `2018-08-31`.

**Why:** 2016 has only 329 orders (ramp-up) and is not representative.
2018-09 and 2018-10 have 20 orders combined (incomplete tail).

**YoY window:** 2017-01..08 vs 2018-01..08 — the only like-for-like
comparison available.

**Evidence:** `data_quality_log.md` §6.

---

### D-005: Deduplicate reviews by `order_id`, not `review_id`

**Decision:** When an order has multiple review rows, keep the one with the
most recent `review_creation_date`, breaking ties by
`review_answer_timestamp DESC`.

**Why:** `review_id` itself has 814 duplicate values, so it is not a
reliable primary key. `order_id` is the correct partition key. The tiebreak
makes the result deterministic.

**Evidence:** `data_quality_log.md` §4.

---

### D-006: Aggregate payments to order level before joining

**Decision:** Payment values are always `SUM(payment_value) GROUP BY order_id`
before joining to any fact table.

**Why:** 2.98% of orders have multiple payment rows (max: 29). Joining at
row level would inflate revenue.

**Evidence:** `data_quality_log.md` §3.

---

### D-007: Geography dimension uses `LEFT JOIN` on zip prefix

**Decision:** `dim_geography` is joined to customers and sellers via
`LEFT JOIN` on `zip_code_prefix`.

**Why:** 157 customer zip prefixes and 7 seller zip prefixes have no
matching geolocation row. An `INNER JOIN` would silently drop 278 customer
rows and 7 seller rows.

**Evidence:** `data_quality_log.md` §1 (extended FK checks).

---

### D-008: Category names preserved in snake_case; display column added

**Decision:** `dim_product.product_category_name` retains the original
snake_case value. A separate column `category_name_english_display`
Title Cases all 73 categories consistently.

**Why:** Keeps the raw data clean and lets the report consume human-readable
labels by construction. Products with no category are labeled `unknown`
(lowercase in raw column) and rendered as `Unknown` in the display column.

**Manual translations added:**
- `pc_gamer` → `pc_gamer`
- `portateis_cozinha_e_preparadores_de_alimentos` → `kitchen_food_prep_portables`

**Evidence:** `data_quality_log.md` §7.

---

### D-009: 2018 trend treated as hypothesis, not headline

**Decision:** The "2018 flat-to-slightly-down" observation is presented as a
hypothesis that holds across three metrics (raw orders, in-scope orders,
GMV) — not as a headline finding.

**Why:** Only 8 months of 2018 are available, and there is no prior-year
baseline to distinguish decline from seasonality. The +138% YoY growth
figure (Jan–Aug) is dominated by the marketplace ramp-up, not organic
growth.

**Evidence:** `data_quality_log.md` §11.

---

## How to Add an Entry

Use this template:
