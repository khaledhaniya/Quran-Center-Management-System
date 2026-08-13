using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class ReportService
{
    private readonly AppDbContext _db;
    public ReportService(AppDbContext db) => _db = db;

    public async Task<SummaryReportDto> GetSummaryAsync(DateOnly from, DateOnly to)
    {
        var totalStudents = await _db.Students.CountAsync(s => s.IsActive);
        var totalTeachers = await _db.Teachers.CountAsync(t => t.IsActive);
        var totalCircles = await _db.Circles.CountAsync(c => c.IsActive);

        var sessions = await _db.Sessions
            .Where(s => s.SessionDate >= from && s.SessionDate <= to)
            .ToListAsync();

        var totalVerses = sessions.Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));

        var absenceCount = await _db.Attendances
            .CountAsync(a => a.SessionDate >= from && a.SessionDate <= to && a.Status == AttendanceStatus.Absent);

        var breakdown = sessions
            .GroupBy(s => s.Assessment)
            .ToDictionary(
                g => SessionService.AssessmentText(g.Key),
                g => g.Count());

        return new SummaryReportDto(
            from, to,
            totalStudents, totalTeachers, totalCircles,
            sessions.Count, totalVerses, absenceCount,
            breakdown
        );
    }

    
    public async Task<List<ChildProgressDto>> GetChildrenProgressAsync(int parentId)
    {
        var children = await _db.Students
            .Include(s => s.Circle)
            .Where(s => s.ParentId == parentId)
            .ToListAsync();

        var result = new List<ChildProgressDto>();

        foreach (var child in children)
        {
            var sessions = await _db.Sessions
                .Where(s => s.StudentId == child.Id)
                .OrderByDescending(s => s.SessionDate)
                .ToListAsync();

            var absence = await _db.Attendances
                .CountAsync(a => a.StudentId == child.Id && a.Status == AttendanceStatus.Absent);
            var late = await _db.Attendances
                .CountAsync(a => a.StudentId == child.Id && a.Status == AttendanceStatus.Late);

            var recent = sessions.Take(5).Select(s => new SessionDto(
                s.Id, s.StudentId, child.FullName,
                s.SessionDate, s.SurahName, s.FromVerse, s.ToVerse,
                s.Assessment, SessionService.AssessmentText(s.Assessment), s.Notes, s.ViaLottery
            )).ToList();

            result.Add(new ChildProgressDto(
                child.Id, child.FullName, child.Circle?.Name,
                sessions.Count, absence, late, recent
            ));
        }

        return result;
    }

    public async Task<List<Student>> GetSmartChildrenForParentAsync(User parentUser)
    {
        int pId = parentUser.ParentId ?? parentUser.Id;

        var directStudents = await _db.Students
            .Include(s => s.Circle)
            .Where(s => s.ParentId == pId)
            .ToListAsync();

        var directIds = directStudents.Select(s => s.Id).ToHashSet();
        var contacts = directStudents
            .Where(s => !string.IsNullOrWhiteSpace(s.FamilyContact))
            .Select(s => s.FamilyContact.Trim())
            .ToHashSet();

        var parentNameParts = (parentUser.FullName ?? "")
            .Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

        var allStudents = await _db.Students.Include(s => s.Circle).ToListAsync();
        var matchedList = new List<Student>(directStudents);

        foreach (var s in allStudents)
        {
            if (directIds.Contains(s.Id)) continue;

            bool isMatch = false;

            // 1. Phone / Family contact match
            if (!string.IsNullOrWhiteSpace(s.FamilyContact) && contacts.Contains(s.FamilyContact.Trim()))
            {
                isMatch = true;
            }

            // 2. Father & Grandfather & Family Name match
            if (!isMatch && parentNameParts.Length >= 2)
            {
                var sParts = (s.FullName ?? "").Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                if (sParts.Length >= 2)
                {
                    int matchCount = 0;
                    foreach (var pPart in parentNameParts)
                    {
                        if (sParts.Skip(1).Any(sp => sp.Equals(pPart, StringComparison.OrdinalIgnoreCase)))
                        {
                            matchCount++;
                        }
                    }
                    if (matchCount >= 2)
                    {
                        isMatch = true;
                    }
                }
            }

            if (isMatch)
            {
                matchedList.Add(s);
            }
        }

        return matchedList;
    }
}
