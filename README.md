# E-commerce Sales & Customer Analytics

An end-to-end analytics project on ~100,000 real orders from the Olist Brazilian
e-commerce marketplace (2016–2018): raw CSVs → SQL Server (raw / clean / analytics
layers) → tested star schema → Power BI report with DAX, validation and
row-level security.

> **Currency note:** all money values are Brazilian reais (R$). Power BI may show a
> generic `$` symbol on some visuals.

---

## Highlights

| Metric | Value |
|---|---|
| Total GMV (item price, Jan 2017 – Aug 2018) | R$ 13.45 M |
| Orders | 97,905 |
| Average order value | R$ 137.37 |
| Customers | 94,703 |
| Repeat-purchase rate | 3.03 % (2,874 of 94,703) |
| Late-delivery rate | 6.79 % (6,531 of 96,203 measurable orders) |
| Average delivery time | 12.07 days |
| GMV growth, Jan–Aug 2018 vs Jan–Aug 2017 | +138 % (mostly marketplace ramp-up, see findings) |

---

## Report preview

<!-- Edit the file names below to match the images in the screenshots/ folder. -->

<p align="center">
  <img src="https://github.com/Fazle-Karim/Ecommerce-Analytics/blob/main/screenshots/Executive_Overview.png" width="49%" alt="Executive Overview">
  <img src="https://github.com/Fazle-Karim/Ecommerce-Analytics/blob/main/screenshots/Sales_Analysis.png" width="49%" alt="Sales Analysis">
</p>
<p align="center">
  <img src="https://github.com/Fazle-Karim/Ecommerce-Analytics/blob/main/screenshots/Customer%20Analytics.png" width="49%" alt="Customer Analytics">
  <img src="https://github.com/Fazle-Karim/Ecommerce-Analytics/blob/main/screenshots/Cohort%20Retention.png" width="49%" alt="Cohort Retention">
</p>
<p align="center">
  <img src="https://github.com/Fazle-Karim/Ecommerce-Analytics/blob/main/screenshots/Delivery_and_Satisfaction.png" width="49%" alt="Delivery and Satisfaction">
  <img src="https://github.com/Fazle-Karim/Ecommerce-Analytics/blob/main/screenshots/Data%20Model.png" width="49%" alt="Data model">
</p>

A PDF export of the full report is in `documentation/Ecommerce_Report.pdf`.

---

## Business context

**Primary audience:** Head of Sales and Marketing.

**Goal:** turn raw marketplace data into answers about revenue, customers,
retention and delivery quality.

| # | Question | Answered on |
|---|----------|-------------|
| 1 | How are GMV, orders and AOV trending over time? | Executive Overview, Sales Analysis |
| 2 | Which categories and states drive revenue? | Executive Overview, Sales Analysis |
| 3 | Who are the best customers and who is at risk? | Customer Analytics (RFM segments) |
| 4 | What is the repeat rate and how does cohort retention look? | Customer Analytics, Cohort Retention |
| 5 | Does late delivery go together with worse reviews? | Delivery and Satisfaction |
| 6 | How do sellers compare on revenue, reviews and lateness? | Modeled (`dim_seller`) but **not a page in this version** |

---

## Key findings

- **Growth needs context.** GMV for Jan–Aug 2018 was R$ 7.34 M versus R$ 3.08 M for
  Jan–Aug 2017 (+138 %), but the marketplace was still ramping up in early 2017.
  Within 2018, monthly GMV peaked at about R$ 0.99 M in April–May and fell to
  R$ 0.85 M by August (about −15 % from April). Only eight months of 2018 are available.
- **Very few customers return.** 3.03 % of customers placed a second order.
  Champions (2+ orders, recent) are 1,229 customers, 1.3 % of the base. Later-month
  cohort retention is mostly between 0 % and 0.7 %.
- **Most customers are one-time buyers.** Of 94,703 customers, 36,652 (38.7 %) are
  recent one-time buyers and 55,177 (58.3 %) are lapsed one-time buyers.
- **Late delivery goes with much lower reviews.** The average review is 4.29 for
  on-time orders and 2.27 for late orders (−2.02 points). This is an association,
  not proof of cause, and late orders are also less often reviewed at all
  (2.3 % unreviewed versus 0.5 % for on-time orders).
- **Payments reconcile.** `SUM(payment_value)` matches `SUM(price + freight)` within
  0.0176 % on the analytic population, with residuals concentrated in
  credit-card installment orders.

---

## What was built

```
CSV files (9 tables)
   │  BULK INSERT
   ▼
raw schema      → untouched text copy, append-only load log
   │  typed, deduplicated, translated, flagged
   ▼
clean schema    → audit log of every cleaning rule
   │  star schema + RFM + cohorts
   ▼
analytics schema → facts, dimensions, customer_rfm, cohort_retention
   │  slim views (integer keys, no timestamps)
   ▼
bi schema       → imported by Power BI (Import mode)
   ▼
Power BI report → DAX measures, validation page, RLS, drillthrough
```

- **Data model:** two fact tables (`fact_orders` at order grain, `fact_order_items`
  at item grain) with shared dimensions. The two facts are deliberately not related to each other.
- **Power BI report:** five analysis pages plus an order-detail drillthrough page.
- **DAX:** about 25 purposeful measures, each documented with its business question in
  `dax/measures.md`.
- **Validation:** a Power BI page compares every key measure with the independently
  computed control totals (PASS / FAIL). <!-- REMOVE this bullet if the Validation page does not show all PASS. -->
- **Row-level security:** roles filter by customer state (demonstrated in Power BI
  Desktop with "View as"). <!-- REMOVE this bullet if you did not build RLS. -->
- **Control totals and tests:** key expected values are computed in Python
  (`documentation/control_totals.json`) and reproduced by SQL tests.

---

## Data quality and key decisions

Denominators are stated for every rate.

- **Customer identity:** `customer_id` is per order; `customer_unique_id` identifies
  the person. All customer-level analysis uses the latter (99,441 order-level ids vs
  96,096 people).
- **Repeat rate variants:** the report uses 3.03 % (2,874 of 94,703 customers in the
  analytic population). Documentation also mentions 3.04 % (in-scope orders, all dates)
  and 3.12 % (all statuses, 96,096 customers). See `documentation/decision_log.md`.
- **Analytic population:** 97,905 of 99,441 orders (98.46 %) after excluding canceled,
  unavailable and created orders and anything outside 2017-01 → 2018-08.
- **Payments:** 2,961 of 99,440 orders with payments (2.98 %) have multiple payment rows;
  one delivered order has none.
- **Reviews:** 814 duplicate `review_id` rows; 768 of 99,441 orders (0.77 %) have no
  review. Reviews are deduplicated to one per order (latest wins).
- **Referential integrity:** the six core foreign keys have no orphan rows. The
  zip-prefix links to geolocation are not complete: 157 customer and 7 seller
  prefixes have no match, so those records have no coordinates.
- **Geolocation:** 1,000,163 rows reduce to 19,015 zip prefixes.
- **Late flag:** compared by date, only for delivered orders with a delivery date;
  other orders are blank (not "on time").

Full detail: `documentation/data_quality_log.md` and `documentation/metric_definitions.md`.

---

## Testing

| Suite | Checks | Result |
|-------|:------:|:------:|
| `03_cleaning_tests.sql` | 35 | PASS |
| `05_facts_tests.sql` | 52 | PASS |
| `06_rfm_cohorts_tests.sql` | 29 | PASS |
| `07_pandas_compare_tests.sql` | 6 | PASS |
| `08_bi_views_tests.sql` | 21 | PASS |
| **Total** | **143** | **PASS** |

Expected values come from `clean.test_expected_values`, generated from the Python
control totals; a few structural checks (constraints, flags) are defined inside the
test scripts. `07_pandas_compare_tests.sql` proves the SQL RFM and cohort tables match
pandas on all 94,703 customers and 211 cohort cells. A full rebuild from an empty
database passes twice with identical counts (`documentation/rebuild_evidence.md`).

---

## Repository structure

```
Ecommerce-Analytics/
├── data/
│   ├── raw/                  # Kaggle CSVs (git-ignored)
│   └── cleaned/              # generated exports (git-ignored)
├── python/                   # profiling, control totals, parity and coverage scripts
├── sql/
│   ├── 01_raw_tables.sql
│   ├── 02_load_raw.sql
│   ├── 03_cleaning.sql
│   ├── 04_dimensions.sql
│   ├── 05_facts.sql
│   ├── 06_rfm_cohorts.sql
│   ├── 07_bi_views.sql
│   ├── load_pandas_rfm.sql
│   ├── test_expected_values.sql
│   ├── test_expected_cohort.sql
│   └── tests/                # 5 test suites
├── powerbi/
│   ├── Ecommerce_Analytics.pbix
│   └── ecom_theme_v2.json
├── dax/
│   └── measures.md           # every measure with its business question
├── documentation/            # evidence trail and PDF export
├── screenshots/
└── README.md
```

---

## How to reproduce

1. Clone the repo. Install SQL Server (2017 or later; built on 2025 Express), SSMS and
   Python 3 with pandas.
2. Download the Olist CSVs from Kaggle into `data/raw/` and copy them to `C:\data\olist\`.
3. Generate the expected values with the Python scripts in `python/`
   (`control_totals.py`, `compute_delivery_metrics.py`, `compute_rfm_and_cohorts.py`,
   `generate_test_expected_values_sql.py`). The exact sequence used in the verified
   rebuild is in `documentation/rebuild_evidence.md`.
4. Run the SQL in SSMS with **SQLCMD mode on**, in this order:
   1. `sql/01_raw_tables.sql`
   2. `sql/02_load_raw.sql`
   3. `sql/03_cleaning.sql`
   4. `sql/test_expected_values.sql`, then `sql/tests/03_cleaning_tests.sql`
   5. `sql/04_dimensions.sql`
   6. `sql/05_facts.sql`, then `sql/tests/05_facts_tests.sql`
   7. `sql/06_rfm_cohorts.sql`, then `sql/tests/06_rfm_cohorts_tests.sql`
   8. `sql/load_pandas_rfm.sql`, then `sql/tests/07_pandas_compare_tests.sql`
   9. `sql/07_bi_views.sql`, then `sql/tests/08_bi_views_tests.sql`
5. Open `powerbi/Ecommerce_Analytics.pbix` in Power BI Desktop. If your SQL Server name
   differs, change it under **Transform data → Data source settings**, then **Refresh**.
   The report reads only the `bi` views.

---

## Known limitations

- **No cost data**, so no profit. GMV is item price only (freight reported separately)
  and excludes canceled, unavailable and created orders.
- **Short history.** Data ends in August 2018, 2016 is sparse, and year-over-year is
  only comparable for Jan–Aug. The +138 % is mostly marketplace ramp-up.
- **About 97 % of customers buy once**, so RFM segments for repeat customers are small
  and cohort retention values are low.
- **Review comparison is an association.** Late orders are reviewed less often, which may
  slightly bias the average-score gap.
- **Sellers:** the seller dimension is modeled, but sellers are not a report page in this
  version. Multi-seller orders would count for each seller involved.
- **Geography:** 157 customer and 7 seller zip prefixes have no coordinates.
- **Row-level security** filters orders and items by customer state but does not filter
  the standalone cohort tables.
- **Not published to the Power BI Service.** The report reads a local SQL Server; use the
  screenshots and PDF in this repo to view it without rebuilding the database.

---

## Documentation

| File | Purpose |
|------|---------|
| `dax/measures.md` | All DAX measures with business questions |
| `documentation/Ecommerce_Report.pdf` | Export of the Power BI report |
| `documentation/01_business_questions.md` | The business questions |
| `documentation/data_quality_log.md` | Data-quality findings |
| `documentation/metric_definitions.md` | Frozen metric definitions |
| `documentation/decision_log.md` | Modeling and metric decisions with rationale |
| `documentation/control_totals.json` | Pinned expected values |
| `documentation/test_coverage.md` | Mapping of control-total values to tests |
| `documentation/rebuild_evidence.md` | Full rebuild from an empty database |
| `documentation/load_reconciliation.md` | Raw-load reconciliation |
| `documentation/cleaning_reconciliation.md` | Cleaning-layer reconciliation |
| `documentation/analytics_reconciliation.md` | Analytics-layer reconciliation |

---

## Dataset and credit

**Source:** [Olist Brazilian E-commerce Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
Data belongs to Olist. See the dataset page for its license terms. This project is for
learning and portfolio purposes.

---

## Author

**Fazle Karim** — [GitHub](https://github.com/Fazle-Karim)
