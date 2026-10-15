using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/sessions")]
[RequireRole(UserRole.Admin, UserRole.Teacher)]
public class SessionsController : ControllerBase
{
    private readonly SessionService _svc;
    private readonly AppDbContext _db;
    public SessionsController(SessionService svc, AppDbContext db) { _svc = svc; _db = db; }

    [HttpGet("student/{studentId:int}")]
    public async Task<IActionResult> GetByStudent(int studentId)
        => Ok(await _svc.GetByStudentAsync(studentId));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var s = await _svc.GetByIdAsync(id);
        return s is null ? NotFound(new { error = "الجلسة غير موجودة." }) : Ok(s);
    }

    [HttpPost]
    [Idempotent]
    public async Task<IActionResult> Create([FromBody] CreateSessionDto dto)
    {
        var student = await _db.Students.FindAsync(dto.StudentId);
        if (student?.CircleId == null || !await new CircleOperations(_db).CanRecordAsync(HttpContext, student.CircleId.Value, dto.SessionDate)) return Forbid();
        var (created, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });
        var entity = await _db.Sessions.FindAsync(created!.Id);
        entity!.RecordedByUserId = FakeAuth.GetUserId(HttpContext);
        entity.RecordedCircleId = student.CircleId;
        entity.RecordedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        await new CircleOperations(_db).StartAsync(student.CircleId.Value, FakeAuth.GetUserId(HttpContext)!.Value, dto.SessionDate);
        return CreatedAtAction(nameof(Get), new { id = created!.Id }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateSessionDto dto)
    {
        if (!await CanEdit(id)) return Forbid();
        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        if (!await CanEdit(id)) return Forbid();
        var ok = await _svc.DeleteAsync(id);
        return ok ? NoContent() : NotFound(new { error = "الجلسة غير موجودة." });
    }

    private async Task<bool> CanEdit(int id)
    {
        var session = await _db.Sessions.Include(s => s.Student).FirstOrDefaultAsync(s => s.Id == id);
        var circleId = session?.RecordedCircleId ?? session?.Student?.CircleId;
        return session != null && circleId.HasValue && await new CircleOperations(_db).CanRecordAsync(HttpContext, circleId.Value, session.SessionDate);
    }

    [HttpGet("lottery/{circleId:int}")]
    public async Task<IActionResult> Lottery(int circleId, [FromQuery] DateOnly? date)
    {
        var d = date ?? DateOnly.FromDateTime(DateTime.Today);
        var (result, error) = await _svc.DrawAsync(circleId, d);
        if (error is not null) return BadRequest(new { error });
        return Ok(result);
    }
}
