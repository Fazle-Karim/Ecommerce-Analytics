# DAX Measures — Olist Analytics

**Purpose:** Every DAX measure in the Power BI model, with its business question and validation against the pinned control totals.

---

## 1. Core Sales Metrics

### Total GMV

**Question:** How much revenue did we generate in item sales?

    Total GMV = SUM ( bi.fact_order_items[price] )

**Pinned value:** BRL 13,449,529.68

---

### Total Orders

**Question:** How many orders did we process?

    Total Orders = DISTINCTCOUNT ( bi.fact_orders[order_key] )

**Pinned value:** 97,905

---

### Total Items Sold

**Question:** How many individual items were sold?

    Total Items Sold = COUNTROWS ( bi.fact_order_items )

**Pinned value:** 111,752

---

### AOV — Average Order Value

**Question:** What is the average revenue per order?

    AOV = DIVIDE ( [Total GMV], [Total Orders] )

**Pinned value:** BRL 137.37 (13449529.68 / 97905)

---

### Items per Order

**Question:** How many items does the average order contain?

    Items per Order = DIVIDE ( [Total Items Sold], [Total Orders] )

**Pinned value:** 1.14

---

### Freight Charged

**Question:** How much did customers pay in freight?

    Freight Charged = SUM ( bi.fact_order_items[freight_value] )

**Pinned value:** BRL 2,234,177.06

---

### Total Customer Paid

**Question:** What is the total value paid by customers (items + freight)?

    Total Customer Paid = [Total GMV] + [Freight Charged]

**Pinned value:** BRL 15,683,706.74

---

## 2. Delivery and Review Metrics

### Average Delivery Days

**Question:** How long does delivery take on average?

    Avg Delivery Days = AVERAGE ( bi.fact_orders[delivery_days] )

**Pinned value:** 12.0739

---

### Late Orders

**Question:** How many orders were delivered after the estimated date?

    Late Orders = SUM ( bi.fact_orders[is_late] )

**Pinned value:** 6,531

---

### Measurable Orders

**Question:** How many delivered orders have a valid delivery date?

    Measurable Orders = COUNT ( bi.fact_orders[is_late] )

**Pinned value:** 96,203

---

### Late Order Rate

**Question:** What share of measurable orders arrived late?

    Late Rate = DIVIDE ( [Late Orders], [Measurable Orders] )

**Pinned value:** 6.79%

---

### Average Review Score

**Question:** What is the average customer review score?

    Avg Review Score = AVERAGE ( bi.fact_orders[review_score] )

**Pinned value:** 4.0863

---

### Average Review Score — Late Orders

**Question:** What is the average review score for late orders?

    Avg Review Score (Late) = CALCULATE ( AVERAGE ( bi.fact_orders[review_score] ), bi.fact_orders[is_late] = 1 )

**Pinned value:** 2.2709

---

### Average Review Score — On-Time Orders

**Question:** What is the average review score for on-time orders?

    Avg Review Score (On Time) = CALCULATE ( AVERAGE ( bi.fact_orders[review_score] ), bi.fact_orders[is_late] = 0 )

**Pinned value:** 4.2910

---

### Late vs On-Time Review Gap

**Question:** How many review points does a late delivery cost us?

    Late Review Gap = [Avg Review Score (Late)] - [Avg Review Score (On Time)]

**Pinned value:** -2.0201 points

---

## 3. Customer Metrics

### Unique Customers

**Question:** How many unique people placed orders?

    Unique Customers = DISTINCTCOUNT ( bi.dim_customer[customer_unique_id] )

**Pinned value:** 96,096

---

### Repeat Customers

**Question:** How many customers placed more than one order?

    Repeat Customers = SUMX ( VALUES ( bi.dim_customer[customer_unique_id] ), IF ( CALCULATE ( [Total Orders] ) > 1, 1, 0 ) )

**Pinned value:** 2,874

---

### Repeat Rate

**Question:** What share of the customer base is repeat buyers?

    Repeat Rate = DIVIDE ( [Repeat Customers], [Unique Customers] )

**Pinned value:** 3.03%

---

## 4. Time Intelligence

### GMV YTD

**Question:** How much revenue have we generated year-to-date?

    GMV YTD = TOTALYTD ( [Total GMV], bi.dim_date[full_date] )

---

### GMV YoY %

**Question:** How does this year's revenue compare to last year?

    GMV YoY % = VAR Current = [Total GMV] VAR Prior = CALCULATE ( [Total GMV], SAMEPERIODLASTYEAR ( bi.dim_date[full_date] ) ) RETURN DIVIDE ( Current - Prior, Prior )

---

### Orders MoM %

**Question:** How did order volume change versus last month?

    Orders MoM % = VAR Current = [Total Orders] VAR Prior = CALCULATE ( [Total Orders], DATEADD ( bi.dim_date[full_date], -1, MONTH ) ) RETURN DIVIDE ( Current - Prior, Prior )

---

### GMV Rolling 12M

**Question:** What is the trailing 12-month revenue?

    GMV Rolling 12M = CALCULATE ( [Total GMV], DATESINPERIOD ( bi.dim_date[full_date], MAX ( bi.dim_date[full_date] ), -12, MONTH ) )

---

## 5. RFM Segment Metrics

### Champions Count

**Question:** How many high-value repeat customers do we have?

    Champions = CALCULATE ( COUNTROWS ( bi.dim_customer ), bi.dim_customer[segment] = "Champions" )

**Pinned value:** 1,229

---

### Loyal Count

**Question:** How many loyal customers do we have?

    Loyal = CALCULATE ( COUNTROWS ( bi.dim_customer ), bi.dim_customer[segment] = "Loyal" )

**Pinned value:** 612

---

### At Risk Count

**Question:** How many customers are at risk of churning?

    At Risk = CALCULATE ( COUNTROWS ( bi.dim_customer ), bi.dim_customer[segment] = "At Risk" )

**Pinned value:** 1,033

---

## 6. Cohort Metrics

### Cohort Size

**Question:** How many customers are in each cohort?

    Cohort Size = MAX ( bi.cohort_retention[cohort_size] )

---

### Active Customers

**Question:** How many customers were active at a given offset?

    Active Customers = SUM ( bi.cohort_retention[active_customers] )

---

### Retention %

**Question:** What is the average retention rate across cohorts?

    Retention % = AVERAGE ( bi.cohort_retention[retention_pct] )

---

## 7. Validation Summary

| Measure | DAX value | Pinned value | Match |
|---------|----------:|-------------:|:-----:|
| Total GMV | - | 13449529.68 | TBD |
| Total Orders | - | 97905 | TBD |
| Total Items Sold | - | 111752 | TBD |
| AOV | - | 137.37 | TBD |
| Freight Charged | - | 2234177.06 | TBD |
| Total Customer Paid | - | 15683706.74 | TBD |
| Avg Delivery Days | - | 12.0739 | TBD |
| Late Orders | - | 6531 | TBD |
| Measurable Orders | - | 96203 | TBD |
| Late Rate | - | 6.79% | TBD |
| Avg Review Score | - | 4.0863 | TBD |
| Avg Review Score (Late) | - | 2.2709 | TBD |
| Avg Review Score (On Time) | - | 4.2910 | TBD |
| Late Review Gap | - | -2.0201 | TBD |
| Unique Customers | - | 96096 | TBD |
| Repeat Customers | - | 2874 | TBD |
| Repeat Rate | - | 3.03% | TBD |
| Champions | - | 1229 | TBD |
| Loyal | - | 612 | TBD |
| At Risk | - | 1033 | TBD |

"TBD" will be filled in during validation after the DAX is created in Power BI.
