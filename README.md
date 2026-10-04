# E-commerce Sales & Customer Analytics

An end-to-end data analytics project analyzing ~100,000 real orders from the
Olist Brazilian E-commerce marketplace (2016–2018). The deliverable is a
multi-page Power BI report backed by a clean SQL Server data warehouse and a
proper star-schema model.

---

## Business Context

**Audience:** Executive Leadership Team — Head of Sales & Marketing Manager.

**Goal:** Answer 6 core business questions about revenue performance, product
& regional growth, customer value, retention, logistics quality, and seller
performance — turning raw transactional data into actionable insights.

---

## Key Business Questions

| # | Question | Primary Metric |
|---|----------|----------------|
| 1 | How are GMV, orders, and AOV trending YoY? | GMV, Orders, AOV |
| 2 | Which categories and Brazilian states drive revenue? | Revenue by dimension |
| 3 | Who are our best customers, and who is at risk of churning? | RFM segments |
| 4 | What is our repeat purchase rate and monthly cohort retention? | Repeat %, cohort curve |
| 5 | Does delivery delay impact review scores? | Avg review, % late |
| 6 | How do sellers distribute by revenue, reviews, and late rate? | Seller scorecard |

---

## Tech Stack

- **Database:** SQL Server (Developer Edition)
- **ETL:** SQL (raw → clean → analytics layered pipeline)
- **BI:** Power BI Desktop
- **Modeling:** DAX (30+ measures)
- **Version control:** Git + GitHub

---

## Repository Structure
Ecommerce-Analytics/
├── data/
│   ├── raw/               # Kaggle CSVs (git-ignored)
│   └── cleaned/           # Intermediate cleaned exports (git-ignored)
├── python/                # Reproducible profiling and analysis scripts
│   ├── profile_data.py
│   ├── gap_analysis.py
│   ├── repeat_and_reconcile.py
│   ├── diagnose_reconciliation.py
│   ├── reconcile_payments_v2.py
│   ├── order_funnel.py
│   ├── late_flag_check.py
│   ├── control_totals.py
│   └── verify_control_totals.py
├── sql/
│   ├── 01_raw_tables.sql
│   ├── 02_cleaning.sql
│   └── 03_analytics_layer.sql
├── powerbi/               # .pbix report file (git-ignored, screenshots provided)
├── dax/                   # DAX measure documentation
├── documentation/         # Data quality log, metric definitions, decision log,
│                          # control totals, and script outputs (evidence trail)
├── screenshots/           # Report page images
└── README.md

text

---

## Project Status

**Project started:** October 2026

- [x] Step 1 — Business brief, environment setup, directory structure
- [x] Step 2 — Data collection, profiling, quality log, metric definitions
- [ ] Step 3 — Load raw CSVs into SQL Server
- [ ] Step 4 — Write cleaning layer (`02_cleaning.sql`)
- [ ] Step 5 — Build analytics star schema (`03_analytics_layer.sql`)
- [ ] Step 6 — Connect Power BI and model data
- [ ] Step 7 — Write DAX measures (core, time intelligence, RFM, cohorts)
- [ ] Step 8 — Design multi-page report
- [ ] Step 9 — Optimize & apply row-level security
- [ ] Step 10 — Publish, document, and present

---

## Dataset

**Source:** [Olist Brazilian E-commerce Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

~100k orders across 9 relational tables, 2016–2018:
`orders`, `order_items`, `payments`, `reviews`, `customers`, `sellers`,
`products`, `geolocation`, `category_translation`.

**Verified data characteristics** (from `documentation/data_quality_log.md`):

- **Repeat customer rate:** 3.12% of 96,096 unique customers
  (2,997 customers placed more than one order).
- **Customer identity:** `customer_id` is unique per order;
  `customer_unique_id` identifies the actual person. All customer-level
  analysis uses the latter.
- **Referential integrity:** 100% clean across all 6 core foreign keys.
- **Multi-payment orders:** 2.98% of 99,440 orders have more than one
  payment row (max: 29). Payments are aggregated to order level.
- **Multi-item orders:** 9.94% of 98,666 item-orders have more than one
  product row.
- **Reviews:** 814 duplicate `review_id` rows; 547 orders have more than one
  review; 768 orders (0.77%) have no review. Deduplication keeps the latest
  review per order.
- **Order statuses:** 97.02% delivered. GMV scope excludes canceled (625),
  unavailable (609), and created (5) orders.
- **Date coverage:** The dataset ramps up through 2016 (329 orders) and
  tails off in Sept–Oct 2018 (20 orders). Effective analysis window is
  2017-01 → 2018-08.
- **Geolocation:** 1,000,163 rows collapse to 19,015 unique zip prefixes
  (98.1% reduction).
- **Payment reconciliation:** `SUM(payment_value)` matches
  `SUM(price + freight_value)` to within **0.018%** across in-scope orders.

See `documentation/data_quality_log.md` for the complete log with
denominators and script-output sourcing.

---

## Documentation

| File | Purpose |
|------|---------|
| `documentation/01_business_questions.md` | The 6 questions driving the report |
| `documentation/data_quality_log.md` | Full data-quality findings and decisions |
| `documentation/metric_definitions.md` | Frozen metric definitions (v1.0) |
| `documentation/decision_log.md` | Running log of modeling decisions |
| `documentation/gap_analysis.txt` | Raw output of the gap analysis script |
| `documentation/repeat_and_reconcile.txt` | Raw output of the corrected metrics script |
| `documentation/data_profile_raw.txt` | Raw output of the profiling script |

---

## Results & Key Insights

_To be filled in as the analysis is completed._

---

## How to Reproduce

1. Clone the repo.
2. Install SQL Server Developer Edition + SSMS.
3. Download the Olist CSVs from Kaggle into `data/raw/`.
4. Run `python/profile_data.py`, `python/gap_analysis.py`, and
   `python/repeat_and_reconcile.py` to reproduce the data-quality findings.
5. Run `sql/01_raw_tables.sql` to create the database architecture.
6. Load CSVs into the `raw` schema (BULK INSERT or Import Flat File wizard).
7. Run `sql/02_cleaning.sql` and `sql/03_analytics_layer.sql`.
8. Open the `.pbix` in Power BI Desktop and refresh.

---

## Author

**Fazle Karim** — [GitHub](https://github.com/Fazle-Karim)