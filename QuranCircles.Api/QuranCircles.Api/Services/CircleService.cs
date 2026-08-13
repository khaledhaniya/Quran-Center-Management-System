using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class CircleService
{
    private readonly AppDbContext _db;
    public CircleService(AppDbContext db) => _db = db;

    public async Task<List<CircleDto>> GetAllAsync()
    {
        var circles = await _db.Circles
            .Include(c => c.Teacher)
            .Include(c => c.Students)
            .ToListAsync();
        return circles.Select(Map).ToList();
    }

    public async Task<List<CircleDto>> GetAllForTeacherAsync(int teacherId)
    {
        var circles = await _db.Circles
            .Include(c => c.Teacher)
            .Include(c => c.Students)
            .Where(c => c.TeacherId == teacherId)
            .ToListAsync();
        return circles.Select(Map).ToList();
    }

    public async Task<CircleDto?> GetByIdAsync(int id)
    {
        var c = await _db.Circles
            .Include(x => x.Teacher)
            .Include(x => x.Students)
            .FirstOrDefaultAsync(x => x.Id == id);
        return c is null ? null : Map(c);
    }

    public async Task<(CircleDto? dto, string? error)> CreateAsync(CreateCircleDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Name))
            return (null, "اسم الحلقة مطلوب.");

        if (dto.TeacherId is not null)
        {
            var t = await _db.Teachers.FindAsync(dto.TeacherId);
            if (t is null) return (null, "المعلّم المحدد غير موجود.");
            if (!t.IsActive) return (null, "لا يمكن إسناد معلّم غير مفعّل.");
        }

        var c = new Circle
        {
            Name = dto.Name.Trim(),
            Timing = dto.Timing,
            TeacherId = dto.TeacherId,
            IsActive = true
        };
        _db.Circles.Add(c);
        await _db.SaveChangesAsync();

        await _db.Entry(c).Reference(x => x.Teacher).LoadAsync();
        await _db.Entry(c).Collection(x => x.Students).LoadAsync();
        return (Map(c), null);
    }

    public async Task<(bool ok, string? error)> UpdateAsync(int id, UpdateCircleDto dto)
    {
        var c = await _db.Circles.FindAsync(id);
        if (c is null) return (false, "الحلقة غير موجودة.");
        if (string.IsNullOrWhiteSpace(dto.Name)) return (false, "اسم الحلقة مطلوب.");

        if (dto.TeacherId is not null)
        {
            var t = await _db.Teachers.FindAsync(dto.TeacherId);
            if (t is null) return (false, "المعلّم المحدد غير موجود.");
            if (!t.IsActive) return (false, "لا يمكن إسناد معلّم غير مفعّل.");
        }

        c.Name = dto.Name.Trim();
        c.Timing = dto.Timing;
        c.TeacherId = dto.TeacherId;
        c.IsActive = dto.IsActive;
        await _db.SaveChangesAsync();
        return (true, null);
    }

    public async Task<bool> DeactivateAsync(int id)
    {
        var c = await _db.Circles.FindAsync(id);
        if (c is null) return false;
        c.IsActive = false;
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<(bool ok, bool newStatus, string? error)> ToggleActiveAsync(int id)
    {
        var c = await _db.Circles.FindAsync(id);
        if (c is null) return (false, false, "الحلقة غير موجودة.");

        c.IsActive = !c.IsActive;
        await _db.SaveChangesAsync();
        return (true, c.IsActive, null);
    }

    public async Task<(bool ok, string circleName, string? error)> HardDeleteAsync(int id)
    {
        var c = await _db.Circles.Include(x => x.Students).FirstOrDefaultAsync(x => x.Id == id);
        if (c is null) return (false, "", "الحلقة غير موجودة.");

        var circleName = c.Name;
        foreach (var s in c.Students)
        {
            s.CircleId = null;
        }

        _db.Circles.Remove(c);
        await _db.SaveChangesAsync();
        return (true, circleName, null);
    }

    public async Task<(bool ok, string? error)> AddStudentAsync(int circleId, int studentId)
    {
        var c = await _db.Circles.FindAsync(circleId);
        if (c is null) return (false, "الحلقة غير موجودة.");

        var s = await _db.Students.FindAsync(studentId);
        if (s is null) return (false, "الطالب غير موجود.");
        if (!s.IsActive) return (false, "لا يمكن إضافة طالب غير مفعّل.");

        s.CircleId = circleId;
        await _db.SaveChangesAsync();
        return (true, null);
    }

    public async Task<(bool ok, string? error)> RemoveStudentAsync(int circleId, int studentId)
    {
        var s = await _db.Students.FirstOrDefaultAsync(x => x.Id == studentId && x.CircleId == circleId);
        if (s is null) return (false, "الطالب غير موجود في هذه الحلقة.");

        s.CircleId = null;
        await _db.SaveChangesAsync();
        return (true, null);
    }

    private static CircleDto Map(Circle c) => new(
        c.Id, c.Name, c.Timing, c.IsActive,
        c.TeacherId, c.Teacher?.FullName,
        c.Students.Count,
        c.Students.Select(s => new StudentBriefDto(s.Id, s.FullName)).ToList()
    );
}
