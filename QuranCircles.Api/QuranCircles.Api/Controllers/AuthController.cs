using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly PasswordHasher _hasher;
    private readonly TokenService _tokenSvc;

    public AuthController(AppDbContext db, PasswordHasher hasher, TokenService tokenSvc)
    {
        _db = db;
        _hasher = hasher;
        _tokenSvc = tokenSvc;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { error = "الرجاء إدخال اسم المستخدم وكلمة المرور." });

        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Username.ToLower() == dto.Username.ToLower().Trim());

        if (user == null || !user.IsActive)
            return BadRequest(new { error = "اسم المستخدم غير موجود أو الحساب معطل." });

        bool isPasswordValid = false;
        if (!string.IsNullOrEmpty(user.PasswordHash))
        {
            try
            {
                isPasswordValid = _hasher.VerifyPassword(user.PasswordHash, dto.Password);
            }
            catch
            {
                isPasswordValid = false;
            }
        }
        else if (!string.IsNullOrEmpty(user.PlainPassword) && user.PlainPassword == dto.Password)
        {
            // Auto-upgrade legacy plain password to secure hash immediately and clear plain password
            isPasswordValid = true;
            user.PasswordHash = _hasher.HashPassword(dto.Password);
            user.PlainPassword = string.Empty;
            await _db.SaveChangesAsync();
        }

        if (!isPasswordValid)
            return BadRequest(new { error = "كلمة المرور غير صحيحة." });

        var token = _tokenSvc.GenerateToken(user);
        
        // Find reference ID based on role
        int? teacherId = user.TeacherId;
        int? studentId = user.StudentId;
        int? parentId = user.ParentId;

        if (user.Role == Entities.UserRole.Teacher && (!teacherId.HasValue || teacherId.Value == 0))
        {
            var t = await _db.Teachers.FirstOrDefaultAsync(x => x.FullName == user.FullName);
            if (t != null) teacherId = t.Id;
            else teacherId = user.Id;
        }

        return Ok(new
        {
            token,
            role = user.Role.ToString(),
            userId = user.Id,
            teacherId,
            studentId,
            parentId,
            username = user.Username,
            fullName = user.FullName
        });
    }
}

public record LoginDto(string Username, string Password);
