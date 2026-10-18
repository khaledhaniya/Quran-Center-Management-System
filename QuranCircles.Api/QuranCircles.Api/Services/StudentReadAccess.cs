using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class StudentReadAccess(AppDbContext db)
{
    public async Task<bool> CanReadAsync(HttpContext context, int studentId)
    {
        var id = FakeAuth.GetUserId(context);
        if (!id.HasValue) return false;
        var user = await db.Users.Include(u => u.Teacher).AsNoTracking().FirstOrDefaultAsync(u => u.Id == id);
        if (user?.IsActive != true) return false;
        if (user.Role is UserRole.Admin or UserRole.Developer) return true;
        var student = await db.Students.AsNoTracking().FirstOrDefaultAsync(s => s.Id == studentId);
        if (student == null) return false;
        if (user.StudentId == studentId || ParentLinks.IsChild(user, student)) return true;
        if (user.Teacher?.IsActive != true) return false;
        var tasks = user.Teacher.TaskRole ?? "";
        var permissions=TeacherPermissions.For(user.Teacher);
        if (permissions.Contains("quality") || permissions.Contains("memorization")) return true;
        var today = CenterClock.Today;
        return await db.Circles.AnyAsync(c => c.Id == student.CircleId &&
            (c.TeacherId == user.TeacherId || c.AssistantTeacherId == user.TeacherId ||
                db.CircleDays.Any(d => d.CircleId == c.Id && d.Date == today && d.Status == "Absent" && d.SubstituteUserId == user.Id))) ||
            await db.CourseEnrollments.AnyAsync(e => e.StudentId == studentId && e.Course != null && e.Course.TeacherId == user.TeacherId);
    }
}
