import openpyxl
import sqlite3
import sys
import datetime

sys.stdout.reconfigure(encoding='utf-8')

wb = openpyxl.load_workbook('all data.xlsx', data_only=True)
sheet = wb.active

conn = sqlite3.connect('QuranCircles.Api/QuranCircles.Api/quran.db')
cursor = conn.cursor()

def parse_excel_date(val):
    if val is None or str(val).strip() == '':
        return ''
    if isinstance(val, (datetime.datetime, datetime.date)):
        return val.strftime('%Y-%m-%d')
    s = str(val).strip()
    # Format DD/MM/YYYY
    parts = s.split('/')
    if len(parts) == 3:
        d, m, y = parts[0].zfill(2), parts[1].zfill(2), parts[2]
        return f'{y}-{m}-{d}'
    parts = s.split('-')
    if len(parts) == 3:
        if len(parts[0]) == 4:
            return s
        else:
            d, m, y = parts[0].zfill(2), parts[1].zfill(2), parts[2]
            return f'{y}-{m}-{d}'
    return s

discrepancies = []
dob_mismatches = []
missing_in_db = []
father_status_mismatches = []
mother_status_mismatches = []

rows = list(sheet.iter_rows(values_only=True))[1:]

for idx, row in enumerate(rows):
    if not row[1] or not str(row[1]).strip():
        continue
    
    excel_num = str(row[0]).strip() if row[0] is not None else str(idx+1)
    excel_name = str(row[1]).strip()
    excel_id = str(row[2]).strip() if row[2] is not None else ''
    excel_dob_raw = row[3]
    excel_dob = parse_excel_date(excel_dob_raw)
    excel_father_status = str(row[9]).strip() if row[9] is not None else ''
    excel_mother_status = str(row[10]).strip() if row[10] is not None else ''

    # Query DB by StudentIdentityNumber or FullName
    cursor.execute('''
        SELECT Id, FullName, DateOfBirth, StudentIdentityNumber, FatherStatus, MotherStatus, 
               PreviousQuranMemorization, ParentIdentityNumber, FamilyContact, StudentMobile,
               HealthStatus, Address, CurrentAddress, Notes
        FROM Students 
        WHERE StudentIdentityNumber = ? OR FullName = ?
    ''', (excel_id, excel_name))
    
    db_rows = cursor.fetchall()
    
    if not db_rows:
        missing_in_db.append(f"Row #{excel_num}: Name '{excel_name}', ID '{excel_id}', DOB '{excel_dob}'")
        continue
    
    db_student = db_rows[0]
    (db_id, db_name, db_dob, db_s_id, db_f_status, db_m_status, 
     db_quran, db_p_id, db_contact, db_mobile, db_health, db_addr, db_curr_addr, db_notes) = db_student

    # 1. Date of Birth check
    if excel_dob and db_dob != excel_dob:
        dob_mismatches.append({
            'id': db_id,
            'name': db_name,
            'db_dob': db_dob,
            'excel_dob': excel_dob,
            'raw_excel': str(excel_dob_raw)
        })

    # 2. Father status check
    if excel_father_status and (db_f_status or '').strip() != excel_father_status:
        father_status_mismatches.append({
            'id': db_id,
            'name': db_name,
            'db_status': db_f_status,
            'excel_status': excel_father_status
        })

    # 3. Mother status check
    if excel_mother_status and (db_m_status or '').strip() != excel_mother_status:
        mother_status_mismatches.append({
            'id': db_id,
            'name': db_name,
            'db_status': db_m_status,
            'excel_status': excel_mother_status
        })

print(f"Total Rows Evaluated: {len(rows)}")
print(f"Missing in DB: {len(missing_in_db)}")
print(f"DOB Mismatches: {len(dob_mismatches)}")
print(f"Father Status Mismatches: {len(father_status_mismatches)}")
print(f"Mother Status Mismatches: {len(mother_status_mismatches)}")

print("\n--- DOB MISMATCHES SAMPLE ---")
for d in dob_mismatches[:40]:
    print(f"ID #{d['id']} | {d['name']} | DB: {d['db_dob']} <---> Excel: {d['excel_dob']} (Raw: {d['raw_excel']})")

print("\n--- MISSING STUDENTS SAMPLE ---")
for m in missing_in_db[:20]:
    print(" ", m)

print("\n--- FATHER STATUS MISMATCHES SAMPLE ---")
for f in father_status_mismatches[:10]:
    print(f"  ID #{f['id']} | {f['name']} | DB: {f['db_status']} <---> Excel: {f['excel_status']}")
