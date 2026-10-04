# Control Totals — Olist Analytics

**Generated:** 2026-10-04 06:37:05.552189
**Source:** `python/control_totals.py` (re-runnable)
**JSON:** `documentation/control_totals.json`

> Every number in this file is derived from the raw CSVs by script.
> No value is hand-entered. Any SQL layer built on top of this
> project must reproduce these totals exactly.

---

## Raw-Level Values (Step 3 load verification)

| Metric | Value |
|--------|------:|
| orders row count | `99,441` |
| order_items row count | `112,650` |
| payments row count | `103,886` |
| reviews row count | `99,224` |
| customers row count | `99,441` |
| sellers row count | `3,095` |
| products row count | `32,951` |
| geolocation row count | `1,000,163` |
| category_translation row count | `71` |
| distinct orders.order_id | `99,441` |
| distinct customers.customer_unique_id | `96,096` |
| SUM(items.price) raw | `BRL 13,591,643.70` |
| SUM(items.freight_value) raw | `BRL 2,251,909.54` |
| SUM(payments.payment_value) raw | `BRL 16,008,872.12` |

## Order Funnel

| Metric | Value |
|--------|------:|
| Step 0 — Raw orders | `99,441` |
| Step 1 — In-scope status | `98,202` |
| Step 2 — In-scope and in-window | `97,905` |
| Step 3 — Analytic population | `97,905` |

## Revenue on Analytic Population

| Metric | Value |
|--------|------:|
| GMV (item price only) | `BRL 13,449,529.68` |
| Freight Charged | `BRL 2,234,177.06` |
| Total Customer Paid | `BRL 15,683,706.74` |

## Payments Reconciliation

| Metric | Value |
|--------|------:|
| Payments total | `BRL 15,686,469.07` |
| Items total | `BRL 15,683,706.74` |
| Net residual | `BRL 2,762.33` |
| Absolute residual | `BRL 3,033.13` |
| Orders exactly equal | `97,336` |
| Orders differing by 1 cent | `273` |
| Orders within 1 cent | `97,609` |
| Orders with larger diff | `296` |
| Orders compared | `97,905` |

## Customers

| Metric | Value |
|--------|------:|
| Unique customers (all statuses) | `96,096` |
| Repeat customers (all statuses) | `2,997` |
| Repeat rate % (all statuses) | `3.12` |
| Unique customers (in-scope) | `94,986` |
| Repeat customers (in-scope) | `2,887` |
| Repeat rate % (in-scope) | `3.04` |
| Unique customers (analytic population) | `94,703` |
| Repeat customers (analytic population) | `2,874` |

## Late Rate

| Metric | Value |
|--------|------:|
| Denominator | `96,203` |
| Late orders | `6,531` |
| Late rate % | `6.79` |

## Reviews

| Metric | Value |
|--------|------:|
| Orders with deduped review | `98,673` |
| Average review score | `4.09` |
| Average review score (late) | `2.27` |
| Average review score (on-time) | `4.29` |
| Late vs on-time gap | `-2.02` |

## Excluded Statuses

| Metric | Value |
|--------|------:|
| Payments on canceled/unavailable/created | `BRL 270,423.21` |

## Year Splits

| Metric | Value |
|--------|------:|
| In-window orders 2017 (in-scope) | `44,375` |
| In-window orders 2018 (in-scope) | `53,530` |
| In-window orders 2017+2018 (all statuses) | `99,092` |

## Monthly Window (2017-01 to 2018-08)

| Month | Orders (all statuses) | Orders (in-scope) | GMV (in-scope, item price) |
|-------|----------------------:|------------------:|---------------------------:|
| 2017-01 | 800 | 787 | `BRL 120,098.27` |
| 2017-02 | 1,780 | 1,718 | `BRL 244,959.35` |
| 2017-03 | 2,682 | 2,617 | `BRL 368,341.32` |
| 2017-04 | 2,404 | 2,377 | `BRL 353,842.98` |
| 2017-05 | 3,700 | 3,640 | `BRL 503,159.19` |
| 2017-06 | 3,245 | 3,205 | `BRL 429,916.61` |
| 2017-07 | 4,026 | 3,946 | `BRL 492,287.30` |
| 2017-08 | 4,331 | 4,272 | `BRL 568,245.79` |
| 2017-09 | 4,285 | 4,227 | `BRL 621,415.91` |
| 2017-10 | 4,631 | 4,547 | `BRL 660,179.62` |
| 2017-11 | 7,544 | 7,421 | `BRL 1,003,862.14` |
| 2017-12 | 5,673 | 5,618 | `BRL 742,183.79` |
| 2018-01 | 7,269 | 7,187 | `BRL 945,456.29` |
| 2018-02 | 6,728 | 6,624 | `BRL 837,895.43` |
| 2018-03 | 7,211 | 7,168 | `BRL 981,051.06` |
| 2018-04 | 6,939 | 6,919 | `BRL 993,592.98` |
| 2018-05 | 6,873 | 6,833 | `BRL 992,871.75` |
| 2018-06 | 6,167 | 6,145 | `BRL 863,265.53` |
| 2018-07 | 6,292 | 6,233 | `BRL 878,044.27` |
| 2018-08 | 6,512 | 6,421 | `BRL 848,860.10` |

## Top 10 Categories by GMV (analytic population)

| Rank | Category | GMV |
|-----:|----------|----:|
| 1 | `beleza_saude` | `BRL 1,251,145.54` |
| 2 | `relogios_presentes` | `BRL 1,194,824.97` |
| 3 | `cama_mesa_banho` | `BRL 1,035,485.07` |
| 4 | `esporte_lazer` | `BRL 977,728.77` |
| 5 | `informatica_acessorios` | `BRL 902,922.70` |
| 6 | `moveis_decoracao` | `BRL 721,584.27` |
| 7 | `utilidades_domesticas` | `BRL 625,538.73` |
| 8 | `cool_stuff` | `BRL 619,724.39` |
| 9 | `automotivo` | `BRL 585,177.48` |
| 10 | `ferramentas_jardim` | `BRL 479,650.06` |
