using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class CircleOperations(AppDbContext db)
{
    public static bool ScheduledOn(CircleSchedule schedule, DateOnly date) =>
        schedule.Weekdays.Split(',').Contains((((int)date.DayOfWeek + 6) % 7 + 1).ToString());

    public async Task<bool> CanRecordAsync(HttpContext context, int circleId, DateOnly date)
    {
        var userId = FakeAuth.GetUserId(context);
        var user = await db.Users.Include(u => u.Teacher).FirstOrDefaultAsync(u => u.Id == userId);
        var circle = await db.Circles.FindAsync(circleId);
        if (user == null || circle == null) return false;
        if (user.Role == UserRole.Teacher && date != CenterClock.Today &&
            await db.SystemSettings.AsNoTracking().AnyAsync(s => s.EnforceDailyAttendanceRecording))
            return false;
        var day = await db.CircleDays.FirstOrDefaultAsync(d => d.CircleId == circleId && d.Date == date);
        if (day?.Status is "Suspended" or "Closed") return false;
        if (day?.Status == "Absent")
            return day.SubstituteUserId == userId && user.Teacher?.IsActive == true &&
                user.TeacherId != circle.TeacherId;
        if (FakeAuth.GetRole(context) is UserRole.Admin or UserRole.Developer) return true;
        if (user.Teacher?.IsActive == true && circle.IsActive &&
            (circle.TeacherId == user.TeacherId || circle.AssistantTeacherId == user.TeacherId)) return true;
        return false;
    }

    public async Task StartAsync(int circleId, int userId, DateOnly date)
    {
        if (date != CenterClock.Today) return; // Backfilled records never imply live presence.
        var day = await db.CircleDays.FirstOrDefaultAsync(x => x.CircleId == circleId && x.Date == date);
        if (day == null)
        {
            day = new CircleDay { CircleId = circleId, Date = date,
                TeacherId = await db.Circles.Where(x => x.Id == circleId).Select(x => x.TeacherId).SingleAsync() };
            db.CircleDays.Add(day);
        }
        if (day.OpenedAt == null) day.OpenedAt = DateTime.UtcNow;
        if (day.Status != "Absent") day.Status = "Present";
        day.UpdatedByUserId = userId;
        await db.SaveChangesAsync();
    }
}
