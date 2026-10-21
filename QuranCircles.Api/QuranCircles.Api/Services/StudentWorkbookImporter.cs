using System.Globalization;
using ClosedXML.Excel;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;

namespace QuranCircles.Api.Services;

public sealed record StudentWorkbookImportResult(int RowsSelected, int Added, int AlreadyPresent, int DuplicateInFile);

// A deliberate, one-time import. No workbook row is seeded during application startup.
public sealed class StudentWorkbookImporter(AppDbContext db, StudentService students)
{
    private sealed record ImportRow(int ExcelRow, string Identity, CreateStudentDto Student,
        bool DuplicateInWorkbook);

    public async Task<StudentWorkbookImportResult> ProcessAsync(Stream workbookStream, int firstSerial,
        bool previewOnly = false)
    {
        if (firstSerial < 1) throw new InvalidDataException("حدد أول رقم سجل مطلوب استيراده.");
        var rows = ReadRows(workbookStream, firstSerial);
        if (rows.Count == 0) throw new InvalidDataException("لم يُعثر على سجلات بدءاً من الرقم المحدد.");

        async Task<StudentWorkbookImportResult> ProcessRowsAsync()
        {
            db.ChangeTracker.Clear();
            var existing = (await db.Students.AsNoTracking()
                    .Where(s => s.StudentIdentityNumber != null)
                    .Select(s => s.StudentIdentityNumber!).ToListAsync())
                .Select(id => id.Trim()).ToHashSet(StringComparer.Ordinal);
            var added = 0;
            var alreadyPresent = 0;
            var duplicateInFile = 0;

            await using var transaction = previewOnly ? null : await db.Database.BeginTransactionAsync();
            foreach (var row in rows)
            {
                if (row.DuplicateInWorkbook) { duplicateInFile++; continue; }
                if (existing.Contains(row.Identity)) { alreadyPresent++; continue; }
                if (!previewOnly)
                {
                    var (created, _, error) = await students.CreateAsync(row.Student);
                    if (created == null)
                        throw new InvalidDataException($"السطر {row.ExcelRow}: {error ?? "تعذر حفظ الطالب."}");
                }
                added++;
                existing.Add(row.Identity);
            }
            if (transaction != null) await transaction.CommitAsync();
            return new StudentWorkbookImportResult(rows.Count, added, alreadyPresent, duplicateInFile);
        }

        // SQL Server enables retry on transient faults, so explicit transactions run through its strategy.
        return previewOnly ? await ProcessRowsAsync() :
            await db.Database.CreateExecutionStrategy().ExecuteAsync(ProcessRowsAsync);
    }

    private static List<ImportRow> ReadRows(Stream stream, int firstSerial)
    {
        using var workbook = new XLWorkbook(stream);
        var sheet = workbook.Worksheet(1);
        if (Cell(sheet, 1, 2) != "الاسم رباعي" || Cell(sheet, 1, 3) != "رقم هوية الطالب")
            throw new InvalidDataException("هذا ليس ملف بيانات الطلاب المتوقع؛ تحقق من عناوين الأعمدة.");

        var rows = new List<ImportRow>();
        var seenInWorkbook = new HashSet<string>(StringComparer.Ordinal);
        var last = sheet.LastRowUsed()?.RowNumber() ?? 1;
        for (var line = 2; line <= last; line++)
        {
            if (!int.TryParse(Cell(sheet, line, 1), out var serial)) continue;
            var identity = Cell(sheet, line, 3);
            var duplicateInWorkbook = !string.IsNullOrWhiteSpace(identity) && !seenInWorkbook.Add(identity);
            if (serial < firstSerial) continue;
            var name = Cell(sheet, line, 2);
            if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(identity))
                throw new InvalidDataException($"السطر {line}: اسم الطالب ورقم هويته مطلوبان.");

            var birth = BirthDate(sheet.Cell(line, 4), line);
            string? Optional(int column) => NullIfBlank(Cell(sheet, line, column));
            var currentAddress = Optional(24);
            var originalAddress = Optional(21);
            var parentMobile = Optional(16);
            var studentMobile = Optional(7);
            var student = new CreateStudentDto(
                FullName: name,
                Address: currentAddress ?? originalAddress,
                DateOfBirth: birth,
                FamilyContact: parentMobile ?? studentMobile,
                CircleId: null,
                ParentId: null,
                Username: identity,
                Password: null,
                StudentIdentityNumber: identity,
                PreviousQuranMemorization: Optional(6),
                StudentMobile: studentMobile,
                StudentWhatsapp: Optional(8),
                HealthStatus: Optional(9),
                FatherStatus: Optional(10),
                MotherStatus: Optional(11),
                Kinship: Optional(14),
                ParentIdentityNumber: Optional(15),
                WhatsappNumber: Optional(17),
                WalletNumber: Optional(18),
                BankAccountNumber: Optional(19),
                BankName: Optional(20),
                OriginalAddress: originalAddress,
                OriginalHousingType: Optional(22),
                OriginalHousingStatus: Optional(23),
                CurrentAddress: currentAddress,
                CurrentHousingType: Optional(25),
                Notes: Optional(26),
                ParentName: Optional(13),
                SchoolGrade: Optional(5));
            rows.Add(new ImportRow(line, identity, student, duplicateInWorkbook));
        }
        return rows;
    }

    private static string Cell(IXLWorksheet sheet, int row, int column) =>
        sheet.Cell(row, column).GetFormattedString(CultureInfo.InvariantCulture).Trim();

    private static string? NullIfBlank(string text) => string.IsNullOrWhiteSpace(text) ? null : text;

    private static DateOnly BirthDate(IXLCell cell, int line)
    {
        if (cell.TryGetValue<DateTime>(out var date)) return DateOnly.FromDateTime(date);
        var text = cell.GetFormattedString(CultureInfo.InvariantCulture).Trim();
        var formats = new[] { "d/M/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "yyyy/MM/dd", "M/d/yyyy" };
        if (DateOnly.TryParseExact(text, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var result))
            return result;
        throw new InvalidDataException($"السطر {line}: تاريخ الميلاد غير صالح.");
    }
}
