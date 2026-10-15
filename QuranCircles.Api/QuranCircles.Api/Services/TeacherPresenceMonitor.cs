using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class TeacherPresenceMonitor(IServiceScopeFactory scopes, ILogger<TeacherPresenceMonitor> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                using var scope = scopes.CreateScope();
                await CheckAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "Teacher presence monitor failed"); }
        }
    }

    public static async Task CheckAsync(AppDbContext db, CancellationToken token = default)
    {
        var today = CenterClock.Today; var now = CenterClock.Now.TimeOfDay;
        var schedules = await db.CircleSchedules.AsNoTracking().ToListAsync(token);
        var circles = await db.Circles.Where(c => c.IsActive).AsNoTracking().ToListAsync(token);
        var days = await db.CircleDays.Where(d => d.Date == today).ToListAsync(token);
        foreach (var schedule in schedules.Where(s => CircleOperations.ScheduledOn(s, today)))
        {
            var circle = circles.FirstOrDefault(c => c.Id == schedule.CircleId);
            if (circle == null || !TimeOnly.TryParse(schedule.StartTime, out var start)) continue;
            if (now < start.ToTimeSpan().Add(TimeSpan.FromMinutes(15))) continue;
            var day = days.FirstOrDefault(d => d.CircleId == circle.Id);
            if (day != null && (day.OpenedAt.HasValue || day.LateAlertSent || day.Status == "Suspended")) continue;
            if (day == null) { day = new CircleDay { CircleId = circle.Id, Date = today, TeacherId = circle.TeacherId }; db.CircleDays.Add(day); }
            day.LateAlertSent = true;
            var supervisor = schedule.SupervisorUserId.HasValue ? await db.Users.FindAsync(new object[] { schedule.SupervisorUserId.Value }, token) : null;
            db.Announcements.Add(new Announcement {
                Title = $"تأخر بدء حلقة {circle.Name}",
                Content = "مضت 15 دقيقة على موعد الحلقة دون تسجيل بدء الجلسة. يرجى المتابعة وتحديد بديل عند الحاجة.",
                TargetType = supervisor?.TeacherId.HasValue == true ? AnnouncementTarget.Teacher : AnnouncementTarget.Admin,
                TargetId = supervisor?.TeacherId, DateTimeSent = DateTime.UtcNow, SenderName = "متابعة الحلقات"
            });
        }
        await db.SaveChangesAsync(token);
    }
}
