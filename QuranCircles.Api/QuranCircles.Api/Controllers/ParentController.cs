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
