using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class AttendanceService
{
    private readonly AppDbContext _db;
    public AttendanceService(AppDbContext db) => _db = db;

    public async Task<(AttendanceDto? dto, string? error)> RecordAsync(RecordAttendanceDto dto)
    {
        var student = await _db.Students.FindAsync(dto.StudentId);
        if (student is null) return (null, "الطالب غير موجود.");

        var circle = await _db.Circles.FindAsync(dto.CircleId);
        if (circle is null) return (null, "الحلقة غير موجودة.");

        if (dto.SessionDate > DateOnly.FromDateTime(DateTime.UtcNow.AddDays(2)))
            return (null, "تاريخ الجلسة غير صالح (في المستقبل البعيد).");

        var existing = await _db.Attendances.FirstOrDefaultAsync(a =>
            a.StudentId == dto.StudentId &&
            a.CircleId == dto.CircleId &&
            a.SessionDate == dto.SessionDate);

        if (existing is not null)
        {
            existing.Status = dto.Status; 
            await _db.SaveChangesAsync();
            return (Map(existing, student.FullName, circle.Name), null);
        }

        var a = new Attendance
        {
            StudentId = dto.StudentId,
            CircleId = dto.CircleId,
            SessionDate = dto.SessionDate,
            Status = dto.Status
        };
        _db.Attendances.Add(a);
        await _db.SaveChangesAsync();
        return (Map(a, student.FullName, circle.Name), null);
    }

    public async Task<List<AttendanceDto>> GetByStudentAsync(int studentId)
    {
        return await _db.Attendances
            .Include(a => a.Student)
            .Include(a => a.Circle)
            .Where(a => a.StudentId == studentId)
            .OrderByDescending(a => a.SessionDate)
            .Select(a => new AttendanceDto(
                a.Id, a.StudentId, a.Student!.FullName,
                a.CircleId, a.Circle!.Name,
                a.SessionDate, a.Status, StatusText(a.Status)))
            .ToListAsync();
    }

    private static AttendanceDto Map(Attendance a, string studentName, string circleName) => new(
        a.Id, a.StudentId, studentName, a.CircleId, circleName,
        a.SessionDate, a.Status, StatusText(a.Status)
    );

    public static string StatusText(AttendanceStatus s) => s switch
    {
        AttendanceStatus.Present => "حاضر",
        AttendanceStatus.Absent => "غائب",
        AttendanceStatus.Late => "متأخر",
        _ => s.ToString()
    };
}
