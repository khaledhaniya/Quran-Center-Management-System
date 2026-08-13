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
    public AttendanceController(AttendanceService svc) => _svc = svc;

    // تسجيل/تحديث حضور
    [HttpPost]
    public async Task<IActionResult> Record([FromBody] RecordAttendanceDto dto)
    {
        var (created, error) = await _svc.RecordAsync(dto);
        if (error is not null) return BadRequest(new { error });
        return Ok(created);
    }

    // عرض حضور طالب
    [HttpGet("student/{studentId:int}")]
    public async Task<IActionResult> GetByStudent(int studentId)
        => Ok(await _svc.GetByStudentAsync(studentId));
}
