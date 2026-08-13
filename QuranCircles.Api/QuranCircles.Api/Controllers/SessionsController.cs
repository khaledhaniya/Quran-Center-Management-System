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
    public SessionsController(SessionService svc) => _svc = svc;

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
    public async Task<IActionResult> Create([FromBody] CreateSessionDto dto)
    {
        var (created, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });
        return CreatedAtAction(nameof(Get), new { id = created!.Id }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateSessionDto dto)
    {
        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var ok = await _svc.DeleteAsync(id);
        return ok ? NoContent() : NotFound(new { error = "الجلسة غير موجودة." });
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
