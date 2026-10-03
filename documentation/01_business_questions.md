# Business Questions — Olist Analytics Project

**Audience:** Executive Leadership Team (Head of Sales & Marketing Manager)

**Purpose:** Every SQL script, DAX measure, and report page must trace back to
one of these questions. If a visual doesn't answer one of them, it doesn't
belong in the report.

---

## Primary Business Questions

| # | Question | Primary Metric | Comparison |
|---|----------|---------------|------------|
| 1 | How are GMV, orders, and AOV trending, and how do they compare YoY across like-for-like periods? | GMV, Orders, AOV | YoY, MoM |
| 2 | Which product categories and Brazilian states drive the highest revenue, and which are underperforming or declining? | Revenue by category/state | YoY change |
| 3 | Who are our highest-value customers, and what proportion of our base is at risk of churning? | RFM score, segment mix | Current period |
| 4 | What is our repeat purchase rate, and how do monthly customer cohorts retain over time? | Repeat %, cohort retention curve | By first-purchase month |
| 5 | Does delivery delay impact customer review scores, and by how much? | Avg review score, % late orders | Late vs. on-time |
| 6 | How are sellers distributed by revenue, review scores, and late-delivery rates? | Seller revenue, avg review, % late | Top/bottom decile |

---

## Secondary / Follow-up Questions (deferred)

- Which payment types correlate with higher AOV?
- Is there a seasonal pattern in category demand?
- Which product categories have the highest freight-to-price ratio?

---

## Success Criteria

The final report will be considered complete when:

1. Each of the 6 questions has at least one dedicated visual or page section.
2. Every KPI is time-aware (YoY, MoM, or cohort-based).
3. RFM and cohort analyses use `customer_unique_id` — never `customer_id`.
4. Report loads in under 5 seconds on a laptop.
5. A reviewer unfamiliar with the data can understand each insight from the
   visual alone.

---

*Last updated: October 2026*