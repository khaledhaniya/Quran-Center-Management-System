using Microsoft.AspNetCore.Mvc;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/reports")]
[RequireRole(UserRole.Admin, UserRole.Developer)]
public class ReportsController : ControllerBase
{
    private readonly ReportService _svc;
    public ReportsController(ReportService svc) => _svc = svc;

    [HttpGet("summary")]
    public async Task<IActionResult> Summary([FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        var today = CenterClock.Today;
        var f = from ?? new DateOnly(today.Year, today.Month, 1);
        var t = to ?? today;
        if (t < f) return BadRequest(new { error = "تاريخ النهاية يسبق تاريخ البداية." });

        return Ok(await _svc.GetSummaryAsync(f, t));
    }

    [HttpGet("executive-dashboard")]
    public async Task<IActionResult> ExecutiveDashboard([FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] DateOnly? fromDate, [FromQuery] DateOnly? toDate)
    {
        var today = CenterClock.Today;
        var f = from ?? fromDate ?? new DateOnly(today.Year, today.Month, 1);
        var t = to ?? toDate ?? today;
        if (t < f) t = f;

        return Ok(await _svc.GetExecutiveDashboardAsync(f, t));
    }
}
