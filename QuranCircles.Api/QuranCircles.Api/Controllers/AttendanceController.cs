using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/attendance")]
[RequireRole(UserRole.Admin, UserRole.Teacher)]
public class AttendanceController : ControllerBase
{
    private readonly AttendanceService _svc;
    private readonly AppDbContext _db;
    public AttendanceController(AttendanceService svc, AppDbContext db) { _svc = svc; _db = db; }

    // تسجيل/تحديث حضور
    [HttpPost]
    [Idempotent]
    public async Task<IActionResult> Record([FromBody] RecordAttendanceDto dto)
    {
        if (!await new CircleOperations(_db).CanRecordAsync(HttpContext, dto.CircleId, dto.SessionDate)) return Forbid();
        var (created, error) = await _svc.RecordAsync(dto);
        if (error is not null) return BadRequest(new { error });
        return Ok(created);
    }

    // عرض حضور طالب
    [HttpGet("student/{studentId:int}")]
    public async Task<IActionResult> GetByStudent(int studentId)
    {
        if (!await new StudentReadAccess(_db).CanReadAsync(HttpContext, studentId)) return Forbid();
        return Ok(await _svc.GetByStudentAsync(studentId));
    }
}
