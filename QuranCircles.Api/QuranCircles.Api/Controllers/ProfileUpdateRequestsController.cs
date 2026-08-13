namespace QuranCircles.Api.Controllers;

using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System.Text.Json;

[ApiController]
[Route("api/profile-update-requests")]
public class ProfileUpdateRequestsController : ControllerBase
{
    private readonly AppDbContext _db;

    public ProfileUpdateRequestsController(AppDbContext db)
    {
        _db = db;
    }

    public record SubmitRequestDto(
        int? StudentId,
        string RequestedByRole,
        string RequestedByName,
        Dictionary<string, string> Changes
    );

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> Submit([FromBody] SubmitRequestDto dto)
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        if (!currentUserId.HasValue) return Unauthorized();

        var req = new ProfileUpdateRequest
        {
            UserId = currentUserId.Value,
            StudentId = dto.StudentId,
            RequestedByRole = dto.RequestedByRole,
            RequestedByName = dto.RequestedByName,
            ChangesJson = JsonSerializer.Serialize(dto.Changes),
            Status = "Pending",
            RequestDate = DateTime.UtcNow
        };

        _db.ProfileUpdateRequests.Add(req);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "SubmitProfileUpdateRequest", $"تقديم طلب جديد لتعديل بيانات العائلة والطالب بواسطة: {dto.RequestedByName} ({dto.RequestedByRole})");

        return Ok(new { message = "تم تقديم طلب التعديل بنجاح وسيتم مراجعته من الإدارة.", id = req.Id });
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> GetAll()
    {
        var requests = await _db.ProfileUpdateRequests
            .OrderByDescending(r => r.RequestDate)
            .ToListAsync();

        var studentIds = requests.Where(r => r.StudentId.HasValue).Select(r => r.StudentId!.Value).Distinct().ToList();
        var studentsMap = await _db.Students.Where(s => studentIds.Contains(s.Id)).ToDictionaryAsync(s => s.Id, s => s.FullName);

        var list = requests.Select(r => new {
            r.Id,
            r.UserId,
            r.StudentId,
            StudentName = r.StudentId.HasValue && studentsMap.TryGetValue(r.StudentId.Value, out var sName) ? sName : "طلب بيانات عامة",
            r.RequestedByRole,
            r.RequestedByName,
            Changes = JsonSerializer.Deserialize<Dictionary<string, string>>(r.ChangesJson),
            r.Status,
            RequestDate = r.RequestDate.ToString("yyyy-MM-dd HH:mm"),
            r.ReviewerNotes,
            ReviewDate = r.ReviewDate?.ToString("yyyy-MM-dd HH:mm")
        });

        return Ok(list);
    }

    [HttpPost("{id:int}/approve")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Approve(int id)
    {
        var req = await _db.ProfileUpdateRequests.FindAsync(id);
        if (req == null) return NotFound(new { error = "الطلب غير موجود." });

        if (req.Status != "Pending")
            return BadRequest(new { error = "تم اتخاذ قرار سابق بشأن هذا الطلب." });

        req.Status = "Approved";
        req.ReviewDate = DateTime.UtcNow;

        string studentName = "طلب عام";

        // Apply changes to Student if StudentId exists
        if (req.StudentId.HasValue)
        {
            var student = await _db.Students.FindAsync(req.StudentId.Value);
            if (student != null)
            {
                studentName = student.FullName;
                var changes = JsonSerializer.Deserialize<Dictionary<string, string>>(req.ChangesJson);
                if (changes != null)
                {
                    if (changes.TryGetValue("studentMobile", out var mobile)) student.StudentMobile = mobile;
                    if (changes.TryGetValue("familyContact", out var contact)) student.FamilyContact = contact;
                    if (changes.TryGetValue("address", out var addr)) student.Address = addr;
                    if (changes.TryGetValue("currentAddress", out var currAddr)) student.CurrentAddress = currAddr;
                    if (changes.TryGetValue("healthStatus", out var health)) student.HealthStatus = health;
                    if (changes.TryGetValue("notes", out var notes)) student.Notes = notes;
                    if (changes.TryGetValue("walletNumber", out var wallet)) student.WalletNumber = wallet;
                    if (changes.TryGetValue("bankAccountNumber", out var bankAcc)) student.BankAccountNumber = bankAcc;
                    if (changes.TryGetValue("bankName", out var bankName)) student.BankName = bankName;
                    if (changes.TryGetValue("previousQuranMemorization", out var quran)) student.PreviousQuranMemorization = quran;
                    if (changes.TryGetValue("studentWhatsapp", out var sWhatsapp)) student.StudentWhatsapp = sWhatsapp;
                    if (changes.TryGetValue("whatsappNumber", out var whatsapp)) student.WhatsappNumber = whatsapp;
                    if (changes.TryGetValue("originalAddress", out var origAddr)) student.OriginalAddress = origAddr;
                    if (changes.TryGetValue("originalHousingType", out var origType)) student.OriginalHousingType = origType;
                    if (changes.TryGetValue("originalHousingStatus", out var origStatus)) student.OriginalHousingStatus = origStatus;
                    if (changes.TryGetValue("currentHousingType", out var currType)) student.CurrentHousingType = currType;
                    if (changes.TryGetValue("fatherStatus", out var fStatus)) student.FatherStatus = fStatus;
                    if (changes.TryGetValue("motherStatus", out var mStatus)) student.MotherStatus = mStatus;
                    if (changes.TryGetValue("studentIdentityNumber", out var sIdNum)) student.StudentIdentityNumber = sIdNum;
                    if (changes.TryGetValue("parentIdentityNumber", out var pIdNum)) student.ParentIdentityNumber = pIdNum;
                }
            }
        }

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "ApproveProfileUpdateRequest", $"الموافقة على طلب تعديل البيانات وتحديث الملف للطالب: {studentName} (مقدم الطلب: {req.RequestedByName})");

        return Ok(new { message = "تمت الموافقة على طلب التعديل وتطبيق البيانات بنجاح." });
    }

    [HttpPost("{id:int}/reject")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Reject(int id, [FromBody] Dictionary<string, string>? body)
    {
        var req = await _db.ProfileUpdateRequests.FindAsync(id);
        if (req == null) return NotFound(new { error = "الطلب غير موجود." });

        if (req.Status != "Pending")
            return BadRequest(new { error = "تم اتخاذ قرار سابق بشأن هذا الطلب." });

        req.Status = "Rejected";
        req.ReviewDate = DateTime.UtcNow;
        if (body != null && body.TryGetValue("notes", out var notes))
        {
            req.ReviewerNotes = notes;
        }

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "RejectProfileUpdateRequest", $"رفض طلب تعديل البيانات المقدم من: {req.RequestedByName}");

        return Ok(new { message = "تم رفض طلب التعديل." });
    }
}
