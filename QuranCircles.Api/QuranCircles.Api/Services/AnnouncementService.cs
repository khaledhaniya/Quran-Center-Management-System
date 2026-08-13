using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace QuranCircles.Api.Services;

public class AnnouncementService
{
    private readonly AppDbContext _db;

    public AnnouncementService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<AnnouncementDto>> GetMyAnnouncementsAsync(int userId)
    {
        var user = await _db.Users.FindAsync(userId);
        if (user == null) return new List<AnnouncementDto>();

        IQueryable<Announcement> query = _db.Announcements;

        if (user.Role == UserRole.Developer || user.Role == UserRole.Admin)
        {
            // Admins and Developers can see all announcements
        }
        else if (user.Role == UserRole.Teacher)
        {
            var teacherCircleIds = await _db.Circles
                .Where(c => c.TeacherId == user.TeacherId)
                .Select(c => c.Id)
                .ToListAsync();

            query = query.Where(a => 
                a.TargetType == AnnouncementTarget.All ||
                a.TargetType == AnnouncementTarget.AllTeachers ||
                (a.TargetType == AnnouncementTarget.Teacher && a.TargetId == user.TeacherId) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && teacherCircleIds.Contains(a.TargetId.Value))
            );
        }
        else if (user.Role == UserRole.Student)
        {
            var student = await _db.Students.FindAsync(user.StudentId);
            var circleId = student?.CircleId;

            query = query.Where(a =>
                a.TargetType == AnnouncementTarget.All ||
                (a.TargetType == AnnouncementTarget.Student && a.TargetId == user.StudentId) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId == circleId)
            );
        }
        else if (user.Role == UserRole.Parent)
        {
            var studentIds = await _db.Students
                .Where(s => s.ParentId == user.ParentId)
                .Select(s => s.Id)
                .ToListAsync();

            var parentCircleIds = await _db.Students
                .Where(s => s.ParentId == user.ParentId && s.CircleId.HasValue)
                .Select(s => s.CircleId!.Value)
                .Distinct()
                .ToListAsync();

            query = query.Where(a =>
                a.TargetType == AnnouncementTarget.All ||
                (a.TargetType == AnnouncementTarget.Parent && a.TargetId == user.ParentId) ||
                (a.TargetType == AnnouncementTarget.Student && a.TargetId.HasValue && studentIds.Contains(a.TargetId.Value)) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && parentCircleIds.Contains(a.TargetId.Value))
            );
        }
        else
        {
            return new List<AnnouncementDto>();
        }

        var list = await query.OrderByDescending(a => a.DateTimeSent).ToListAsync();

        var circleIds = list.Where(a => a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var teacherIds = list.Where(a => a.TargetType == AnnouncementTarget.Teacher && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var studentIdsForNames = list.Where(a => a.TargetType == AnnouncementTarget.Student && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var parentUserIds = list.Where(a => a.TargetType == AnnouncementTarget.Parent && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();

        var circlesMap = await _db.Circles.Where(c => circleIds.Contains(c.Id)).ToDictionaryAsync(c => c.Id, c => c.Name);
        var teachersMap = await _db.Teachers.Where(t => teacherIds.Contains(t.Id)).ToDictionaryAsync(t => t.Id, t => t.FullName);
        var studentsMap = await _db.Students.Where(s => studentIdsForNames.Contains(s.Id)).ToDictionaryAsync(s => s.Id, s => s.FullName);
        var parentsMap = await _db.Users.Where(u => u.Role == UserRole.Parent && u.ParentId.HasValue && parentUserIds.Contains(u.ParentId.Value)).ToDictionaryAsync(u => u.ParentId!.Value, u => u.FullName);

        return list.Select(a => {
            string targetName = "الجميع";
            if (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && circlesMap.TryGetValue(a.TargetId.Value, out var cName))
                targetName = $"حلقة: {cName}";
            else if (a.TargetType == AnnouncementTarget.Teacher && a.TargetId.HasValue && teachersMap.TryGetValue(a.TargetId.Value, out var tName))
                targetName = $"المعلم: {tName}";
            else if (a.TargetType == AnnouncementTarget.Student && a.TargetId.HasValue && studentsMap.TryGetValue(a.TargetId.Value, out var sName))
                targetName = $"الطالب: {sName}";
            else if (a.TargetType == AnnouncementTarget.Parent && a.TargetId.HasValue && parentsMap.TryGetValue(a.TargetId.Value, out var pName))
                targetName = $"ولي الأمر: {pName}";
            else if (a.TargetType == AnnouncementTarget.AllTeachers)
                targetName = "كل المعلمين";
            else if (a.TargetType == AnnouncementTarget.Admin)
                targetName = "مدير المركز";

            return new AnnouncementDto(
                a.Id,
                a.Title,
                a.Content,
                a.DateTimeSent,
                a.TargetType,
                a.TargetId,
                targetName,
                a.SenderName
            );
        }).ToList();
    }

    public async Task<(AnnouncementDto? dto, string? error)> CreateAnnouncementAsync(CreateAnnouncementDto dto, string senderName)
    {
        if (string.IsNullOrWhiteSpace(dto.Title)) return (null, "عنوان التعميم مطلوب.");
        if (string.IsNullOrWhiteSpace(dto.Content)) return (null, "محتوى التعميم مطلوب.");

        if (dto.TargetType != AnnouncementTarget.All && 
            dto.TargetType != AnnouncementTarget.AllTeachers && 
            dto.TargetType != AnnouncementTarget.Admin && 
            !dto.TargetId.HasValue)
        {
            return (null, "يجب تحديد المستهدف لهذا النوع من التعاميم.");
        }

        if (dto.TargetType == AnnouncementTarget.Circle)
        {
            var exists = await _db.Circles.AnyAsync(c => c.Id == dto.TargetId.Value);
            if (!exists) return (null, "الحلقة المحددة غير موجودة.");
        }
        else if (dto.TargetType == AnnouncementTarget.Teacher)
        {
            var exists = await _db.Teachers.AnyAsync(t => t.Id == dto.TargetId.Value);
            if (!exists) return (null, "المعلم المحدد غير موجود.");
        }
        else if (dto.TargetType == AnnouncementTarget.Student)
        {
            var exists = await _db.Students.AnyAsync(s => s.Id == dto.TargetId.Value);
            if (!exists) return (null, "الطالب المحدد غير موجود.");
        }
        else if (dto.TargetType == AnnouncementTarget.Parent)
        {
            var exists = await _db.Users.AnyAsync(u => u.Role == UserRole.Parent && u.ParentId == dto.TargetId.Value);
            if (!exists) return (null, "ولي الأمر المحدد غير موجود.");
        }

        var announcement = new Announcement
        {
            Title = dto.Title.Trim(),
            Content = dto.Content.Trim(),
            DateTimeSent = DateTime.UtcNow,
            TargetType = dto.TargetType,
            TargetId = (dto.TargetType == AnnouncementTarget.All || 
                        dto.TargetType == AnnouncementTarget.AllTeachers || 
                        dto.TargetType == AnnouncementTarget.Admin) ? null : dto.TargetId,
            SenderName = senderName
        };

        _db.Announcements.Add(announcement);
        await _db.SaveChangesAsync();

        string targetName = "الجميع";
        if (announcement.TargetType == AnnouncementTarget.Circle && announcement.TargetId.HasValue)
        {
            var c = await _db.Circles.FindAsync(announcement.TargetId.Value);
            if (c != null) targetName = $"حلقة: {c.Name}";
        }
        else if (announcement.TargetType == AnnouncementTarget.Teacher && announcement.TargetId.HasValue)
        {
            var t = await _db.Teachers.FindAsync(announcement.TargetId.Value);
            if (t != null) targetName = $"المعلم: {t.FullName}";
        }
        else if (announcement.TargetType == AnnouncementTarget.Student && announcement.TargetId.HasValue)
        {
            var s = await _db.Students.FindAsync(announcement.TargetId.Value);
            if (s != null) targetName = $"الطالب: {s.FullName}";
        }
        else if (announcement.TargetType == AnnouncementTarget.Parent && announcement.TargetId.HasValue)
        {
            var p = await _db.Users.FirstOrDefaultAsync(u => u.Role == UserRole.Parent && u.ParentId == announcement.TargetId.Value);
            if (p != null) targetName = $"ولي الأمر: {p.FullName}";
        }
        else if (announcement.TargetType == AnnouncementTarget.AllTeachers)
        {
            targetName = "كل المعلمين";
        }
        else if (announcement.TargetType == AnnouncementTarget.Admin)
        {
            targetName = "مدير المركز";
        }

        var resDto = new AnnouncementDto(
            announcement.Id,
            announcement.Title,
            announcement.Content,
            announcement.DateTimeSent,
            announcement.TargetType,
            announcement.TargetId,
            targetName,
            announcement.SenderName
        );

        return (resDto, null);
    }
}
