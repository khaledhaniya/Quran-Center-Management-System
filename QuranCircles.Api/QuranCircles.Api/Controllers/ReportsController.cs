using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/reports")]
[RequireRole(UserRole.Admin)]
public class ReportsController : ControllerBase
{
    private readonly ReportService _svc;
    public ReportsController(ReportService svc) => _svc = svc;

    [HttpGet("summary")]
    public async Task<IActionResult> Summary([FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        var f = from ?? DateOnly.FromDateTime(DateTime.Today.AddMonths(-1));
        var t = to ?? DateOnly.FromDateTime(DateTime.Today);
        if (t < f) return BadRequest(new { error = "تاريخ النهاية يسبق تاريخ البداية." });

        return Ok(await _svc.GetSummaryAsync(f, t));
    }
}
