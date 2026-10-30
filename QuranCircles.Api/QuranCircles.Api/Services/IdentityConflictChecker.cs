using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

/// <summary>Prevents a personal identity or identity-like login from being assigned to another person.</summary>
public sealed class IdentityConflictChecker(AppDbContext db)
{
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToLowerInvariant();

    public async Task<string?> CheckIdentityAsync(string? identity, int? studentId = null,
        int? teacherId = null, bool allowExistingParentAccount = false)
    {
        var value = Clean(identity);
        if (value is null) return null;
        if (await db.Students.AnyAsync(s => (!studentId.HasValue || s.Id != studentId.Value) && s.StudentIdentityNumber != null &&
            s.StudentIdentityNumber.Trim().ToLower() == value))
            return "رقم الهوية مسجل لطالب آخر.";
        if (await db.Teachers.AnyAsync(t => (!teacherId.HasValue || t.Id != teacherId.Value) && t.IdentityNumber != null &&
            t.IdentityNumber.Trim().ToLower() == value))
            return "رقم الهوية مسجل لمعلم آخر.";
        if (await db.Users.AnyAsync(u => u.Username.Trim().ToLower() == value &&
            (!studentId.HasValue || u.StudentId != studentId.Value) &&
            (!teacherId.HasValue || u.TeacherId != teacherId.Value) &&
            !(allowExistingParentAccount && u.Role == UserRole.Parent && u.StudentId == null && u.TeacherId == null)))
            return "رقم الهوية مرتبط بحساب آخر؛ لا يمكن نقل الحساب أو تغيير كلمة مروره تلقائياً.";
        return null;
    }

    public async Task<string?> CheckUsernameAsync(string? username, int? studentId = null,
        int? teacherId = null, int? userId = null, bool allowExistingParentAccount = false)
    {
        var value = Clean(username);
        if (value is null) return null;
        if (await db.Users.AnyAsync(u => (!userId.HasValue || u.Id != userId.Value) && u.Username.Trim().ToLower() == value &&
            !(allowExistingParentAccount && u.Role == UserRole.Parent && u.StudentId == null && u.TeacherId == null)))
            return "اسم المستخدم محجوز لحساب آخر.";
        if (await db.Students.AnyAsync(s => (!studentId.HasValue || s.Id != studentId.Value) && s.StudentIdentityNumber != null &&
            s.StudentIdentityNumber.Trim().ToLower() == value))
            return "اسم المستخدم يطابق رقم هوية طالب آخر.";
        if (await db.Teachers.AnyAsync(t => (!teacherId.HasValue || t.Id != teacherId.Value) && t.IdentityNumber != null &&
            t.IdentityNumber.Trim().ToLower() == value))
            return "اسم المستخدم يطابق رقم هوية معلم آخر.";
        return null;
    }
}
