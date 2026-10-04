# Decision Log — Olist Analytics

**Analyst:** Fazle Karim
**Date:** October 2026
**Version:** 1.3
**Purpose:** A running log of every non-obvious modeling, metric, or
cleaning decision made during this project. Each entry includes what was
decided, why, and what alternative was rejected. Interviewers ask "why did
you do it this way?" — this file is the answer.

Entries are added in chronological order. Once a decision is logged it is
considered frozen unless a later entry supersedes it.

> **Rule:** every number referenced below is pinned in
> `documentation/control_totals.json` and verified by
> `python/verify_control_totals.py`.

> **Markdown note:** Currency values are written as `BRL` or wrapped in
> backticks to prevent GitHub from rendering `$` as math.

---

## 2026-10 — Step 2 Data Exploration

### D-001: Use `customer_unique_id` as the customer key

**Decision:** All RFM, cohort, repeat-purchase, and customer-level analysis
uses `customer_unique_id`, never `customer_id`.

**Why:** `customer_id` is unique per order; only `customer_unique_id`
identifies the person. Using `customer_id` would have shown a 100%
one-time-buyer rate and made the retention analysis meaningless.

**Evidence:** `data_quality_log.md` §3 — 99,441 `customer_id` vs 96,096
`customer_unique_id`.

---

### D-002: GMV scope excludes canceled, unavailable, created orders

**Decision:** GMV includes only `delivered`, `shipped`, `invoiced`,
`processing`, `approved` order statuses. Excludes `canceled` (625),
`unavailable` (609), and `created` (5).

**Why:** Every order with an excluded status has a payment record. The
dataset contains **no refund data** — whether the money was returned is
unknown. The order status indicates the order did not complete as a sale.
`created` is not a transient state with no payment: all 5 created orders
have a payment row.

**Effect:** In-scope universe is 98,202 orders before the time-window filter.

**Evidence:** `data_quality_log.md` §6 (payment record check).

---

### D-003: GMV defined as item price only; freight tracked separately

**Decision:** `GMV = SUM(order_items.price)`. Freight is a separate measure
(`Freight Charged`). Their sum is `Total Customer Paid`.

**Why:** Item price is the revenue attributable to the product sale.
Freight is a component of what the customer paid but is not called
"revenue" — the dataset contains no cost data to determine margin.

**Pinned values on the analytic population:**
- GMV: `BRL 13,449,529.68`
- Freight Charged: `BRL 2,234,177.06`
- Total Customer Paid: `BRL 15,683,706.74`

**Reconciliation:** `SUM(payment_value)` on the analytic population matches
`Total Customer Paid` to within `BRL 2,762.33` net (0.0176%) and
`BRL 3,033.13` absolute (0.0193%). The residual concentrates in
credit_card orders with installments > 1, consistent with installment
interest charged to the customer.

**Evidence:** `data_quality_log.md` §11; `documentation/reconcile_payments_v2.txt`.

---

### D-004: Trend window is 2017-01-01 to 2018-08-31

**Decision:** All trend analysis uses `order_purchase_timestamp` with a
**half-open interval**: `>= '2017-01-01' AND < '2018-09-01'`.

**Why:** 2016 has only 329 orders (ramp-up) and is not representative.
2018-09 and 2018-10 have 20 orders combined (incomplete tail); after the
in-scope filter, only 1 order remains in that tail.

**Boundary convention:** Half-open intervals (`>= start AND < end`). Using
`BETWEEN '2017-01-01' AND '2018-08-31'` on a timestamp column excludes
every order placed after midnight on 31 August. The half-open form
prevents that class of bug.

**YoY window:** `>= '2017-01-01' AND < '2017-09-01'` vs
`>= '2018-01-01' AND < '2018-09-01'` — the only like-for-like comparison.

**Pinned year splits:** 2017-01..12 in-scope = 44,375 orders; 2018-01..08
in-scope = 53,530; all statuses in-window = 99,092.

**Evidence:** `data_quality_log.md` §7; `control_totals.json` year_splits.

---

### D-005: Deduplicate reviews by `order_id`, not `review_id`

**Decision:** When an order has multiple review rows, keep the one with the
most recent `review_creation_date`, breaking ties by
`review_answer_timestamp DESC`.

**Why:** `review_id` itself has 814 duplicate values, so it is not a
reliable primary key. `order_id` is the correct partition key. The tiebreak
makes the result deterministic.

**Evidence:** `data_quality_log.md` §5.

---

### D-006: Aggregate payments to order level before joining

**Decision:** Payment values are always `SUM(payment_value) GROUP BY order_id`
before joining to any fact table.

**Why:** 2.98% of orders have multiple payment rows (max: 29). Joining at
row level would inflate revenue.

**Evidence:** `data_quality_log.md` §4.

---

### D-007: Geography dimension uses `LEFT JOIN` on zip prefix

**Decision:** `dim_geography` is joined to customers and sellers via
`LEFT JOIN` on `zip_code_prefix`.

**Why:** 157 customer zip prefixes and 7 seller zip prefixes have no
matching geolocation row. An `INNER JOIN` would silently drop 278 customer
rows and 7 seller rows.

**Evidence:** `data_quality_log.md` §1.

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

**Display-name override:** Simple Title Case turns `pc_gamer` into
`Pc Gamer`. A single override forces `PC Gamer` in the display column.
All other categories use plain Title Case.

**Evidence:** `data_quality_log.md` §8.

---

### D-009: 2018 trend treated as hypothesis, not headline

**Decision:** The "2018 flat-to-slightly-down" observation is presented as a
hypothesis that holds across three metrics (raw orders, in-scope orders,
GMV) — not as a headline finding.

**Why:** Only 8 months of 2018 are available, and there is no prior-year
baseline to distinguish decline from seasonality. The +138% YoY growth
figure (Jan–Aug) is dominated by the marketplace ramp-up, not organic
growth.

**Evidence:** `data_quality_log.md` §13.

---

### D-010: Reconciliation fix — population mismatch, not netting

**Decision:** The original payments-vs-items reconciliation reported a
misleading headline figure because the two totals were computed on two
different order populations. The rebuilt script defines the population
once as a single list of order_ids (in-scope, in-window, has-item-rows),
and computes both sums by joining to that list.

**Why it mattered:** The original LEFT total restricted items to in-scope
statuses; the RIGHT total joined payments to that population via an
**outer** join, silently pulling in payments from out-of-scope orders and
orders outside the time window. The `BRL 273,345.09` gap was a population
mismatch, not a revenue gap. The correct net residual on the analytic
population is `BRL 2,762.33` (0.0176%).

**Structural change:** The rebuilt script
(`python/reconcile_payments_v2.py`) includes an assertion that aborts if
the two sides cover different numbers of orders. This class of bug now
fails loudly.

**Note on the first diagnosis:** The initial diagnosis attributed the
discrepancy to "netting" of positive and negative residuals. That was
mathematically wrong — summation is linear, so
`SUM(A − B) = SUM(A) − SUM(B)` on the same population. A review caught
this. The diagnosis script (`python/diagnose_reconciliation.py`) confirms
the correct cause.

**Evidence:** `data_quality_log.md` §11; `documentation/reconcile_payments_v2.txt`;
`documentation/diagnose_reconciliation.txt`.

---

### D-011: Analytic population = 97,905 orders

**Decision:** The analytic population for all revenue, product, seller, and
delivery metrics is defined as a three-step funnel:

1. Status in-scope → 98,202
2. `order_purchase_timestamp` in `[2017-01-01, 2018-09-01)` → 97,905
3. Has at least one row in `order_items` → 97,905

**Why:** Every metric must operate on a single, well-defined population.
The funnel is reproducible (`python/order_funnel.py`) and independently
verified step by step.

**Surprise:** No in-scope, in-window order lacks item rows. The 775 raw
orders with no items are all out-of-scope status or outside the window.

**Evidence:** `data_quality_log.md` §2; `documentation/order_funnel.txt`.

---

### D-012: Late flag compares dates, not timestamps

**Decision:** An order is late if
`DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)`.
Both sides normalized to midnight before comparison.

**Why:** `order_estimated_delivery_date` is always at midnight (0 of
99,441 rows have a non-midnight time). A raw delivery timestamp compared
against a midnight estimated date misclassifies 1,292 orders — they were
delivered on the estimated day but after midnight.

**Additional rule:** Delivered orders with a null delivery date (8 orders,
0.0083%) are excluded from the late-rate denominator but retained in
Order Count.

**Late-rate denominator = 96,203 orders. Late rate = 6.79%.**

**Evidence:** `data_quality_log.md` §12; `documentation/late_flag_check.txt`.

---

### D-013: Verify payment record for excluded statuses

**Decision:** Before excluding canceled, unavailable, and created orders
from GMV, verify they were charged.

**Why:** The exclusion rule needs a factual basis, not an assumption. If
these orders lacked payments entirely, they'd represent a different kind
of data-quality issue.

**Result:** All 1,239 excluded-status orders have a payment row. Total
`BRL 270,423.21`. **The dataset contains no refund data** — whether the
money was returned is not recorded. The order status indicates the order
did not complete.

**Additional edge case:** 6 canceled orders have a delivery date. These
remain excluded along with all other canceled orders.

**Evidence:** `data_quality_log.md` §6; `documentation/late_flag_check.txt` Q4.

---

### D-014: Repeat-rate population = in-scope statuses (3.04%)

**Decision:** The reported repeat purchase rate is **3.04%** (2,887
repeaters of 94,986 customers), computed over **in-scope statuses only**
(delivered, shipped, invoiced, processing, approved).

**Why:** A canceled order is not a purchase — our own GMV rule (D-002)
treats canceled, unavailable, and created orders as not completing as a
sale. Using the all-status population would count a customer whose only
repeat activity was a canceled second order as a "repeater," contradicting
the same rule that governs every other customer metric in this project
(new customers, returning customers, RFM). The report uses one figure, and
that figure is consistent with the rest of the report.

**Alternative rejected:** The full-base all-status rate (3.12% — 2,997 of
96,096). It is documented in `control_totals.json`
(`repeat_rate_all_statuses_pct`) for reference but is not the reported
figure.

**Both values pinned in `control_totals.json`** under
`customers.repeat_rate_all_statuses_pct` and
`customers.repeat_rate_in_scope_pct`.

**Evidence:** `data_quality_log.md` §3; `python/control_totals.py`.

---

### D-015: Round to cents before comparing in reconciliation

**Decision:** In the payments reconciliation and the diagnosis, both sides
are rounded to 2 decimal places before computing differences.

**Why:** The dataset shows floating-point noise (values like
`-1.705303e-13`), which would otherwise be counted as a residual. Rounding
to cents removes the noise and produces an honest distribution.

**Effect:** `orders_exact_match` = 97,336; `orders_differ_one_cent` = 273;
`orders_within_one_cent` = 97,609. Net and absolute residuals unchanged
(`BRL 2,762.33` and `BRL 3,033.13`).

**Evidence:** `data_quality_log.md` §11.3; `control_totals.json`.

---

### D-016: Date windows use half-open intervals

**Decision:** Every date window in SQL, DAX, and Python uses a half-open
interval: `>= start AND < end`, never `BETWEEN start AND end`.

**Why:** On a timestamp column, `BETWEEN '2017-01-01' AND '2018-08-31'`
excludes every row placed after midnight on 31 August. The half-open form
`>= '2017-01-01' AND < '2018-09-01'` includes the entire end date and
prevents off-by-one-day bugs.

**Where it applies:** Time filter (metric_definitions §2), YoY window
(§5.2), MoM, rolling 12-month, and any ad-hoc date window in SQL or DAX.

**Evidence:** `data_quality_log.md` §2, §7; `metric_definitions.md` §2, §5.2.

---

## How to Add an Entry

Use this template when adding a new decision:
D-NNN: Short title
Decision: What was decided.

Why: The reasoning, including the alternative rejected.

Evidence: Where the supporting numbers live (file and section).

text

Number sequentially. Do not delete or edit prior entries — if a decision is
later reversed, add a new entry that supersedes it and reference the old one.