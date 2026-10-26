using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController, Route("api/operations")]
[RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.ExamSupervisor)]
public class OperationsController(AppDbContext db) : ControllerBase
{
    [HttpGet("today")]
    public IActionResult Today() => Ok(new { date = CenterClock.Today.ToString("yyyy-MM-dd") });

    [HttpGet("teacher-attendance")]
    public async Task<IActionResult> TeacherAttendance([FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] int? circleId, [FromQuery] int? teacherId = null, [FromQuery] string? status = null, [FromQuery] string? search = null)
    {
        try {
            var service = new TeacherAttendanceService(db);
            var rows = await service.BuildAsync(from ?? CenterClock.Today, to ?? CenterClock.Today, circleId);
            if(!await service.CanManageAsync(HttpContext)) {
                var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == FakeAuth.GetUserId(HttpContext));
                if(user?.TeacherId == null)return Forbid();
                rows = rows.Where(r => r.TeacherId == user.TeacherId || r.SubstituteUserId == user.Id).ToList();
            }
            return Ok(TeacherAttendanceService.Filter(rows, teacherId, status, search));
        }
        catch (ArgumentException e) { return BadRequest(new { error = e.Message }); }
    }

    [HttpGet("substitutes")]
    public async Task<IActionResult> Substitutes([FromQuery] int? circleId)
    {
        if (!await new TeacherAttendanceService(db).CanManageAsync(HttpContext)) return Forbid();
        var original = await db.Circles.Where(c => c.Id == circleId).Select(c => c.TeacherId).FirstOrDefaultAsync();
        return Ok(await db.Users.AsNoTracking().Where(u => u.IsActive && u.Teacher != null && u.Teacher.IsActive && u.TeacherId != original)
            .OrderBy(u => u.FullName).Select(u => new { u.Id, u.FullName, u.TeacherId }).ToListAsync());
    }

    [HttpPost("coverage/{circleId:int}")]
    public async Task<IActionResult> Coverage(int circleId, CoverageInput input)
    {
        var service = new TeacherAttendanceService(db);
        if (!await service.CanManageAsync(HttpContext)) return Forbid();
        try {
            await service.AssignAsync(circleId, input.Date, input.SubstituteUserId, input.Reason, FakeAuth.GetUserId(HttpContext)!.Value, FakeAuth.GetUsername(HttpContext) ?? "");
            return Ok(new { message = input.SubstituteUserId.HasValue ? "تم تسجيل غياب المعلم الأصلي وتكليف البديل لهذا اليوم." : "تم تسجيل الغياب دون تغطية بديلة." });
        } catch (ArgumentException e) { return BadRequest(new { error = e.Message }); }
    }
    public record CoverageInput(DateOnly Date, int? SubstituteUserId, string Reason);

    [HttpGet("plan-targets")]
    public async Task<IActionResult> PlanTargets()
    {
        if (!await new TeacherAttendanceService(db).CanManageAsync(HttpContext)) return Forbid();
        var circles = await db.Circles.AsNoTracking().Where(c => c.IsActive)
            .OrderBy(c => c.Name).Select(c => new { c.Id, c.Name, TeacherName = c.Teacher != null ? c.Teacher.FullName : "بدون محفظ" }).ToListAsync();
        var courses = await db.Courses.AsNoTracking().Where(c => c.IsActive)
            .OrderBy(c => c.Name).Select(c => new { c.Id, c.Name }).ToListAsync();
        return Ok(new { circles, courses });
    }

    [HttpGet("plans")]
    public async Task<IActionResult> Plans() => await new TeacherAttendanceService(db).CanManageAsync(HttpContext)
        ? Ok(await db.CirclePlans.AsNoTracking().OrderByDescending(p => p.StartsOn).ToListAsync()) : Forbid();

    [HttpPost("plans")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> SavePlan(CirclePlan input)
    {
        if (!await new TeacherAttendanceService(db).CanManageAsync(HttpContext)) return Forbid();
        var coursePlan = input.Track == "Course";
        var validTarget = coursePlan
            ? input.CourseId.HasValue && await db.Courses.AnyAsync(c => c.Id == input.CourseId.Value && c.IsActive)
            : await db.Circles.AnyAsync(c => c.Id == input.CircleId && c.IsActive);
        if (!validTarget || string.IsNullOrWhiteSpace(input.Title) ||
            input.Target <= 0 || input.Completed < 0 || input.Completed > input.Target || input.EndsOn < input.StartsOn ||
            !new[] { "Quran", "Aqeedah", "Tajweed", "Course" }.Contains(input.Track))
            return BadRequest(new { error = "تحقق من الحلقة والمسار والتواريخ والهدف والإنجاز." });
        var plan = input.Id == 0 ? new CirclePlan() : await db.CirclePlans.FindAsync(input.Id);
        if (plan == null) return NotFound();
        if (input.Id == 0) db.CirclePlans.Add(plan);
        plan.CircleId = coursePlan ? 0 : input.CircleId;
        plan.CourseId = coursePlan ? input.CourseId : null;
        plan.Title = input.Title.Trim(); plan.Track = input.Track;
        plan.Unit = input.Unit.Trim(); plan.Target = input.Target; plan.Completed = input.Completed;
        plan.StartsOn = input.StartsOn; plan.EndsOn = input.EndsOn; plan.Notes = input.Notes;
        plan.UpdatedByUserId = FakeAuth.GetUserId(HttpContext)!.Value; plan.UpdatedAt = DateTime.UtcNow;
        db.AuditLogs.Add(new AuditLog { Username = FakeAuth.GetUsername(HttpContext)!, Action = "CirclePlan",
            Details = $"{(coursePlan ? $"Course {plan.CourseId}" : $"Circle {plan.CircleId}")}: {plan.Title}; {plan.Completed}/{plan.Target}" });
        await db.SaveChangesAsync(); return Ok(plan);
    }

    [HttpGet("schedules")]
    public async Task<IActionResult> Schedules() => await new TeacherAttendanceService(db).CanManageAsync(HttpContext)
        ? Ok(await db.CircleSchedules.AsNoTracking().ToListAsync()) : Forbid();

    [HttpPost("schedules")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> SaveSchedule(CircleSchedule input)
    {
        if (!await db.Circles.AnyAsync(c => c.Id == input.CircleId) || !TimeOnly.TryParseExact(input.StartTime, "HH:mm", out _) ||
            input.Capacity < 1 || input.Capacity > 500 || input.DurationMinutes < 15 || input.DurationMinutes > 480 ||
            string.IsNullOrWhiteSpace(input.Weekdays) || input.Weekdays.Split(',').Any(d => !int.TryParse(d, out var n) || n < 1 || n > 7))
            return BadRequest(new { error = "تحقق من وقت الحلقة والأيام والسعة والمدة." });
        if (input.SupervisorUserId.HasValue && !await db.Users.AnyAsync(u => u.Id == input.SupervisorUserId && u.IsActive)) return BadRequest();
        var row = await db.CircleSchedules.FirstOrDefaultAsync(x => x.CircleId == input.CircleId);
        if (row == null) { row = new CircleSchedule { CircleId = input.CircleId }; db.CircleSchedules.Add(row); }
        row.Weekdays = string.Join(',', input.Weekdays.Split(',').Distinct()); row.StartTime = input.StartTime;
        row.Capacity = input.Capacity; row.DurationMinutes = input.DurationMinutes; row.SupervisorUserId = input.SupervisorUserId;
        await db.SaveChangesAsync(); return Ok(row);
    }

    [HttpGet("days")]
    public async Task<IActionResult> Days([FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        if (!await new TeacherAttendanceService(db).CanManageAsync(HttpContext)) return Forbid();
        var f = from ?? CenterClock.Today.AddDays(-30); var t = to ?? CenterClock.Today;
        return Ok(await db.CircleDays.AsNoTracking().Where(d => d.Date >= f && d.Date <= t).ToListAsync());
    }

    [HttpPost("days/{circleId:int}")]
    public async Task<IActionResult> SetDay(int circleId, DayInput input)
    {
        var role = FakeAuth.GetRole(HttpContext);
        var admin = role is UserRole.Admin or UserRole.Developer;
        if (!admin && (!await new CircleOperations(db).CanRecordAsync(HttpContext, circleId, input.Date) || input.Status != "Closed")) return Forbid();
        var circle = await db.Circles.FindAsync(circleId); if (circle == null) return NotFound();
        if (!new[] { "Absent", "Suspended", "Closed", "Pending" }.Contains(input.Status) || input.Date > CenterClock.Today ||
            (input.Status is "Absent" or "Suspended" && string.IsNullOrWhiteSpace(input.Reason))) return BadRequest();
        var day = await db.CircleDays.FirstOrDefaultAsync(d => d.CircleId == circleId && d.Date == input.Date);
        if (day == null) { day = new CircleDay { CircleId = circleId, Date = input.Date, TeacherId = circle.TeacherId }; db.CircleDays.Add(day); }
        if (input.Status == "Closed" && day.OpenedAt == null) return BadRequest(new { error = "لم تبدأ الحلقة بعد." });
        if (input.Status == "Closed") day.ClosedAt = DateTime.UtcNow;
        else { day.Status = input.Status; day.SubstituteUserId = null; }
        day.Reason = input.Reason ?? ""; day.UpdatedByUserId = FakeAuth.GetUserId(HttpContext)!.Value;
        db.AuditLogs.Add(new AuditLog { Username = FakeAuth.GetUsername(HttpContext)!, Action = "TeacherAttendance", Details = $"Circle {circleId}, {input.Date}, {input.Status}: {input.Reason}" });
        await db.SaveChangesAsync(); return Ok(day);
    }
    public record DayInput(DateOnly Date, string Status, string? Reason);
}
