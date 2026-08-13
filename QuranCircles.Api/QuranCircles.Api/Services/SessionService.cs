using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class SessionService
{
    private readonly AppDbContext _db;
    public SessionService(AppDbContext db) => _db = db;

    public async Task<List<SessionDto>> GetByStudentAsync(int studentId)
    {
        return await _db.Sessions
            .Include(s => s.Student)
            .Where(s => s.StudentId == studentId)
            .OrderByDescending(s => s.SessionDate)
            .Select(s => Map(s))
            .ToListAsync();
    }

    public async Task<SessionDto?> GetByIdAsync(int id)
    {
        var s = await _db.Sessions.Include(x => x.Student).FirstOrDefaultAsync(x => x.Id == id);
        return s is null ? null : Map(s);
    }

    public async Task<(SessionDto? dto, string? error)> CreateAsync(CreateSessionDto dto)
    {
        var student = await _db.Students.FindAsync(dto.StudentId);
        if (student is null) return (null, "الطالب غير موجود.");
        if (!student.IsActive) return (null, "الطالب غير مفعّل.");

        var err = Validate(dto.SurahName, dto.FromVerse, dto.ToVerse, dto.SessionDate);
        if (err is not null) return (null, err);

        var s = new RecitationSession
        {
            StudentId = dto.StudentId,
            SessionDate = dto.SessionDate,
            SurahName = dto.SurahName.Trim(),
            FromVerse = dto.FromVerse,
            ToVerse = dto.ToVerse,
            Assessment = dto.Assessment,
            Notes = dto.Notes?.Trim(),
            ViaLottery = dto.ViaLottery
        };
        _db.Sessions.Add(s);
        await _db.SaveChangesAsync();

        await _db.Entry(s).Reference(x => x.Student).LoadAsync();
        return (Map(s), null);
    }

    public async Task<(bool ok, string? error)> UpdateAsync(int id, UpdateSessionDto dto)
    {
        var s = await _db.Sessions.FindAsync(id);
        if (s is null) return (false, "الجلسة غير موجودة.");

        var err = Validate(dto.SurahName, dto.FromVerse, dto.ToVerse, dto.SessionDate);
        if (err is not null) return (false, err);

        s.SessionDate = dto.SessionDate;
        s.SurahName = dto.SurahName.Trim();
        s.FromVerse = dto.FromVerse;
        s.ToVerse = dto.ToVerse;
        s.Assessment = dto.Assessment;
        s.Notes = dto.Notes?.Trim();

        await _db.SaveChangesAsync();
        return (true, null);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var s = await _db.Sessions.FindAsync(id);
        if (s is null) return false;
        _db.Sessions.Remove(s);
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<(LotteryResultDto? result, string? error)> DrawAsync(int circleId, DateOnly date)
    {
        var circle = await _db.Circles.FindAsync(circleId);
        if (circle is null) return (null, "الحلقة غير موجودة.");

        var students = await _db.Students
            .Where(s => s.CircleId == circleId && s.IsActive)
            .ToListAsync();

        if (students.Count == 0)
            return (null, "لا يوجد طلاب مفعّلون في هذه الحلقة.");

        var absentIds = await _db.Attendances
            .Where(a => a.CircleId == circleId && a.SessionDate == date && a.Status == AttendanceStatus.Absent)
            .Select(a => a.StudentId)
            .ToListAsync();

        var candidates = students.Where(s => !absentIds.Contains(s.Id)).ToList();
        if (candidates.Count == 0)
            return (null, "كل الطلاب مسجّلون كغائبين في هذا التاريخ.");

        var picked = candidates[Random.Shared.Next(candidates.Count)];

        return (new LotteryResultDto(picked.Id, picked.FullName, circle.Id, circle.Name), null);
    }

    private static string? Validate(string surah, int from, int to, DateOnly date)
    {
        if (string.IsNullOrWhiteSpace(surah)) return "اسم السورة مطلوب.";
        if (from <= 0 || to <= 0) return "أرقام الآيات يجب أن تكون موجبة.";
        if (to < from) return "آية النهاية يجب ألا تسبق آية البداية.";
        if (date > DateOnly.FromDateTime(DateTime.Today)) return "تاريخ الجلسة في المستقبل.";
        return null;
    }

    private static SessionDto Map(RecitationSession s) => new(
        s.Id, s.StudentId, s.Student?.FullName ?? "",
        s.SessionDate, s.SurahName, s.FromVerse, s.ToVerse,
        s.Assessment, AssessmentText(s.Assessment), s.Notes, s.ViaLottery
    );

    public static string AssessmentText(AssessmentLevel a) => a switch
    {
        AssessmentLevel.Excellent => "ممتاز",
        AssessmentLevel.VeryGood => "جيد جداً",
        AssessmentLevel.Good => "جيد",
        AssessmentLevel.Medium => "متوسط",
        AssessmentLevel.Rejected => "مرفوض",
        _ => a.ToString()
    };
}
