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
            int tId = user.TeacherId ?? 0;
            if (tId == 0 || !await _db.Teachers.AnyAsync(t => t.Id == tId && t.IsActive)) tId = -1;

            var teacherCircleIds = await _db.Circles
                .Where(c => c.TeacherId == tId || c.AssistantTeacherId == tId)
                .Select(c => c.Id)
                .ToListAsync();
            var teacherCourseIds = await _db.Courses.Where(c => c.TeacherId == tId).Select(c => c.Id).ToListAsync();
            var circleStudentIds = await _db.Students.Where(s => s.CircleId.HasValue && teacherCircleIds.Contains(s.CircleId.Value)).Select(s => s.Id).ToListAsync();
            var courseStudentIds = await _db.CourseEnrollments.Where(e => teacherCourseIds.Contains(e.CourseId)).Select(e => e.StudentId).Distinct().ToListAsync();
            var childIds = await ParentLinks.ChildrenQuery(_db, user).Select(s => s.Id).ToListAsync();
            var childCircleIds = await _db.Students.Where(s => childIds.Contains(s.Id) && s.CircleId.HasValue).Select(s => s.CircleId!.Value).Distinct().ToListAsync();
            var parentId = user.ParentId ?? user.Id;

            query = query.Where(a =>
                (a.SenderName == user.FullName && a.TargetType != AnnouncementTarget.StudentCircle) ||
                a.TargetType == AnnouncementTarget.All ||
                a.TargetType == AnnouncementTarget.AllTeachers ||
                (a.TargetType == AnnouncementTarget.Teacher && (a.TargetId == tId || a.TargetId == user.Id)) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && teacherCircleIds.Contains(a.TargetId.Value)) ||
                (a.TargetType == AnnouncementTarget.Course && a.TargetId.HasValue && teacherCourseIds.Contains(a.TargetId.Value)) ||
                (a.TargetType == AnnouncementTarget.StudentCircle && a.TargetId.HasValue && (circleStudentIds.Contains(a.TargetId.Value) || courseStudentIds.Contains(a.TargetId.Value))) ||
                (a.TargetType == AnnouncementTarget.Student && a.TargetId.HasValue && childIds.Contains(a.TargetId.Value)) ||
                (a.TargetType == AnnouncementTarget.Parent && (a.TargetId == parentId || a.TargetId == user.Id)) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && childCircleIds.Contains(a.TargetId.Value))
            );
        }
        else if (user.Role == UserRole.Student)
        {
            var student = await _db.Students.FindAsync(user.StudentId);
            var circleId = student?.CircleId;
            var circleStudentIds = circleId.HasValue ? await _db.Students.Where(s => s.CircleId == circleId).Select(s => s.Id).ToListAsync() : new List<int>();
            var courseIds = await _db.CourseEnrollments.Where(e => e.StudentId == user.StudentId).Select(e => e.CourseId).ToListAsync();

            query = query.Where(a =>
                (a.SenderName == user.FullName && a.TargetType != AnnouncementTarget.StudentCircle) ||
                a.TargetType == AnnouncementTarget.All ||
                (a.TargetType == AnnouncementTarget.Student && a.TargetId == user.StudentId) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId == circleId) ||
                (a.TargetType == AnnouncementTarget.StudentCircle && a.TargetId.HasValue && circleStudentIds.Contains(a.TargetId.Value)) ||
                (a.TargetType == AnnouncementTarget.Course && a.TargetId.HasValue && courseIds.Contains(a.TargetId.Value))
            );
        }
        else if (user.Role == UserRole.Parent)
        {
            int pId = user.ParentId ?? user.Id;

            var studentIds = await ParentLinks.ChildrenQuery(_db, user).Select(s => s.Id).ToListAsync();

            var parentCircleIds = await _db.Students
                .Where(s => studentIds.Contains(s.Id) && s.CircleId.HasValue)
                .Select(s => s.CircleId!.Value)
                .Distinct()
                .ToListAsync();
            var teacherId = user.TeacherId ?? 0;
            var activeTeacher = teacherId > 0 && await _db.Teachers.AnyAsync(t => t.Id == teacherId && t.IsActive);
            var assignedCircleIds = activeTeacher ? await _db.Circles.Where(c => c.TeacherId == teacherId || c.AssistantTeacherId == teacherId).Select(c => c.Id).ToListAsync() : new List<int>();
            var assignedCourseIds = activeTeacher ? await _db.Courses.Where(c => c.TeacherId == teacherId).Select(c => c.Id).ToListAsync() : new List<int>();
            var assignedStudentIds = activeTeacher ? await _db.Students.Where(s => s.CircleId.HasValue && assignedCircleIds.Contains(s.CircleId.Value)).Select(s => s.Id).ToListAsync() : new List<int>();
            var courseStudentIds = activeTeacher ? await _db.CourseEnrollments.Where(e => assignedCourseIds.Contains(e.CourseId)).Select(e => e.StudentId).Distinct().ToListAsync() : new List<int>();

            query = query.Where(a =>
                (a.SenderName == user.FullName && a.TargetType != AnnouncementTarget.StudentCircle) ||
                a.TargetType == AnnouncementTarget.All ||
                (a.TargetType == AnnouncementTarget.Parent && (a.TargetId == pId || a.TargetId == user.Id)) ||
                (a.TargetType == AnnouncementTarget.Student && a.TargetId.HasValue && studentIds.Contains(a.TargetId.Value)) ||
                (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && (parentCircleIds.Contains(a.TargetId.Value) || assignedCircleIds.Contains(a.TargetId.Value))) ||
                (activeTeacher && a.TargetType == AnnouncementTarget.Teacher && (a.TargetId == teacherId || a.TargetId == user.Id)) ||
                (activeTeacher && a.TargetType == AnnouncementTarget.Course && a.TargetId.HasValue && assignedCourseIds.Contains(a.TargetId.Value)) ||
                (activeTeacher && a.TargetType == AnnouncementTarget.StudentCircle && a.TargetId.HasValue && (assignedStudentIds.Contains(a.TargetId.Value) || courseStudentIds.Contains(a.TargetId.Value)))
            );
        }
        else
        {
            return new List<AnnouncementDto>();
        }

        var list = await query.OrderByDescending(a => a.DateTimeSent).ToListAsync();

        var circleIds = list.Where(a => a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var studentCircleSenderIds = list.Where(a => a.TargetType == AnnouncementTarget.StudentCircle && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var studentCircles = await _db.Students.Where(s => studentCircleSenderIds.Contains(s.Id) && s.Circle != null).Select(s => new { s.Id, CircleName = s.Circle!.Name }).ToDictionaryAsync(s => s.Id, s => s.CircleName);
        var courseIdsForNames = list.Where(a => a.TargetType == AnnouncementTarget.Course && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var coursesMap = await _db.Courses.Where(c => courseIdsForNames.Contains(c.Id)).ToDictionaryAsync(c => c.Id, c => c.Name);
        var teacherIds = list.Where(a => a.TargetType == AnnouncementTarget.Teacher && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var studentIdsForNames = list.Where(a => a.TargetType == AnnouncementTarget.Student && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();
        var parentUserIds = list.Where(a => a.TargetType == AnnouncementTarget.Parent && a.TargetId.HasValue).Select(a => a.TargetId!.Value).Distinct().ToList();

        var circlesMap = await _db.Circles.Where(c => circleIds.Contains(c.Id)).ToDictionaryAsync(c => c.Id, c => c.Name);
        var teachersMap = await _db.Teachers.Where(t => teacherIds.Contains(t.Id)).ToDictionaryAsync(t => t.Id, t => t.FullName);
        var studentsMap = await _db.Students.Where(s => studentIdsForNames.Contains(s.Id)).ToDictionaryAsync(s => s.Id, s => s.FullName);
        var parentUsersList = await _db.Users.Where(u => u.Role != UserRole.Student && ((u.ParentId.HasValue && parentUserIds.Contains(u.ParentId.Value)) || parentUserIds.Contains(u.Id))).ToListAsync();
        var parentsMap = new Dictionary<int, string>();
        foreach (var p in parentUsersList)
        {
            if (p.ParentId.HasValue && !parentsMap.ContainsKey(p.ParentId.Value)) parentsMap[p.ParentId.Value] = p.FullName;
            if (!parentsMap.ContainsKey(p.Id)) parentsMap[p.Id] = p.FullName;
        }

        return list.Select(a => {
            string targetName = "الجميع";
            if (a.TargetType == AnnouncementTarget.Circle && a.TargetId.HasValue && circlesMap.TryGetValue(a.TargetId.Value, out var cName))
                targetName = $"حلقة: {cName}";
            else if (a.TargetType == AnnouncementTarget.StudentCircle && a.TargetId.HasValue && studentCircles.TryGetValue(a.TargetId.Value, out var studentCircleName))
                targetName = $"طلاب حلقة: {studentCircleName}";
            else if (a.TargetType == AnnouncementTarget.Course && a.TargetId.HasValue && coursesMap.TryGetValue(a.TargetId.Value, out var courseName))
                targetName = $"دورة: {courseName}";
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
            var exists = await _db.Circles.AnyAsync(c => c.Id == dto.TargetId.GetValueOrDefault());
            if (!exists) return (null, "الحلقة المحددة غير موجودة.");
        }
        else if (dto.TargetType == AnnouncementTarget.StudentCircle)
        {
            var exists = await _db.Students.AnyAsync(s => s.Id == dto.TargetId.GetValueOrDefault() && s.CircleId.HasValue);
            if (!exists) return (null, "الطالب أو الحلقة المحددة غير موجودة.");
        }
        else if (dto.TargetType == AnnouncementTarget.Course)
        {
            var exists = await _db.Courses.AnyAsync(c => c.Id == dto.TargetId.GetValueOrDefault());
            if (!exists) return (null, "الدورة المحددة غير موجودة.");
        }
        else if (dto.TargetType == AnnouncementTarget.Teacher)
        {
            var exists = await _db.Teachers.AnyAsync(t => t.Id == dto.TargetId.GetValueOrDefault());
            if (!exists) return (null, "المعلم المحدد غير موجود.");
        }
        else if (dto.TargetType == AnnouncementTarget.Student)
        {
            var exists = await _db.Students.AnyAsync(s => s.Id == dto.TargetId.GetValueOrDefault());
            if (!exists) return (null, "الطالب المحدد غير موجود.");
        }
        else if (dto.TargetType == AnnouncementTarget.Parent)
        {
            var exists = await _db.Users.AnyAsync(u => u.Role != UserRole.Student && (u.ParentId == dto.TargetId.GetValueOrDefault() || u.Id == dto.TargetId.GetValueOrDefault()))
                         || await _db.Students.AnyAsync(s => s.ParentId == dto.TargetId.GetValueOrDefault());
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
        else if (announcement.TargetType == AnnouncementTarget.StudentCircle && announcement.TargetId.HasValue)
        {
            var sender = await _db.Students.Include(s => s.Circle).FirstOrDefaultAsync(s => s.Id == announcement.TargetId.Value);
            if (sender?.Circle != null) targetName = $"طلاب حلقة: {sender.Circle.Name}";
        }
        else if (announcement.TargetType == AnnouncementTarget.Course && announcement.TargetId.HasValue)
        {
            var course = await _db.Courses.FindAsync(announcement.TargetId.Value);
            if (course != null) targetName = $"دورة: {course.Name}";
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
            var p = await _db.Users.FirstOrDefaultAsync(u => u.Role != UserRole.Student && (u.ParentId == announcement.TargetId.Value || u.Id == announcement.TargetId.Value));
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
