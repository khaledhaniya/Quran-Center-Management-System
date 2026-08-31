using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class TeacherService
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;

    public TeacherService(AppDbContext db, PasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    public async Task<List<TeacherDto>> GetAllAsync(string? search)
    {
        var q = _db.Teachers.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(t => t.FullName.Contains(search));
        return await q.Select(t => Map(t)).ToListAsync();
    }

    public async Task<TeacherDto?> GetByIdAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        return t is null ? null : Map(t);
    }

    public async Task<(TeacherDto? dto, string? error)> CreateAsync(CreateTeacherDto dto)
    {
        var err = Validate(dto.FullName, dto.Contact, dto.DateOfBirth);
        if (err is not null) return (null, err);

        var username = string.IsNullOrWhiteSpace(dto.Username) 
            ? "tch_" + Random.Shared.Next(10000, 99999) 
            : dto.Username.Trim();

        var password = string.IsNullOrWhiteSpace(dto.Password) 
            ? "123456" 
            : dto.Password.Trim();

        var userExists = await _db.Users.AnyAsync(u => u.Username.ToLower() == username.ToLower());
        if (userExists) username = "tch_" + Random.Shared.Next(100000, 999999);

        var t = new Teacher
        {
            FullName = dto.FullName.Trim(),
            Address = dto.Address?.Trim() ?? "",
            DateOfBirth = dto.DateOfBirth ?? DateOnly.FromDateTime(DateTime.Today),
            Contact = dto.Contact?.Trim() ?? "",
            RegistrationDate = DateOnly.FromDateTime(DateTime.Today),
            IsActive = true,
            IdentityNumber = dto.IdentityNumber?.Trim(),
            WhatsappNumber = dto.WhatsappNumber?.Trim(),
            SocialStatus = dto.SocialStatus?.Trim(),
            FamilyMembersCount = dto.FamilyMembersCount,
            MosqueName = dto.MosqueName?.Trim(),
            Qualification = dto.Qualification?.Trim(),
            TaskRole = dto.TaskRole?.Trim(),
            WalletNumber = dto.WalletNumber?.Trim(),
            WalletOwner = dto.WalletOwner?.Trim(),
            MemorizedAjzaa = dto.MemorizedAjzaa?.Trim(),
            StudentsCountTarget = dto.StudentsCountTarget?.Trim()
        };
        _db.Teachers.Add(t);
        await _db.SaveChangesAsync();

        var user = new User
        {
            Username = username,
            PasswordHash = _hasher.HashPassword(password),
            PlainPassword = password,
            Role = UserRole.Teacher,
            FullName = t.FullName,
            TeacherId = t.Id,
            IsActive = true
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        return (Map(t), null);
    }

    public async Task<(bool ok, string? error)> UpdateAsync(int id, UpdateTeacherDto dto)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return (false, "المعلّم غير موجود.");

        if (!string.IsNullOrWhiteSpace(dto.FullName))
        {
            var err = Validate(dto.FullName, dto.Contact, t.DateOfBirth);
            if (err is not null) return (false, err);
            t.FullName = dto.FullName.Trim();
        }

        if (dto.Address != null) t.Address = dto.Address.Trim();
        if (dto.Contact != null) t.Contact = dto.Contact.Trim();
        if (dto.DateOfBirth.HasValue) t.DateOfBirth = dto.DateOfBirth.Value;
        if (dto.IsActive.HasValue) t.IsActive = dto.IsActive.Value;

        if (dto.IdentityNumber != null) t.IdentityNumber = dto.IdentityNumber.Trim();
        if (dto.WhatsappNumber != null) t.WhatsappNumber = dto.WhatsappNumber.Trim();
        if (dto.SocialStatus != null) t.SocialStatus = dto.SocialStatus.Trim();
        if (dto.FamilyMembersCount.HasValue) t.FamilyMembersCount = dto.FamilyMembersCount.Value;
        if (dto.MosqueName != null) t.MosqueName = dto.MosqueName.Trim();
        if (dto.Qualification != null) t.Qualification = dto.Qualification.Trim();
        if (dto.TaskRole != null) t.TaskRole = dto.TaskRole.Trim();
        if (dto.WalletNumber != null) t.WalletNumber = dto.WalletNumber.Trim();
        if (dto.WalletOwner != null) t.WalletOwner = dto.WalletOwner.Trim();
        if (dto.MemorizedAjzaa != null) t.MemorizedAjzaa = dto.MemorizedAjzaa.Trim();
        if (dto.StudentsCountTarget != null) t.StudentsCountTarget = dto.StudentsCountTarget.Trim();

        var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == id);
        if (u != null) u.FullName = t.FullName;

        await _db.SaveChangesAsync();
        return (true, null);
    }

    public async Task<bool> DeactivateAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return false;
        t.IsActive = false;

        var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == id);
        if (u is not null) u.IsActive = false;

        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<(bool ok, string teacherName, string? error)> HardDeleteAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return (false, "", "المعلم غير موجود.");

        var teacherName = t.FullName;

        var circles = await _db.Circles.Where(c => c.TeacherId == id).ToListAsync();
        foreach (var c in circles)
        {
            c.TeacherId = null;
        }

        var user = await _db.Users.FirstOrDefaultAsync(u => u.TeacherId == id);
        if (user != null)
        {
            _db.Users.Remove(user);
        }

        _db.Teachers.Remove(t);
        await _db.SaveChangesAsync();
        return (true, teacherName, null);
    }

    public async Task<(bool ok, bool newStatus, string? error)> ToggleActiveAsync(int id)
    {
        var t = await _db.Teachers.FindAsync(id);
        if (t is null) return (false, false, "المعلم غير موجود.");
        t.IsActive = !t.IsActive;

        var u = await _db.Users.FirstOrDefaultAsync(x => x.TeacherId == id);
        if (u is not null) u.IsActive = t.IsActive;

        await _db.SaveChangesAsync();
        return (true, t.IsActive, null);
    }

    private static string? Validate(string fullName, string? contact, DateOnly? dob)
    {
        if (string.IsNullOrWhiteSpace(fullName)) return "اسم المعلم مطلوب.";
        return null;
    }

    private static TeacherDto Map(Teacher t) => new(
        t.Id,
        t.FullName,
        t.Address,
        t.DateOfBirth,
        t.Contact,
        t.RegistrationDate,
        t.IsActive,
        t.IdentityNumber,
        t.WhatsappNumber,
        t.SocialStatus,
        t.FamilyMembersCount,
        t.MosqueName,
        t.Qualification,
        t.TaskRole,
        t.WalletNumber,
        t.WalletOwner,
        t.MemorizedAjzaa,
        t.StudentsCountTarget
    );
}
