using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/parent")]
public class ParentController : ControllerBase
{
    private readonly ReportService _svc;
    private readonly AppDbContext _db;

    public ParentController(ReportService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    [HttpGet("children")]
    [RequireRole(UserRole.Parent, UserRole.Teacher, UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Children()
    {
        var userId = FakeAuth.GetUserId(HttpContext);
        if (userId is null)
            return BadRequest(new { error = "جلسة غير صالحة." });

        var user = await _db.Users
            .Include(u => u.Teacher)
            .FirstOrDefaultAsync(u => u.Id == userId.Value);

        if (user == null)
            return BadRequest(new { error = "المستخدم غير موجود." });

        var children = await _svc.GetChildrenProgressForUserAsync(user);
        if ((children == null || children.Count == 0) && user.ParentId.HasValue)
        {
            children = await _svc.GetChildrenProgressAsync(user.ParentId.Value);
        }

        return Ok(children ?? new List<ChildProgressDto>());
    }

    [HttpGet("teachers")]
    [RequireRole(UserRole.Parent, UserRole.Teacher, UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> GetParentTeachers()
    {
        var userId = FakeAuth.GetUserId(HttpContext);
        if (userId is null)
            return BadRequest(new { error = "جلسة غير صالحة." });

        var user = await _db.Users
            .Include(u => u.Teacher)
            .FirstOrDefaultAsync(u => u.Id == userId.Value);

        if (user == null)
            return BadRequest(new { error = "المستخدم غير موجود." });

        // 1. Get children of this parent
        var children = await _svc.GetSmartChildrenForParentAsync(user);
        if ((children == null || children.Count == 0) && user.ParentId.HasValue)
        {
            children = await _db.Students.Include(s => s.Circle).Where(s => s.ParentId == user.ParentId.Value).ToListAsync();
        }

        var distinctChildren = (children ?? new List<Student>()).GroupBy(c => c.Id).Select(g => g.First()).ToList();
        var childIds = distinctChildren.Select(c => c.Id).ToList();

        // 2. Fetch circles for Quran Memorization teachers
        var circleIds = distinctChildren.Where(c => c.CircleId.HasValue).Select(c => c.CircleId!.Value).Distinct().ToList();
        var circles = await _db.Circles
            .Include(c => c.Teacher)
            .Include(c => c.AssistantTeacher)
            .Where(c => circleIds.Contains(c.Id))
            .ToListAsync();

        // 3. Fetch courses for Course teachers
        var enrollments = await _db.CourseEnrollments
            .Include(e => e.Course)
                .ThenInclude(co => co.Teacher)
            .Include(e => e.Student)
            .Where(e => childIds.Contains(e.StudentId) && e.Course != null && e.Course.TeacherId.HasValue && e.Course.Teacher != null)
            .ToListAsync();

        // Aggregate by Teacher Id
        var teacherDict = new Dictionary<int, (
            int Id, 
            string FullName, 
            string? Phone, 
            bool IsQuran, 
            bool IsCourse, 
            HashSet<string> Children, 
            HashSet<string> Circles, 
            HashSet<string> Courses, 
            List<string> Details
        )>();

        // Process Quran Circles
        foreach (var child in distinctChildren)
        {
            if (child.CircleId.HasValue)
            {
                var circle = circles.FirstOrDefault(c => c.Id == child.CircleId.Value);
                if (circle?.Teacher != null)
                {
                    int tId = circle.Teacher.Id;
                    if (!teacherDict.ContainsKey(tId))
                    {
                        teacherDict[tId] = (tId, circle.Teacher.FullName, circle.Teacher.Contact ?? circle.Teacher.WhatsappNumber, false, false, new HashSet<string>(), new HashSet<string>(), new HashSet<string>(), new List<string>());
                    }
                    var item = teacherDict[tId];
                    item.IsQuran = true;
                    item.Children.Add(child.FullName);
                    item.Circles.Add(circle.Name);
                    item.Details.Add($"محفظ حلقة {circle.Name} (ابنك: {child.FullName})");
                    teacherDict[tId] = item;
                }

                if (circle?.AssistantTeacher != null)
                {
                    int aId = circle.AssistantTeacher.Id;
                    if (!teacherDict.ContainsKey(aId))
                    {
                        teacherDict[aId] = (aId, circle.AssistantTeacher.FullName, circle.AssistantTeacher.Contact ?? circle.AssistantTeacher.WhatsappNumber, false, false, new HashSet<string>(), new HashSet<string>(), new HashSet<string>(), new List<string>());
                    }
                    var item = teacherDict[aId];
                    item.IsQuran = true;
                    item.Children.Add(child.FullName);
                    item.Circles.Add(circle.Name);
                    item.Details.Add($"مساعد محفظ حلقة {circle.Name} (ابنك: {child.FullName})");
                    teacherDict[aId] = item;
                }
            }
        }

        // Process Courses
        foreach (var enr in enrollments)
        {
            if (enr.Course?.Teacher != null)
            {
                var t = enr.Course.Teacher;
                int tId = t.Id;
                var childName = enr.Student?.FullName ?? "الابن";
                if (!teacherDict.ContainsKey(tId))
                {
                    teacherDict[tId] = (tId, t.FullName, t.Contact ?? t.WhatsappNumber, false, false, new HashSet<string>(), new HashSet<string>(), new HashSet<string>(), new List<string>());
                }
                var item = teacherDict[tId];
                item.IsCourse = true;
                item.Children.Add(childName);
                item.Courses.Add(enr.Course.Name);
                item.Details.Add($"معلم دورة {enr.Course.Name} (ابنك: {childName})");
                teacherDict[tId] = item;
            }
        }

        var result = teacherDict.Values.Select(t => new
        {
            id = t.Id,
            fullName = t.FullName,
            phone = t.Phone,
            category = (t.IsQuran && t.IsCourse) ? "Both" : (t.IsQuran ? "Quran" : "Course"),
            categoryLabel = (t.IsQuran && t.IsCourse) ? "محفظ ومعلم دورة" : (t.IsQuran ? "محفظ قرآن كريم" : "معلم دورة تدريبية"),
            isQuranTeacher = t.IsQuran,
            isCourseTeacher = t.IsCourse,
            childrenNames = t.Children.ToList(),
            circles = t.Circles.ToList(),
            courses = t.Courses.ToList(),
            details = t.Details.Distinct().ToList(),
            summaryText = string.Join(" • ", t.Details.Distinct())
        }).ToList();

        // Admin or Dev fallback for testing preview
        if (result.Count == 0 && (user.Role == UserRole.Admin || user.Role == UserRole.Developer))
        {
            var fallbackTeachers = await _db.Teachers.Where(t => t.IsActive).Take(5).ToListAsync();
            result = fallbackTeachers.Select(t => new
            {
                id = t.Id,
                fullName = t.FullName,
                phone = t.Contact ?? t.WhatsappNumber,
                category = "Both",
                categoryLabel = "معلم المركز (معاينة تجريبية)",
                isQuranTeacher = true,
                isCourseTeacher = true,
                childrenNames = new List<string> { "طالب تجريبي" },
                circles = new List<string> { "حلقة الفجر" },
                courses = new List<string> { "دورة التجويد" },
                details = new List<string> { $"معلم بالمركز (معاينة الإدارة: {t.FullName})" },
                summaryText = $"معلم بالمركز (معاينة الإدارة)"
            }).ToList();
        }

        return Ok(result);
    }

    [HttpGet("audit")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> GetParentAudit()
    {
        var parentUsers = await _db.Users
            .Where(u => u.Role == UserRole.Parent)
            .ToListAsync();

        var allStudents = await _db.Students
            .Include(s => s.Circle)
            .ToListAsync();

        var result = new List<object>();

        foreach (var parent in parentUsers)
        {
            int pId = parent.ParentId ?? parent.Id;
            var uName = (parent.Username ?? "").Trim();

            var linkedChildren = allStudents
                .Where(s => (s.ParentId.HasValue && (s.ParentId == pId || s.ParentId == parent.Id))
                         || (!string.IsNullOrWhiteSpace(s.ParentIdentityNumber) && !string.IsNullOrWhiteSpace(uName) && s.ParentIdentityNumber.Trim() == uName)
                         || (!string.IsNullOrWhiteSpace(s.FamilyContact) && !string.IsNullOrWhiteSpace(uName) && s.FamilyContact.Trim() == uName))
                .Select(s => new
                {
                    s.Id,
                    s.FullName,
                    CircleId = s.CircleId,
                    CircleName = s.Circle?.Name ?? "غير مسند حلقة",
                    DateOfBirth = s.DateOfBirth.ToString("yyyy-MM-dd"),
                    s.FamilyContact,
                    s.StudentIdentityNumber,
                    s.ParentIdentityNumber,
                    s.FatherStatus,
                    s.MotherStatus,
                    s.Notes
                })
                .ToList();

            // Derive parent identity number from children's parentIdentityNumber field or username
            var parentIdNumber = linkedChildren.FirstOrDefault(c => !string.IsNullOrWhiteSpace(c.ParentIdentityNumber))?.ParentIdentityNumber;
            if (string.IsNullOrWhiteSpace(parentIdNumber))
            {
                parentIdNumber = !string.IsNullOrWhiteSpace(parent.Username) ? parent.Username : "غير مسجل";
            }

            // Derive parent name if FullName is missing or generic
            var rawName = (parent.FullName ?? "").Trim();
            var isGeneric = string.IsNullOrWhiteSpace(rawName) || rawName == "ولي أمر" || rawName.StartsWith("ولي أمر (");
            
            var resolvedParentName = !isGeneric
                ? rawName
                : (linkedChildren.Any() 
                    ? $"ولي أمر الطالب ({string.Join("، ", linkedChildren.Select(c => c.FullName))})" 
                    : (!string.IsNullOrWhiteSpace(rawName) ? rawName : $"ولي أمر ({parent.Username})"));

            result.Add(new
            {
                parentId = pId,
                parentUserId = parent.Id,
                parentName = resolvedParentName,
                username = parent.Username,
                parentIdentityNumber = parentIdNumber,
                childrenCount = linkedChildren.Count,
                children = linkedChildren
            });
        }

        return Ok(result);
    }

    public record UnlinkDto(int StudentId);

    [HttpPost("unlink-child")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> UnlinkChild([FromBody] UnlinkDto dto)
    {
        var student = await _db.Students.FindAsync(dto.StudentId);
        if (student == null) return NotFound(new { error = "الطالب غير موجود." });

        student.ParentId = null;
        await _db.SaveChangesAsync();

        return Ok(new { message = "تم فك ربط الطالب من ولي الأمر بنجاح." });
    }

    public record ReassignDto(int StudentId, int NewParentId);

    [HttpPost("reassign-child")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ReassignChild([FromBody] ReassignDto dto)
    {
        var student = await _db.Students.FindAsync(dto.StudentId);
        if (student == null) return NotFound(new { error = "الطالب غير موجود." });

        var parentUser = await _db.Users.FirstOrDefaultAsync(u => (u.ParentId == dto.NewParentId || u.Id == dto.NewParentId) && u.Role == UserRole.Parent);
        if (parentUser == null) return BadRequest(new { error = "حساب ولي الأمر الجديد غير موجود." });

        student.ParentId = parentUser.ParentId ?? parentUser.Id;
        await _db.SaveChangesAsync();

        return Ok(new { message = "تمت إعادة إسناد الطالب لولي الأمر الجديد بنجاح." });
    }
}
