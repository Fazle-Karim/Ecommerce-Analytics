# Control Totals — Olist Analytics

**Generated:** 2026-10-04 05:37:57.133723
**Source:** `python/control_totals.py` (re-runnable)
**JSON:** `documentation/control_totals.json`

> Every number in this file is derived from the raw CSVs by script.
> No value is hand-entered. Any SQL layer that this project builds
> must reproduce these totals exactly. Discrepancies are bugs.

---

## Dataset

| Metric | Value |
|--------|------:|
| Raw orders | 99,441 |
| Raw customers | 99,441 |
| Raw order_items rows | 112,650 |
| Raw payments rows | 103,886 |

## Order Funnel

| Metric | Value |
|--------|------:|
| Step 0 — Raw orders | 99,441 |
| Step 1 — In-scope status | 98,202 |
| Step 2 — In-scope and in-window | 97,905 |
| Step 3 — Analytic population | 97,905 |

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
| Orders exact match | 97,336 |
| Orders with diff | 569 |
| Orders compared | 97,905 |

## Customers

| Metric | Value |
|--------|------:|
| Unique customers (all statuses) | 96,096 |
| Repeat customers (all statuses) | 2,997 |
| Repeat rate % (all statuses) | 3.12 |
| Unique customers (in-scope statuses) | 94,986 |
| Repeat customers (in-scope statuses) | 2,887 |
| Repeat rate % (in-scope statuses) | 3.04 |

## Late Rate

| Metric | Value |
|--------|------:|
| Late rate denominator | 96,203 |
| Late orders | 6,531 |
| Late rate % | 6.79 |

## Excluded Statuses

| Metric | Value |
|--------|------:|
| Payments on canceled / unavailable / created | 270,423.21 |

## Year Splits

| Metric | Value |
|--------|------:|
| In-window orders 2017 (in-scope) | 44,375 |
| In-window orders 2018 (in-scope) | 53,530 |
| In-window orders 2017+2018 (all statuses) | 99,092 |
