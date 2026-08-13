using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CompetitionsController : ControllerBase
{
    private readonly AppDbContext _db;

    public CompetitionsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("leaderboard")]
    public async Task<IActionResult> GetLeaderboard()
    {
        var circles = await _db.Circles
            .Include(c => c.Teacher)
            .Include(c => c.Students)
            .Where(c => c.IsActive)
            .ToListAsync();

        var leaderboard = new List<CircleLeaderboardDto>();

        foreach (var circle in circles)
        {
            var studentIds = circle.Students.Select(s => s.Id).ToList();

            // 1. Quran Memorization Score (Sum of verses recited in all sessions)
            double quranScore = 0;
            if (studentIds.Any())
            {
                var sessions = await _db.Sessions
                    .Where(s => studentIds.Contains(s.StudentId))
                    .ToListAsync();
                quranScore = sessions.Sum(s => Math.Max(0, s.ToVerse - s.FromVerse + 1));
            }

            // 2. Hadith Memorization Score (Sum of points in Hadith sessions)
            double hadithScore = 0;
            if (studentIds.Any())
            {
                hadithScore = await _db.HadithSessions
                    .Where(hs => studentIds.Contains(hs.StudentId))
                    .SumAsync(hs => hs.Points);
            }

            // 3. Course Performance Score (Average grade of students in courses)
            double courseScore = 0;
            if (studentIds.Any())
            {
                var grades = await _db.CourseEnrollments
                    .Where(ce => studentIds.Contains(ce.StudentId) && ce.Grade.HasValue)
                    .Select(ce => ce.Grade!.Value)
                    .ToListAsync();

                courseScore = grades.Any() ? grades.Average() : 0;
            }

            // 4. Commitment/Attendance Score (Attendance percentage)
            double attendanceScore = 0;
            var attendanceRecords = await _db.Attendances
                .Where(a => a.CircleId == circle.Id)
                .ToListAsync();

            if (attendanceRecords.Any())
            {
                var present = attendanceRecords.Count(r => r.Status == AttendanceStatus.Present);
                var late = attendanceRecords.Count(r => r.Status == AttendanceStatus.Late);
                var total = attendanceRecords.Count;
                attendanceScore = ((double)(present + late * 0.5) / total) * 100;
            }

            // Normalize or aggregate into an overall score (e.g. average of scores)
            // To make overall score balanced, we can sum them or average their percentiles,
            // let's do a simple weighted score: (Quran/100) + (Hadith/10) + Course + Attendance
            double overallScore = Math.Round((quranScore * 0.1) + (hadithScore * 0.5) + (courseScore * 0.5) + (attendanceScore * 0.8), 1);

            leaderboard.Add(new CircleLeaderboardDto
            {
                CircleId = circle.Id,
                CircleName = circle.Name,
                TeacherName = circle.Teacher != null ? circle.Teacher.FullName : "بدون معلم",
                StudentCount = circle.Students.Count,
                QuranScore = quranScore,
                HadithScore = hadithScore,
                CourseScore = Math.Round(courseScore, 1),
                AttendanceScore = Math.Round(attendanceScore, 1),
                OverallScore = overallScore
            });
        }

        // Rank lists
        var ranked = leaderboard
            .OrderByDescending(x => x.OverallScore)
            .ToList();

        return Ok(ranked);
    }

    [HttpGet("hadith")]
    public async Task<IActionResult> GetHadithSessions()
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        var query = _db.HadithSessions
            .Include(hs => hs.Student)
            .ThenInclude(s => s!.Circle)
            .AsQueryable();

        // RBAC filtering
        if (currentUser.Role == UserRole.Teacher)
        {
            var teacherCircleIds = await _db.Circles
                .Where(c => c.TeacherId == currentUser.TeacherId)
                .Select(c => c.Id)
                .ToListAsync();

            query = query.Where(hs => hs.Student!.CircleId.HasValue && teacherCircleIds.Contains(hs.Student.CircleId.Value));
        }
        else if (currentUser.Role == UserRole.Student)
        {
            query = query.Where(hs => hs.StudentId == currentUser.StudentId);
        }
        else if (currentUser.Role == UserRole.Parent)
        {
            var studentIds = await _db.Students
                .Where(s => s.ParentId == currentUser.ParentId)
                .Select(s => s.Id)
                .ToListAsync();
            query = query.Where(hs => studentIds.Contains(hs.StudentId));
        }

        var list = await query
            .OrderByDescending(hs => hs.SessionDate)
            .Select(hs => new
            {
                hs.Id,
                hs.StudentId,
                StudentName = hs.Student != null ? hs.Student.FullName : "",
                HalaqahName = (hs.Student != null && hs.Student.Circle != null) ? hs.Student.Circle.Name : "بدون حلقة",
                hs.HadithBook,
                hs.HadithNumber,
                hs.Points,
                hs.SessionDate,
                hs.Notes
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpPost("hadith")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> RecordHadith([FromBody] CreateHadithSessionDto dto)
    {
        var student = await _db.Students
            .Include(s => s.Circle)
            .FirstOrDefaultAsync(s => s.Id == dto.StudentId);

        if (student == null) return NotFound(new { Message = "الطالب غير موجود." });

        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        if (currentUser == null) return Unauthorized();

        // RBAC validation: If teacher, verify the student is in their circle
        if (currentUser.Role == UserRole.Teacher)
        {
            if (student.Circle == null || student.Circle.TeacherId != currentUser.TeacherId)
            {
                return Forbid();
            }
        }

        var session = new HadithSession
        {
            StudentId = dto.StudentId,
            HadithBook = dto.HadithBook,
            HadithNumber = dto.HadithNumber,
            Points = dto.Points > 0 ? dto.Points : 10,
            SessionDate = DateOnly.FromDateTime(DateTime.Today),
            Notes = dto.Notes
        };

        _db.HadithSessions.Add(session);
        await _db.SaveChangesAsync();

        // Audit Log
        _db.AuditLogs.Add(new AuditLog
        {
            Username = currentUser.Username,
            Action = "RecordHadithSession",
            Details = $"تسجيل تسميع الحديث {dto.HadithNumber} من {dto.HadithBook} للطالب {student.FullName} بنقاط {session.Points}",
            Timestamp = DateTime.UtcNow,
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "::1"
        });
        await _db.SaveChangesAsync();

        return Ok(new { Message = "تم تسجيل تسميع الحديث بنجاح.", PointsAwarded = session.Points });
    }
}

public class CircleLeaderboardDto
{
    public int CircleId { get; set; }
    public string CircleName { get; set; } = string.Empty;
    public string TeacherName { get; set; } = string.Empty;
    public int StudentCount { get; set; }
    public double QuranScore { get; set; }
    public double HadithScore { get; set; }
    public double CourseScore { get; set; }
    public double AttendanceScore { get; set; }
    public double OverallScore { get; set; }
}

public record CreateHadithSessionDto(int StudentId, string HadithBook, int HadithNumber, int Points, string? Notes);
