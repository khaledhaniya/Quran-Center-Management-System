import openpyxl
import sys
import datetime

sys.stdout.reconfigure(encoding='utf-8')

wb = openpyxl.load_workbook('all data.xlsx', data_only=True)
sheet = wb.active

def parse_excel_date(val):
    if val is None or str(val).strip() == '':
        return ''
    if isinstance(val, (datetime.datetime, datetime.date)):
        return val.strftime('%Y-%m-%d')
    s = str(val).strip()
    # Handle DD/MM/YYYY
    if '/' in s:
        parts = s.split('/')
        if len(parts) == 3:
            d, m, y = parts[0].zfill(2), parts[1].zfill(2), parts[2]
            return f'{y}-{m}-{d}'
    # Handle YYYY-MM-DD or DD-MM-YYYY
    if '-' in s:
        parts = s.split('-')
        if len(parts) == 3:
            if len(parts[0]) == 4:
                return f"{parts[0]}-{parts[1].zfill(2)}-{parts[2].zfill(2)}"
            else:
                d, m, y = parts[0].zfill(2), parts[1].zfill(2), parts[2]
                return f'{y}-{m}-{d}'
    return s

rows = list(sheet.iter_rows(values_only=True))[1:]
print(f"Total Rows: {len(rows)}")

invalid_dates = []
for idx, row in enumerate(rows):
    if not row[1] or not str(row[1]).strip():
        continue
    raw_dob = row[3]
    parsed = parse_excel_date(raw_dob)
    if not parsed or len(parsed) != 10 or parsed[4] != '-' or parsed[7] != '-':
        invalid_dates.append(f"Row {idx+1}: {row[1]} | Raw: {raw_dob} | Parsed: {parsed}")

print(f"Invalid Dates Count: {len(invalid_dates)}")
for inv in invalid_dates:
    print(" ", inv)
