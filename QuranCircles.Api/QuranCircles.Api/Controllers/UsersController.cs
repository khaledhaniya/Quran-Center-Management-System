using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/users")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;

    public UsersController(AppDbContext db, PasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    [HttpGet]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> GetAll()
    {
        var users = await _db.Users
            .Select(u => new {
                u.Id,
                u.Username,
                u.FullName,
                Role = u.Role.ToString(),
                u.IsActive,
                u.TeacherId,
                u.StudentId,
                u.ParentId,
                PlainPassword = !string.IsNullOrEmpty(u.PlainPassword) 
                    ? u.PlainPassword 
                    : (u.Username == "dev" ? "dev123" : (u.Username == "admin" ? "admin123" : (u.Username == "wael" ? "wael123" : "123456")))
            })
            .ToListAsync();
        return Ok(users);
    }

    [HttpPost]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> Create([FromBody] CreateUserDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { error = "اسم المستخدم وكلمة المرور مطلوبان." });

        var taken = await _db.Users.AnyAsync(u => u.Username.ToLower() == dto.Username.ToLower().Trim());
        if (taken) return BadRequest(new { error = "اسم المستخدم محجوز بالفعل." });

        if (!Enum.TryParse<UserRole>(dto.Role, out var roleVal))
            return BadRequest(new { error = "نوع الحساب غير صالح." });

        var user = new User
        {
            Username = dto.Username.Trim(),
            FullName = dto.FullName.Trim(),
            Role = roleVal,
            TeacherId = dto.TeacherId,
            IsActive = true,
            PasswordHash = _hasher.HashPassword(dto.Password.Trim()),
            PlainPassword = dto.Password.Trim()
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "CreateUser", $"إنشاء حساب جديد للمستخدم: {user.Username} ({user.FullName}) - الصفة: {user.Role}");

        return CreatedAtAction(nameof(GetAll), new { id = user.Id }, new {
            user.Id,
            user.Username,
            user.FullName,
            Role = user.Role.ToString(),
            user.TeacherId,
            user.IsActive,
            user.PlainPassword
        });
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUserDto dto)
    {
        var user = await _db.Users.FindAsync(id);
        if (user == null) return NotFound(new { error = "المستخدم غير موجود." });

        if (string.IsNullOrWhiteSpace(dto.Username)) 
            return BadRequest(new { error = "اسم المستخدم مطلوب." });

        var taken = await _db.Users.AnyAsync(u => u.Id != id && u.Username.ToLower() == dto.Username.ToLower().Trim());
        if (taken) return BadRequest(new { error = "اسم المستخدم محجوز بالفعل." });

        user.Username = dto.Username.Trim();
        user.FullName = dto.FullName.Trim();
        user.TeacherId = dto.TeacherId;
        
        if (Enum.TryParse<UserRole>(dto.Role, out var roleVal))
        {
            user.Role = roleVal;
        }

        if (!string.IsNullOrWhiteSpace(dto.Password))
        {
            user.PasswordHash = _hasher.HashPassword(dto.Password.Trim());
            user.PlainPassword = dto.Password.Trim();
        }

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateUser", $"تعديل حساب المستخدم: {user.Username} ({user.FullName}) - الصفة: {user.Role}");

        return Ok(new { 
            message = "تم تحديث الحساب وكلمة المرور بنجاح.",
            user.Id,
            user.Username,
            user.FullName,
            user.PlainPassword
        });
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> Delete(int id)
    {
        var user = await _db.Users.FindAsync(id);
        if (user == null) return NotFound(new { error = "المستخدم غير موجود." });

        var uName = user.Username;
        var fName = user.FullName;
        var uRole = user.Role;

        _db.Users.Remove(user);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "DeleteUser", $"حذف الحساب نهائياً للمستخدم: {uName} ({fName}) - الصفة: {uRole}");

        return NoContent();
    }

    [HttpGet("supervisors")]
    [RequireRole(UserRole.Developer, UserRole.Admin)]
    public async Task<IActionResult> GetSupervisors()
    {
        var supervisors = await _db.Users
            .Where(u => u.Role == UserRole.ExamSupervisor && u.IsActive)
            .Select(u => new { u.Id, u.FullName, u.Username })
            .ToListAsync();
        return Ok(supervisors);
    }
}

public record CreateUserDto(
    string Username,
    string FullName,
    string Role,
    string Password,
    int? TeacherId = null
);

public record UpdateUserDto(
    string Username,
    string FullName,
    string Role,
    string? Password = null,
    int? TeacherId = null
);
