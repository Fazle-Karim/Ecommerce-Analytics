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

```
Ecommerce-Analytics/
├── data/
│   ├── raw/                     # Kaggle CSVs (git-ignored)
│   └── cleaned/                 # Intermediate cleaned exports (git-ignored)
├── python/                      # Reproducible profiling and analysis scripts
│   ├── profile_data.py
│   ├── gap_analysis.py
│   ├── repeat_and_reconcile.py
│   ├── diagnose_reconciliation.py
│   ├── reconcile_payments_v2.py
│   ├── order_funnel.py
│   ├── late_flag_check.py
│   ├── ab_gap_check.py
│   ├── control_totals.py
│   └── verify_control_totals.py
├── sql/
│   ├── 01_raw_tables.sql        # Create database, schemas, raw tables
│   ├── 02_load_raw.sql          # TRUNCATE + BULK INSERT (Step 3)
│   ├── 03_cleaning.sql          # Type casting, dedup, translation (Step 4)
│   └── 04_analytics_layer.sql   # Star schema fact and dimension tables (Step 5)
├── powerbi/                     # .pbix report file (git-ignored, screenshots provided)
├── dax/                         # DAX measure documentation
├── documentation/               # Data quality log, metric definitions, decision log,
│                                # control totals, and script outputs (evidence trail)
├── screenshots/                 # Report page images
└── README.md
```

---

## Project Status

**Project started:** October 2026

- [x] Step 1 — Business brief, environment setup, directory structure
- [x] Step 2 — Data collection, profiling, quality log, metric definitions
- [ ] Step 3 — Load raw CSVs into SQL Server (`02_load_raw.sql`)
- [ ] Step 4 — Write cleaning layer (`03_cleaning.sql`)
- [ ] Step 5 — Build analytics star schema (`04_analytics_layer.sql`)
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

- **Repeat customer rate:** 3.04% of 94,986 unique customers (2,887
  customers placed more than one in-scope order). The all-status figure
  (3.12% of 96,096) is documented in `control_totals.json` for reference —
  see `decision_log.md` D-014.
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
  `SUM(price + freight_value)` to within **0.0176%** net across the
  analytic population.

See `documentation/data_quality_log.md` for the complete log with
denominators and script-output sourcing. All numbers are pinned in
`documentation/control_totals.json`.

---

## Documentation

| File | Purpose |
|------|---------|
| `documentation/01_business_questions.md` | The 6 questions driving the report |
| `documentation/data_quality_log.md` | Full data-quality findings and decisions |
| `documentation/metric_definitions.md` | Frozen metric definitions |
| `documentation/decision_log.md` | Running log of modeling decisions |
| `documentation/control_totals.json` | Pinned expected values for SQL verification |
| `documentation/control_totals.md` | Human-readable version of the above |
| `documentation/control_totals_verification.txt` | Self-check output for control totals |
| `documentation/order_funnel.txt` | Raw output of the funnel script |
| `documentation/gap_analysis.txt` | Raw output of the gap analysis script |
| `documentation/repeat_and_reconcile.txt` | Corrected metrics output |
| `documentation/reconcile_payments_v2.txt` | Canonical reconciliation output |
| `documentation/diagnose_reconciliation.txt` | Four-part attribution of the original gap |
| `documentation/late_flag_check.txt` | Late-flag assumption checks |
| `documentation/ab_gap_check.txt` | A+B vs status-total gap diagnostic |
| `documentation/data_profile_raw.txt` | Raw output of the profiling script |

---

## Results & Key Insights

_To be filled in as the analysis is completed._

---

## How to Reproduce

1. Clone the repo.
2. Install SQL Server Developer Edition + SSMS.
3. Download the Olist CSVs from Kaggle into `data/raw/`.
4. Run `python/profile_data.py`, `python/gap_analysis.py`,
   `python/repeat_and_reconcile.py`, `python/order_funnel.py`,
   `python/late_flag_check.py`, `python/diagnose_reconciliation.py`,
   `python/reconcile_payments_v2.py`, `python/ab_gap_check.py`, and
   `python/control_totals.py` to reproduce the data-quality findings.
5. Run `sql/01_raw_tables.sql` to create the database architecture.
6. Load CSVs into the `raw` schema with `sql/02_load_raw.sql` (or the
   Import Flat File wizard).
7. Run `sql/03_cleaning.sql` and `sql/04_analytics_layer.sql`.
8. Open the `.pbix` in Power BI Desktop and refresh.

---

## Author

**Fazle Karim** — [GitHub](https://github.com/Fazle-Karim)