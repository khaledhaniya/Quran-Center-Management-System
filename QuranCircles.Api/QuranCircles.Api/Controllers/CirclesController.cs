using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/circles")]
public class CirclesController : ControllerBase
{
    private readonly CircleService _svc;
    private readonly AppDbContext _db;
    public CirclesController(CircleService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> GetAll()
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser != null && currentUser.Role == UserRole.Teacher)
        {
            int teacherId = currentUser.TeacherId ?? 0;
            if (teacherId == 0)
            {
                var t = await _db.Teachers.FirstOrDefaultAsync(x => x.FullName == currentUser.FullName);
                if (t != null) teacherId = t.Id;
            }
            return Ok(await _svc.GetAllForTeacherAsync(teacherId));
        }
        return Ok(await _svc.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> Get(int id)
    {
        var c = await _svc.GetByIdAsync(id);
        return c is null ? NotFound(new { error = "الحلقة غير موجودة." }) : Ok(c);
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateCircleDto dto)
    {
        var (created, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "CreateCircle", $"إضافة حلقة جديدة: {created!.Name}");

        return CreatedAtAction(nameof(Get), new { id = created!.Id }, created);
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCircleDto dto)
    {
        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateCircle", $"تعديل الحلقة: {dto.Name} (ID: #{id})");

        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Deactivate(int id)
    {
        var ok = await _svc.DeactivateAsync(id);
        if (ok)
        {
            await AuditLogger.LogAsync(_db, HttpContext, "DeactivateCircle", $"تعطيل الحلقة ID: #{id}");
        }
        return ok ? NoContent() : NotFound(new { error = "الحلقة غير موجودة." });
    }

    [HttpDelete("{id:int}/permanent")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> HardDelete(int id)
    {
        var (ok, circleName, error) = await _svc.HardDeleteAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "HardDeleteCircle", $"حذف حلقة قرآنية نهائياً: {circleName} (ID: #{id})");

        return Ok(new { Message = $"تم حذف الحلقة ({circleName}) نهائياً من النظام." });
    }

    [HttpPost("{id:int}/toggle-active")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ToggleActive(int id)
    {
        var (ok, newStatus, error) = await _svc.ToggleActiveAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "ToggleActiveCircle", $"تغيير حالة تفعيل الحلقة ID #{id} إلى: {(newStatus ? "نشطة" : "معطلة")}");

        return Ok(new { Message = newStatus ? "تم تنشيط الحلقة بنجاح." : "تم تعطيل الحلقة بنجاح.", IsActive = newStatus });
    }

    [HttpPost("{id:int}/students")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> AddStudent(int id, [FromBody] AssignStudentDto dto)
    {
        var (ok, error) = await _svc.AddStudentAsync(id, dto.StudentId);
        if (!ok) return BadRequest(new { error });
        return NoContent();
    }

    [HttpDelete("{id:int}/students/{studentId:int}")]
    [RequireRole(UserRole.Admin)]
    public async Task<IActionResult> RemoveStudent(int id, int studentId)
    {
        var (ok, error) = await _svc.RemoveStudentAsync(id, studentId);
        if (!ok) return BadRequest(new { error });
        return NoContent();
    }
}
