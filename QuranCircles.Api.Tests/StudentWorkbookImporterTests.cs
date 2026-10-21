using ClosedXML.Excel;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using Xunit;

namespace QuranCircles.Api.Tests;

public class StudentWorkbookImporterTests
{
    [Fact]
    public async Task ImportsOnlySelectedNewStudentsAndNeverSeedsDeletedStudents()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseSqlite(connection).Options);
        db.Database.EnsureCreated();
        db.Students.Add(new Student { FullName = "طالب موجود", StudentIdentityNumber = "111", IsActive = true });
        await db.SaveChangesAsync();

        using var workbook = new XLWorkbook();
        var sheet = workbook.AddWorksheet("Students");
        sheet.Cell(1, 2).Value = "الاسم رباعي";
        sheet.Cell(1, 3).Value = "رقم هوية الطالب";
        WriteStudent(sheet, 2, 242, "طالب قديم", "333");
        WriteStudent(sheet, 3, 243, "طالب جديد", "222");
        WriteStudent(sheet, 4, 244, "طالب مكرر", "222");
        WriteStudent(sheet, 5, 245, "طالب موجود", "111");
        WriteStudent(sheet, 6, 246, "طالب محذوف سابقاً", "333");
        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        var hasher = new PasswordHasher();
        var importer = new StudentWorkbookImporter(db, new StudentService(db, hasher));

        stream.Position = 0;
        var preview = await importer.ProcessAsync(stream, 243, previewOnly: true);
        Assert.Equal(new StudentWorkbookImportResult(4, 1, 1, 2), preview);
        Assert.Equal(1, await db.Students.CountAsync());

        stream.Position = 0;
        var saved = await importer.ProcessAsync(stream, 243);
        Assert.Equal(preview, saved);
        var added = await db.Students.SingleAsync(s => s.StudentIdentityNumber == "222");
        Assert.Equal("الصف الثامن", added.SchoolGrade);
        Assert.DoesNotContain(await db.Students.ToListAsync(), s => s.StudentIdentityNumber == "333");

        db.Students.Remove(added);
        await db.SaveChangesAsync();
        DbSeeder.Seed(db, hasher);
        Assert.False(await db.Students.AnyAsync(s => s.StudentIdentityNumber == "222"));
    }

    private static void WriteStudent(IXLWorksheet sheet, int row, int serial, string name, string identity)
    {
        sheet.Cell(row, 1).Value = serial;
        sheet.Cell(row, 2).Value = name;
        sheet.Cell(row, 3).Value = identity;
        sheet.Cell(row, 4).Value = new DateTime(2013, 10, 20);
        sheet.Cell(row, 5).Value = "الصف الثامن";
    }
}
