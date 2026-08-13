import openpyxl
import sqlite3
import sys
import datetime

sys.stdout.reconfigure(encoding='utf-8')

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

wb = openpyxl.load_workbook('all data.xlsx', data_only=True)
sheet = wb.active

conn = sqlite3.connect('QuranCircles.Api/QuranCircles.Api/quran.db')
cursor = conn.cursor()

rows = list(sheet.iter_rows(values_only=True))[1:]

updated_students_count = 0
dob_fixed_count = 0
father_status_fixed_count = 0
mother_status_fixed_count = 0
health_status_fixed_count = 0
quran_fixed_count = 0

audit_log = []

for idx, row in enumerate(rows):
    if not row[1] or not str(row[1]).strip():
        continue

    excel_num = str(row[0]).strip() if row[0] is not None else str(idx+1)
    fullName = str(row[1]).strip()
    studentIdentityNumber = str(row[2]).strip() if row[2] is not None else ''
    dateOfBirth = parse_excel_date(row[3])
    grade = str(row[4]).strip() if row[4] is not None else ''
    previousQuranMemorization = str(row[5]).strip() if row[5] is not None else ''
    studentMobile = str(row[6]).strip() if row[6] is not None else ''
    studentWhatsapp = str(row[7]).strip() if row[7] is not None else ''
    healthStatus = str(row[8]).strip() if row[8] is not None else ''
    fatherStatus = str(row[9]).strip() if row[9] is not None else ''
    motherStatus = str(row[10]).strip() if row[10] is not None else ''
    teacherName = str(row[11]).strip() if row[11] is not None else ''
    parentName = str(row[12]).strip() if row[12] is not None else ''
    kinship = str(row[13]).strip() if row[13] is not None else ''
    parentIdentityNumber = str(row[14]).strip() if row[14] is not None else ''
    familyContact = str(row[15]).strip() if row[15] is not None else ''
    whatsappNumber = str(row[16]).strip() if row[16] is not None else ''
    walletNumber = str(row[17]).strip() if row[17] is not None else ''
    bankAccountNumber = str(row[18]).strip() if row[18] is not None else ''
    bankName = str(row[19]).strip() if row[19] is not None else ''
    originalAddress = str(row[20]).strip() if row[20] is not None else ''
    originalHousingType = str(row[21]).strip() if row[21] is not None else ''
    originalHousingStatus = str(row[22]).strip() if row[22] is not None else ''
    currentAddress = str(row[23]).strip() if row[23] is not None else ''
    currentHousingType = str(row[24]).strip() if row[24] is not None else ''
    notes = str(row[25]).strip() if row[25] is not None else ''

    # General Address logic
    address = currentAddress or originalAddress or ''

    # Find existing student in DB
    cursor.execute('SELECT Id, DateOfBirth, FatherStatus, MotherStatus, HealthStatus, PreviousQuranMemorization FROM Students WHERE StudentIdentityNumber = ? OR FullName = ?', (studentIdentityNumber, fullName))
    existing = cursor.fetchone()

    if existing:
        st_id, db_dob, db_f_status, db_m_status, db_health, db_quran = existing
        
        changes = []
        if dateOfBirth and db_dob != dateOfBirth:
            changes.append(f"DOB: '{db_dob}' -> '{dateOfBirth}'")
            dob_fixed_count += 1
            
        if fatherStatus and db_f_status != fatherStatus:
            changes.append(f"FatherStatus: '{db_f_status}' -> '{fatherStatus}'")
            father_status_fixed_count += 1

        if motherStatus and db_m_status != motherStatus:
            changes.append(f"MotherStatus: '{db_m_status}' -> '{motherStatus}'")
            mother_status_fixed_count += 1

        if healthStatus and db_health != healthStatus:
            changes.append(f"HealthStatus: '{db_health}' -> '{healthStatus}'")
            health_status_fixed_count += 1

        if previousQuranMemorization and db_quran != previousQuranMemorization:
            changes.append(f"Quran: '{db_quran}' -> '{previousQuranMemorization}'")
            quran_fixed_count += 1

        # Perform UPDATE
        cursor.execute('''
            UPDATE Students 
            SET FullName = ?,
                StudentIdentityNumber = ?,
                DateOfBirth = ?,
                PreviousQuranMemorization = ?,
                StudentMobile = ?,
                StudentWhatsapp = ?,
                HealthStatus = ?,
                FatherStatus = ?,
                MotherStatus = ?,
                Kinship = ?,
                ParentIdentityNumber = ?,
                FamilyContact = ?,
                WhatsappNumber = ?,
                WalletNumber = ?,
                BankAccountNumber = ?,
                BankName = ?,
                OriginalAddress = ?,
                OriginalHousingType = ?,
                OriginalHousingStatus = ?,
                CurrentAddress = ?,
                CurrentHousingType = ?,
                Address = ?,
                Notes = ?
            WHERE Id = ?
        ''', (
            fullName, studentIdentityNumber, dateOfBirth or db_dob, previousQuranMemorization,
            studentMobile, studentWhatsapp, healthStatus or 'سليم', fatherStatus or 'سليم',
            motherStatus or 'سليم', kinship or 'الأب', parentIdentityNumber, familyContact,
            whatsappNumber, walletNumber, bankAccountNumber, bankName,
            originalAddress, originalHousingType, originalHousingStatus,
            currentAddress, currentHousingType, address, notes,
            st_id
        ))

        if changes:
            updated_students_count += 1
            audit_log.append(f"Student ID #{st_id} ({fullName}): " + ", ".join(changes))

conn.commit()
conn.close()

print(f"--- AUDIT & SYNC REPORT ---")
print(f"Total Student Records in Excel: {len(rows)}")
print(f"Total Students Updated: {updated_students_count}")
print(f"  - Birth Dates Fixed: {dob_fixed_count}")
print(f"  - Father Statuses Fixed: {father_status_fixed_count}")
print(f"  - Mother Statuses Fixed: {mother_status_fixed_count}")
print(f"  - Health Statuses Fixed: {health_status_fixed_count}")
print(f"  - Memorization Levels Fixed: {quran_fixed_count}")

print("\n--- SAMPLE AUDITED DISCREPANCIES FIXED ---")
for log_item in audit_log[:35]:
    print("  *", log_item)
