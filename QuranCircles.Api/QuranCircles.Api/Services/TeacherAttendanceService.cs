using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public record TeacherAttendanceRow(int CircleId, string CircleName, DateOnly Date, int? TeacherId, string TeacherName,
    string Status, string StatusText, bool IsAutomatic, string? ScheduledStart, string? OpenedAt, string? ClosedAt,
    int? LateMinutes, int? SubstituteUserId, string SubstituteName, string Reason);

public class TeacherAttendanceService(AppDbContext db)
{
    public async Task<bool> CanManageAsync(HttpContext context)
    {
        if (FakeAuth.GetRole(context) is UserRole.Admin or UserRole.Developer) return true;
        var user = await db.Users.Include(u => u.Teacher).AsNoTracking().FirstOrDefaultAsync(u => u.Id == FakeAuth.GetUserId(context));
        var tasks = user?.Teacher?.TaskRole ?? "";
        return user?.Teacher?.IsActive == true && (tasks.Contains("الجودة") || tasks.Contains("الرقابة"));
    }

    public async Task<List<TeacherAttendanceRow>> BuildAsync(DateOnly from, DateOnly to, int? circleId = null, DateTime? localNow = null)
    {
        var now = localNow ?? CenterClock.Now;
        if (to < from || to.DayNumber - from.DayNumber > 92 || to > DateOnly.FromDateTime(now)) throw new ArgumentException("اختر فترة لا تزيد عن ثلاثة أشهر وتنتهي اليوم أو قبله.");
        var circles = await db.Circles.AsNoTracking().Where(c => !circleId.HasValue || c.Id == circleId).ToListAsync();
        var schedules = await db.CircleSchedules.AsNoTracking().ToDictionaryAsync(s => s.CircleId);
        var days = (await db.CircleDays.AsNoTracking().Where(d => d.Date >= from && d.Date <= to && (!circleId.HasValue || d.CircleId == circleId)).ToListAsync()).ToDictionary(d => (d.CircleId, d.Date));
        var teachers = await db.Teachers.AsNoTracking().ToDictionaryAsync(t => t.Id, t => t.FullName);
        var users = await db.Users.AsNoTracking().ToDictionaryAsync(u => u.Id, u => u.FullName);
        var rows = new List<TeacherAttendanceRow>();
        foreach (var circle in circles.OrderBy(c => c.Name))
        for (var date = from; date <= to; date = date.AddDays(1))
        {
            days.TryGetValue((circle.Id, date), out var day);
            schedules.TryGetValue(circle.Id, out var schedule);
            var scheduled = schedule != null && CircleOperations.ScheduledOn(schedule, date);
            if (day == null && (!circle.IsActive || (!scheduled && !(schedule == null && date == to)))) continue;
            DateTime? start = scheduled && TimeOnly.TryParse(schedule!.StartTime, out var time) ? date.ToDateTime(time) : null;
            var opened = day?.OpenedAt is DateTime o ? CenterClock.Local(o) : (DateTime?)null;
            var closed = day?.ClosedAt is DateTime c ? CenterClock.Local(c) : (DateTime?)null;
            int? late = opened.HasValue && start.HasValue ? Math.Max(0, (int)(opened.Value - start.Value).TotalMinutes) : null;
            var status = day?.Status is "Absent" or "Suspended" ? day.Status : opened.HasValue ? (late > 0 ? "Late" : "Present")
                : start.HasValue && now >= start.Value.AddMinutes(schedule!.DurationMinutes) ? "Absent"
                : start.HasValue && now >= start.Value.AddMinutes(15) ? "LatePending"
                : start.HasValue ? "Pending" : "Unscheduled";
            var label = status switch { "Absent" => "غائب", "Suspended" => "الحلقة معلقة", "Late" => "حاضر متأخر", "Present" => "حاضر", "LatePending" => "متأخر • لم تبدأ", "Pending" => "بانتظار بدء الحلقة", _ => "الموعد غير محدد" };
            var teacherId = day?.TeacherId ?? circle.TeacherId;
            rows.Add(new(circle.Id, circle.Name, date, teacherId, teacherId.HasValue ? teachers.GetValueOrDefault(teacherId.Value, "غير معين") : "غير معين",
                status, label, status == "Absent" && day?.Status != "Absent", start?.ToString("HH:mm"), opened?.ToString("HH:mm"), closed?.ToString("HH:mm"),
                late, day?.SubstituteUserId, day?.SubstituteUserId is int sub ? users.GetValueOrDefault(sub, "حساب غير متاح") : "", day?.Reason ?? ""));
        }
        return rows.OrderByDescending(r => r.Date).ThenBy(r => r.CircleName).ToList();
    }

    public async Task AssignAsync(int circleId, DateOnly date, int? substituteId, string reason, int actorId, string actorName)
    {
        if (date > CenterClock.Today || date < CenterClock.Today.AddDays(-92) || string.IsNullOrWhiteSpace(reason)) throw new ArgumentException("حدد تاريخاً صحيحاً وسبب الغياب أو الإجازة.");
        var circle = await db.Circles.FindAsync(circleId) ?? throw new ArgumentException("الحلقة غير موجودة.");
        if (substituteId.HasValue)
        {
            var substitute = await db.Users.Include(u => u.Teacher).FirstOrDefaultAsync(u => u.Id == substituteId);
            if (substitute?.IsActive != true || substitute.Teacher?.IsActive != true || substitute.TeacherId == circle.TeacherId)
                throw new ArgumentException("اختر حساب معلم نشط يختلف عن المعلم الأصلي.");
        }
        var day = await db.CircleDays.FirstOrDefaultAsync(d => d.CircleId == circleId && d.Date == date);
        if (day?.Status == "Suspended" || (day?.OpenedAt != null && day.Status != "Absent")) throw new ArgumentException("توجد جلسة بدأها المعلم الأصلي أو حلقة معلقة؛ راجع سجلها قبل تغيير الغياب.");
        if (day == null) { day = new CircleDay { CircleId = circleId, Date = date, TeacherId = circle.TeacherId }; db.CircleDays.Add(day); }
        day.Status = "Absent"; day.SubstituteUserId = substituteId; day.Reason = reason.Trim(); day.UpdatedByUserId = actorId;
        db.AuditLogs.Add(new AuditLog { Username = actorName, Action = "TeacherCoverage", Details = $"Circle {circleId}; Date {date}; Original teacher {day.TeacherId}; Substitute user {substituteId}; {day.Reason}" });
        await db.SaveChangesAsync();
    }
}
