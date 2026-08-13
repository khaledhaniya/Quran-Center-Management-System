import openpyxl
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

wb = openpyxl.load_workbook(r'c:\xampp\htdocs\Quran Center\all data.xlsx', data_only=True)
ws = wb['all data']
rows = list(ws.iter_rows(values_only=True))

print("Header Row:")
for idx, col in enumerate(rows[0]):
    print(f"Col {idx}: {col}")

print("\nSample Rows:")
for r_idx in range(1, min(6, len(rows))):
    print(f"Row {r_idx}:", rows[r_idx])
