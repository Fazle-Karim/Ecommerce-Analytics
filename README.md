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
│ ├── raw/ # Kaggle CSVs (git-ignored)
│ └── cleaned/ # Intermediate cleaned exports (git-ignored)
├── sql/
│ ├── 01_raw_tables.sql
│ ├── 02_cleaning.sql
│ └── 03_analytics_layer.sql
├── powerbi/ # .pbix report file (git-ignored, screenshots provided)
├── dax/ # DAX measure documentation
├── documentation/ # Business questions, data dictionary, ER diagram
├── screenshots/ # Report page images
└── README.md

text

---

## Project Status

**Project started:** October 2026

- [x] Step 1 — Business brief, environment setup, directory structure
- [ ] Step 2 — Data collection & exploration
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

~100k orders, 9 relational tables:
`orders`, `order_items`, `payments`, `reviews`, `customers`, `sellers`,
`products`, `geolocation`, `category_translation`.

**Known data traps to verify in Step 2:**
- `customer_id` is per-order; `customer_unique_id` identifies the actual person
  (critical for RFM & retention).
- Reviews table has duplicate `review_id` values.
- Payments has multiple rows per order (needs aggregation).
- Geolocation has ~1M rows but only ~19k unique zip prefixes (needs dedup).

---

## Results & Key Insights

_To be filled in as the analysis is completed._

---

## How to Reproduce

1. Clone the repo.
2. Install SQL Server Developer Edition + SSMS.
3. Download the Olist CSVs from Kaggle into `data/raw/`.
4. Run `sql/01_raw_tables.sql` to create the database architecture.
5. Load CSVs into the `raw` schema (BULK INSERT or Import Flat File wizard).
6. Run `sql/02_cleaning.sql` and `sql/03_analytics_layer.sql`.
7. Open the `.pbix` in Power BI Desktop and refresh.

---

## Author

**Fazle Karim** — [LinkedIn](https://www.linkedin.com/in/fazle-karim-b95b0b265/) · [GitHub](https://github.com/Fazle-Karim)