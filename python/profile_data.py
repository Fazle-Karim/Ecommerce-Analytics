"""
profile_data.py
Purpose: Profile all 9 Olist CSVs — row counts, dtypes, nulls, duplicates, date ranges.
Output:  documentation/data_profile_raw.txt
"""

import pandas as pd
from pathlib import Path

RAW = Path("data/raw")
OUT = Path("documentation/data_profile_raw.txt")

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

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

log(f"Olist Data Profile — generated {pd.Timestamp.now()}")
log("=" * 70)

for name, fname in FILES.items():
    path = RAW / fname
    if not path.exists():
        log(f"\n!! MISSING FILE: {fname}")
        continue

    df = pd.read_csv(path, dtype=str, encoding="utf-8")

    log(f"\n{'=' * 70}")
    log(f"TABLE: {name}")
    log(f"File:  {fname}")
    log(f"{'=' * 70}")
    log(f"Rows:    {len(df):,}")
    log(f"Columns: {df.shape[1]}")
    log(f"Column names: {list(df.columns)}")

    log(f"\nNull counts and %:")
    null_info = pd.DataFrame({
        "null_count": df.isnull().sum(),
        "null_pct":   (df.isnull().mean() * 100).round(2),
    })
    log(null_info.to_string())

    log(f"\nDuplicate full rows: {df.duplicated().sum():,}")

    # Date columns
    date_cols = [c for c in df.columns if "date" in c.lower() or "timestamp" in c.lower()]
    if date_cols:
        log(f"\nDate columns:")
        for col in date_cols:
            parsed = pd.to_datetime(df[col], errors="coerce")
            unparseable = parsed.isnull().sum() - df[col].isnull().sum()
            log(f"  {col}:")
            log(f"    min: {parsed.min()}")
            log(f"    max: {parsed.max()}")
            log(f"    unparseable: {unparseable}")

log(f"\n\nProfile complete.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")