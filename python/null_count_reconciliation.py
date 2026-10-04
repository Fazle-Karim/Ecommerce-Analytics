"""
null_count_reconciliation.py
Purpose: Compare per-column null/empty counts between source CSVs and loaded
         SQL Server tables. Catches empty-field handling issues before Step 4.
Output:  documentation/null_count_reconciliation.txt
"""

import pandas as pd
import pyodbc
from pathlib import Path
import sys

RAW = Path("data/raw")
OUT = Path("documentation/null_count_reconciliation.txt")

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

# ------------------------------------------------------------------
# SQL Server connection (adjust if needed)
# ------------------------------------------------------------------
CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=.\\SQLEXPRESS;"
    "DATABASE=OlistAnalytics;"
    "Trusted_Connection=yes;"
)

try:
    conn = pyodbc.connect(CONN_STR)
except Exception as e:
    print(f"Connection failed: {e}")
    print("Adjust CONN_STR and retry.")
    sys.exit(1)

# ------------------------------------------------------------------
# Files -> table mapping
# ------------------------------------------------------------------
FILES = {
    "orders":               "olist_orders_dataset.csv",
    "order_items":          "olist_order_items_dataset.csv",
    "payments":             "olist_order_payments_dataset.csv",
    "reviews":              "olist_order_reviews_dataset.csv",
    "customers":            "olist_customers_dataset.csv",
    "sellers":              "olist_sellers_dataset.csv",
    "products":             "olist_products_dataset.csv",
    "geolocation":          "olist_geolocation_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}

log(f"Null-count reconciliation — {pd.Timestamp.now()}")
log("=" * 72)

total_mismatches = 0

for table, fname in FILES.items():
    log(f"\n## {table}  ({fname})")

    # CSV side
    df = pd.read_csv(RAW / fname, dtype=str, encoding="utf-8", keep_default_na=False, na_values=[""])
    csv_nulls = df.isnull().sum()

    # SQL side
    cur = conn.cursor()
    cols = [c for c in df.columns]
    query = f"""
    SELECT
        {', '.join([f'SUM(CASE WHEN {c} IS NULL THEN 1 ELSE 0 END) AS null_{c}' for c in cols])}
    FROM raw.{table}
    """
    cur.execute(query)
    row = cur.fetchone()
    sql_nulls = {c: int(row[i]) for i, c in enumerate(cols)}

    # Compare
    log(f"\n  {'column':<35} {'csv_nulls':>10} {'sql_nulls':>10}  match")
    log(f"  {'-' * 35} {'-' * 10} {'-' * 10}  -----")
    for c in cols:
        cn = int(csv_nulls[c])
        sn = sql_nulls[c]
        match = "OK" if cn == sn else "MISMATCH"
        if cn != sn:
            total_mismatches += 1
        log(f"  {c:<35} {cn:>10} {sn:>10}  {match}")

    cur.close()

log(f"\n\n{'=' * 72}")
log(f"TOTAL MISMATCHES: {total_mismatches}")
if total_mismatches == 0:
    log("All columns match between source and loaded tables.")
else:
    log("Review the mismatches above before proceeding to Step 4.")

conn.close()

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")