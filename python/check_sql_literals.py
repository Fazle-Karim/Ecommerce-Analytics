"""
check_sql_literals.py
Purpose: Verify that hard-coded expected counts in sql/02_load_raw.sql match
         the values in documentation/control_totals.json. Fails loudly if not.

Rule enforced: expected values are never hand-entered — they are checked
against the canonical JSON on every run.
"""

import json
import re
import sys
from pathlib import Path

SQL_PATH  = Path("sql/02_load_raw.sql")
JSON_PATH = Path("documentation/control_totals.json")
OUT       = Path("documentation/sql_literal_check.txt")

# ------------------------------------------------------------------
# Load JSON baseline
# ------------------------------------------------------------------
baseline = json.loads(JSON_PATH.read_text(encoding="utf-8"))
expected = {
    "category_translation": baseline["raw_level"]["category_translation_row_count"],
    "customers":            baseline["raw_level"]["customers_row_count"],
    "geolocation":          baseline["raw_level"]["geolocation_row_count"],
    "order_items":          baseline["raw_level"]["order_items_row_count"],
    "orders":               baseline["raw_level"]["orders_row_count"],
    "payments":             baseline["raw_level"]["payments_row_count"],
    "products":             baseline["raw_level"]["products_row_count"],
    "reviews":              baseline["raw_level"]["reviews_row_count"],
    "sellers":              baseline["raw_level"]["sellers_row_count"],
}

# ------------------------------------------------------------------
# Parse SQL literals from the expected-counts CTE
# ------------------------------------------------------------------
sql_text = SQL_PATH.read_text(encoding="utf-8")

# Match lines like:  UNION ALL SELECT 'customers',  99441
# and the first line:  SELECT 'category_translation' AS table_name, 71  AS expected_count
pattern = re.compile(r"'([a-z_]+)'[^\d]*(\d{2,7})")
matches = pattern.findall(sql_text)

# Build a dict of table -> SQL literal
sql_literals = {}
for table, count in matches:
    if table in expected:
        sql_literals[table] = int(count)

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

log(f"SQL literal vs JSON check — {SQL_PATH.name}")
log("=" * 60)
log("")
log(f"{'Table':<25} {'JSON':>10} {'SQL':>10}  match")
log(f"{'-'*25} {'-'*10} {'-'*10}  -----")

mismatches = []
for table in sorted(expected.keys()):
    json_val = expected[table]
    sql_val = sql_literals.get(table)
    if sql_val is None:
        match = "MISSING"
        mismatches.append((table, json_val, None))
    elif json_val == sql_val:
        match = "OK"
    else:
        match = "MISMATCH"
        mismatches.append((table, json_val, sql_val))
    log(f"{table:<25} {json_val:>10} {str(sql_val):>10}  {match}")

log("")
if mismatches:
    log(f"❌ {len(mismatches)} mismatch(es) found. Update sql/02_load_raw.sql")
    log("   to match control_totals.json, or regenerate the JSON.")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    sys.exit(1)
else:
    log("✅ All SQL literals match the pinned control totals.")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"\n✅ Report written to {OUT}")