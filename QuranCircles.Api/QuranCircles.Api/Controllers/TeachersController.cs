using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/teachers")]
public class TeachersController : ControllerBase
{
    private readonly TeacherService _svc;
    private readonly AppDbContext _db;

    public TeachersController(TeacherService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetAll([FromQuery] string? search)
        => Ok(await _svc.GetAllAsync(search));

    [HttpGet("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Get(int id)
    {
        var t = await _svc.GetByIdAsync(id);
        return t is null ? NotFound(new { error = "المعلّم غير موجود." }) : Ok(t);
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateTeacherDto dto)
    {
        var (created, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "CreateTeacher", $"إضافة معلم جديد: {created!.FullName}");

        return CreatedAtAction(nameof(Get), new { id = created!.Id }, created);
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateTeacherDto dto)
    {
        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateTeacher", $"تعديل بيانات المعلم: {dto.FullName} (ID: #{id})");

        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Deactivate(int id)
    {
        var ok = await _svc.DeactivateAsync(id);
        if (ok)
        {
            await AuditLogger.LogAsync(_db, HttpContext, "DeactivateTeacher", $"تعطيل حساب المعلم ID: #{id}");
        }
        return ok ? NoContent() : NotFound(new { error = "المعلّم غير موجود." });
    }

    [HttpDelete("{id:int}/permanent")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> HardDelete(int id)
    {
        var (ok, teacherName, error) = await _svc.HardDeleteAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "HardDeleteTeacher", $"حذف معلم نهائياً: {teacherName} (ID: #{id}) وحسابه بالتنسيق");

        return Ok(new { Message = $"تم حذف المعلم ({teacherName}) نهائياً من النظام." });
    }

    [HttpPost("{id:int}/toggle-active")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ToggleActive(int id)
    {
        var (ok, newStatus, error) = await _svc.ToggleActiveAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "ToggleActiveTeacher", $"تغيير حالة تفعيل المعلم ID #{id} إلى: {(newStatus ? "نشط" : "معطل")}");

        return Ok(new { Message = newStatus ? "تم تنشيط المعلم بنجاح." : "تم تعطيل المعلم بنجاح.", IsActive = newStatus });
    }
}
