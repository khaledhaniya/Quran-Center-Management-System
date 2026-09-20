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
        try
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
        catch (Exception ex)
        {
            Console.WriteLine($"[ReportService.GetSummaryAsync Warning] {ex.Message}");
            int sCount = 0, tCount = 0, cCount = 0;
            try { sCount = await _db.Students.CountAsync(s => s.IsActive); } catch { }
            try { tCount = await _db.Teachers.CountAsync(t => t.IsActive); } catch { }
            try { cCount = await _db.Circles.CountAsync(c => c.IsActive); } catch { }

            return new SummaryReportDto(
                from, to,
                sCount, tCount, cCount,
                0, 0, 0,
                new Dictionary<string, int>()
            );
        }
    }

    
    public async Task<List<ChildProgressDto>> GetChildrenProgressAsync(int parentId)
    {
        var children = await _db.Students
            .Include(s => s.Circle)
            .Where(s => s.ParentId == parentId)
            .ToListAsync();

        return await BuildChildProgressDtosAsync(children);
    }

    public async Task<List<ChildProgressDto>> GetChildrenProgressForUserAsync(User user)
    {
        if (user == null) return new List<ChildProgressDto>();

        var matchedStudents = await GetSmartChildrenForParentAsync(user);
        return await BuildChildProgressDtosAsync(matchedStudents);
    }

    private async Task<List<ChildProgressDto>> BuildChildProgressDtosAsync(List<Student> children)
    {
        var result = new List<ChildProgressDto>();
        var distinctChildren = children.GroupBy(c => c.Id).Select(g => g.First()).ToList();

        foreach (var child in distinctChildren)

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

            var talents = await _db.TalentRecords
                .Include(t => t.SupervisorTeacher)
                .Where(t => t.StudentId == child.Id)
                .OrderByDescending(t => t.EventDate)
                .Select(t => (object)new {
                    t.Id,
                    t.TalentType,
                    t.Title,
                    t.PreparationMethod,
                    t.SpeechContent,
                    t.Occasion,
                    EventDate = t.EventDate.ToString("yyyy-MM-dd"),
                    t.SupervisorTeacherId,
                    SupervisorTeacherName = t.SupervisorTeacher != null ? t.SupervisorTeacher.FullName : "غير معين",
                    t.MediaUrl,
                    t.MediaType,
                    t.EvaluationScore,
                    t.PerformanceNotes
                })
                .ToListAsync();

            result.Add(new ChildProgressDto(
                child.Id, child.FullName, child.Circle?.Name,
                sessions.Count, absence, late, recent,
                talents.Count > 0, talents
            ));
        }

        return result;
    }

    public async Task<List<Student>> GetSmartChildrenForParentAsync(User parentUser)
    {
        int pId = parentUser.ParentId ?? parentUser.Id;
        Teacher? teacher = parentUser.Teacher;
        if (teacher == null && parentUser.TeacherId.HasValue)
        {
            teacher = await _db.Teachers.FindAsync(parentUser.TeacherId.Value);
        }
        else if (teacher == null && parentUser.Role == UserRole.Teacher)
        {
            var uName = (parentUser.Username ?? "").Trim();
            teacher = await _db.Teachers.FirstOrDefaultAsync(t => 
                (!string.IsNullOrEmpty(t.IdentityNumber) && t.IdentityNumber == uName) ||
                (!string.IsNullOrEmpty(t.FullName) && t.FullName == parentUser.FullName));
        }

        var directStudents = await _db.Students
            .Include(s => s.Circle)
            .Where(s => (s.ParentId.HasValue && (s.ParentId == pId || s.ParentId == parentUser.Id || (parentUser.TeacherId.HasValue && s.ParentId == parentUser.TeacherId.Value))))
            .ToListAsync();

        var directIds = directStudents.Select(s => s.Id).ToHashSet();
        
        var idNumbersToMatch = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (!string.IsNullOrWhiteSpace(parentUser.Username) && parentUser.Username.All(char.IsDigit))
        {
            idNumbersToMatch.Add(parentUser.Username.Trim());
        }
        if (teacher != null && !string.IsNullOrWhiteSpace(teacher.IdentityNumber))
        {
            idNumbersToMatch.Add(teacher.IdentityNumber.Trim());
        }

        var contactsToMatch = directStudents
            .Where(s => !string.IsNullOrWhiteSpace(s.FamilyContact))
            .Select(s => s.FamilyContact.Trim())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        if (teacher != null)
        {
            if (!string.IsNullOrWhiteSpace(teacher.Contact)) contactsToMatch.Add(teacher.Contact.Trim());
            if (!string.IsNullOrWhiteSpace(teacher.WhatsappNumber)) contactsToMatch.Add(teacher.WhatsappNumber.Trim());
        }

        var parentNameParts = (teacher?.FullName ?? parentUser.FullName ?? "")
            .Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

        var allStudents = await _db.Students.Include(s => s.Circle).ToListAsync();
        var matchedList = new List<Student>(directStudents);

        foreach (var s in allStudents)
        {
            if (directIds.Contains(s.Id)) continue;

            bool isMatch = false;

            // 1. National ID match (e.g. Student's ParentIdentityNumber == Father's National ID)
            if (!isMatch && !string.IsNullOrWhiteSpace(s.ParentIdentityNumber) && idNumbersToMatch.Contains(s.ParentIdentityNumber.Trim()))
            {
                isMatch = true;
            }

            // 2. Phone / Family contact match
            if (!isMatch && !string.IsNullOrWhiteSpace(s.FamilyContact) && contactsToMatch.Contains(s.FamilyContact.Trim()))
            {
                isMatch = true;
            }

            // 3. Father & Grandfather & Family Name match in FullName
            if (!isMatch && parentNameParts.Length >= 2)
            {
                var sParts = (s.FullName ?? "").Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                if (sParts.Length >= 3)
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
                directIds.Add(s.Id);
            }
        }

        return matchedList;
    }
}
