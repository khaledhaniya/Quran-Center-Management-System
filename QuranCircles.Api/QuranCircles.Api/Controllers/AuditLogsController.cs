using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/auditlogs")]
[Route("api/audit-logs")]
[RequireRole(UserRole.Admin, UserRole.Developer)]
public class AuditLogsController : ControllerBase
{
    private readonly AppDbContext _db;

    public AuditLogsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetAuditLogs()
    {
        var logs = await _db.AuditLogs
            .OrderByDescending(l => l.Timestamp)
            .Take(100)
            .ToListAsync();

        return Ok(logs);
    }
}
