using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TalentsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;

    public TalentsController(AppDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.Parent, UserRole.Student, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetAll([FromQuery] int? studentId, [FromQuery] string? talentType)
    {
        var query = _db.TalentRecords
            .Include(t => t.Student)
                .ThenInclude(s => s!.Circle)
            .Include(t => t.SupervisorTeacher)
            .AsNoTracking()
            .AsQueryable();

        if (studentId.HasValue && studentId.Value > 0)
        {
            query = query.Where(t => t.StudentId == studentId.Value);
        }

        if (!string.IsNullOrWhiteSpace(talentType))
        {
            query = query.Where(t => t.TalentType.Contains(talentType));
        }

        var list = await query
            .OrderByDescending(t => t.EventDate)
            .ThenByDescending(t => t.Id)
            .Select(t => new
            {
                t.Id,
                t.StudentId,
                StudentName = t.Student != null ? t.Student.FullName : "طالب غير معروف",
                CircleId = t.Student != null ? t.Student.CircleId : null,
                CircleName = t.Student != null && t.Student.Circle != null ? t.Student.Circle.Name : "غير مسند",
                t.TalentType,
                t.Title,
                t.PreparationMethod,
                t.SpeechContent,
                t.Occasion,
                EventDate = t.EventDate.ToString("yyyy-MM-dd"),
                t.SupervisorTeacherId,
                SupervisorTeacherName = t.SupervisorTeacher != null ? t.SupervisorTeacher.FullName : "غير معين",
                t.MediaUrl,
                t.MediaType,
                t.EvaluationScore,
                t.PerformanceNotes,
                t.CreatedAt
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpGet("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher, UserRole.Parent, UserRole.Student, UserRole.ExamSupervisor)]
    public async Task<IActionResult> GetById(int id)
    {
        var t = await _db.TalentRecords
            .Include(x => x.Student)
                .ThenInclude(s => s!.Circle)
            .Include(x => x.SupervisorTeacher)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (t == null) return NotFound(new { error = "سجل الموهبة غير موجود." });

        return Ok(new
        {
            t.Id,
            t.StudentId,
            StudentName = t.Student?.FullName,
            CircleName = t.Student?.Circle?.Name,
            t.TalentType,
            t.Title,
            t.PreparationMethod,
            t.SpeechContent,
            t.Occasion,
            EventDate = t.EventDate.ToString("yyyy-MM-dd"),
            t.SupervisorTeacherId,
            SupervisorTeacherName = t.SupervisorTeacher?.FullName,
            t.MediaUrl,
            t.MediaType,
            t.EvaluationScore,
            t.PerformanceNotes,
            t.CreatedAt
        });
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> Create([FromBody] CreateTalentRecordDto dto)
    {
        if (dto.StudentId <= 0) return BadRequest(new { error = "يرجى تحديد الطالب الموهوب." });
        if (string.IsNullOrWhiteSpace(dto.TalentType)) return BadRequest(new { error = "يرجى تحديد مسار الموهبة." });
        if (string.IsNullOrWhiteSpace(dto.Title)) return BadRequest(new { error = "يرجى إدخال عنوان وموضوع المشاركة أو الخطبة." });

        var student = await _db.Students.FindAsync(dto.StudentId);
        if (student == null) return NotFound(new { error = "الطالب غير موجود." });

        DateOnly evDate = DateOnly.FromDateTime(DateTime.Today);
        if (!string.IsNullOrWhiteSpace(dto.EventDate) && DateOnly.TryParse(dto.EventDate, out var parsedDate))
        {
            evDate = parsedDate;
        }

        var record = new TalentRecord
        {
            StudentId = dto.StudentId,
            TalentType = dto.TalentType.Trim(),
            Title = dto.Title.Trim(),
            PreparationMethod = dto.PreparationMethod?.Trim(),
            SpeechContent = dto.SpeechContent?.Trim(),
            Occasion = dto.Occasion?.Trim(),
            EventDate = evDate,
            SupervisorTeacherId = dto.SupervisorTeacherId > 0 ? dto.SupervisorTeacherId : null,
            MediaUrl = dto.MediaUrl?.Trim(),
            MediaType = string.IsNullOrWhiteSpace(dto.MediaType) ? "video" : dto.MediaType.Trim(),
            EvaluationScore = dto.EvaluationScore?.Trim(),
            PerformanceNotes = dto.PerformanceNotes?.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        _db.TalentRecords.Add(record);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "AddTalentRecord", 
            $"إضافة مشاركة موهبة ({record.TalentType}) للطالب {student.FullName}: {record.Title}");

        return CreatedAtAction(nameof(GetById), new { id = record.Id }, new { record.Id, Message = "تم تسجيل وتوثيق الموهبة بنجاح!" });
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> Update(int id, [FromBody] CreateTalentRecordDto dto)
    {
        var record = await _db.TalentRecords.FindAsync(id);
        if (record == null) return NotFound(new { error = "سجل الموهبة غير موجود." });

        if (dto.StudentId > 0) record.StudentId = dto.StudentId;
        if (!string.IsNullOrWhiteSpace(dto.TalentType)) record.TalentType = dto.TalentType.Trim();
        if (!string.IsNullOrWhiteSpace(dto.Title)) record.Title = dto.Title.Trim();

        record.PreparationMethod = dto.PreparationMethod?.Trim();
        record.SpeechContent = dto.SpeechContent?.Trim();
        record.Occasion = dto.Occasion?.Trim();
        
        if (!string.IsNullOrWhiteSpace(dto.EventDate) && DateOnly.TryParse(dto.EventDate, out var parsedDate))
        {
            record.EventDate = parsedDate;
        }

        record.SupervisorTeacherId = dto.SupervisorTeacherId > 0 ? dto.SupervisorTeacherId : null;
        record.MediaUrl = dto.MediaUrl?.Trim();
        if (!string.IsNullOrWhiteSpace(dto.MediaType)) record.MediaType = dto.MediaType.Trim();
        record.EvaluationScore = dto.EvaluationScore?.Trim();
        record.PerformanceNotes = dto.PerformanceNotes?.Trim();

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateTalentRecord", 
            $"تحديث سجل الموهبة ID #{id} ({record.Title})");

        return Ok(new { Message = "تم تحديث سجل الموهبة بنجاح." });
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> Delete(int id)
    {
        var record = await _db.TalentRecords.FindAsync(id);
        if (record == null) return NotFound(new { error = "السجل غير موجود." });

        _db.TalentRecords.Remove(record);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "DeleteTalentRecord", 
            $"حذف مشاركة الموهبة ID #{id} ({record.Title})");

        return Ok(new { Message = "تم حذف سجل الموهبة بنجاح." });
    }

    [HttpPost("upload")]
    [RequireRole(UserRole.Admin, UserRole.Developer, UserRole.Teacher)]
    public async Task<IActionResult> UploadMedia([FromForm] IFormFile? file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { error = "لم يتم اختيار أي ملف للرفع." });
        }

        // Validate file extensions
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedVideoExts = new[] { ".mp4", ".webm", ".mkv", ".mov", ".avi" };
        var allowedAudioExts = new[] { ".mp3", ".wav", ".m4a", ".ogg", ".aac" };
        var allowedImageExts = new[] { ".jpg", ".jpeg", ".png", ".webp", ".gif" };

        string mediaType = "video";
        if (allowedAudioExts.Contains(ext)) mediaType = "audio";
        else if (allowedImageExts.Contains(ext)) mediaType = "image";
        else if (!allowedVideoExts.Contains(ext))
        {
            return BadRequest(new { error = "نوع الملف غير مدعوم. يرجى رفع ملف فيديو (mp4/webm) أو صوت (mp3/wav) أو صورة." });
        }

        // Limit size: 100MB for media
        if (file.Length > 100 * 1024 * 1024)
        {
            return BadRequest(new { error = "حجم الملف كبير جداً. الحد الأقصى هو 100 ميجابايت." });
        }

        var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
        var uploadsDir = Path.Combine(webRoot, "uploads", "talents");
        Directory.CreateDirectory(uploadsDir);

        var safeFileName = $"talent_{DateTime.UtcNow.Ticks}_{Guid.NewGuid().ToString("N")[..8]}{ext}";
        var filePath = Path.Combine(uploadsDir, safeFileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var url = $"/uploads/talents/{safeFileName}";
        return Ok(new
        {
            Url = url,
            MediaType = mediaType,
            FileName = file.FileName,
            Size = file.Length,
            Message = "تم رفع الملف بنجاح!"
        });
    }
}

public record CreateTalentRecordDto(
    int StudentId,
    string TalentType,
    string Title,
    string? PreparationMethod,
    string? SpeechContent,
    string? Occasion,
    string? EventDate,
    int? SupervisorTeacherId,
    string? MediaUrl,
    string? MediaType,
    string? EvaluationScore,
    string? PerformanceNotes
);
