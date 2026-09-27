using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.DTOs;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;
using System.Linq;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/teachers")]
public class TeachersController : ControllerBase
{
    private readonly TeacherService _svc;
    private readonly AppDbContext _db;

    public TeachersController(TeacherService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    [HttpGet]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> GetAll([FromQuery] string? search)
        => Ok(await _svc.GetAllAsync(search));

    [HttpGet("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer, UserRole.Parent, UserRole.Student)]
    public async Task<IActionResult> Get(int id)
    {
        var t = await _svc.GetByIdAsync(id);
        return t is null ? NotFound(new { error = "المعلّم غير موجود." }) : Ok(t);
    }

    [HttpPost]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Create([FromBody] CreateTeacherDto dto)
    {
        var (created, error) = await _svc.CreateAsync(dto);
        if (error is not null) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "CreateTeacher", $"إضافة معلم جديد: {created!.FullName}");

        return CreatedAtAction(nameof(Get), new { id = created!.Id }, created);
    }

    [HttpPut("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateTeacherDto dto)
    {
        var (ok, error) = await _svc.UpdateAsync(id, dto);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateTeacher", $"تعديل بيانات المعلم: {dto.FullName} (ID: #{id})");

        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> Deactivate(int id)
    {
        var ok = await _svc.DeactivateAsync(id);
        if (ok)
        {
            await AuditLogger.LogAsync(_db, HttpContext, "DeactivateTeacher", $"تعطيل حساب المعلم ID: #{id}");
        }
        return ok ? NoContent() : NotFound(new { error = "المعلّم غير موجود." });
    }

    [HttpDelete("{id:int}/permanent")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> HardDelete(int id)
    {
        var (ok, teacherName, error) = await _svc.HardDeleteAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "HardDeleteTeacher", $"حذف معلم نهائياً: {teacherName} (ID: #{id}) وحسابه بالتنسيق");

        return Ok(new { Message = $"تم حذف المعلم ({teacherName}) نهائياً من النظام." });
    }

    [HttpPost("{id:int}/toggle-active")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ToggleActive(int id)
    {
        var (ok, newStatus, error) = await _svc.ToggleActiveAsync(id);
        if (!ok) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "ToggleActiveTeacher", $"تغيير حالة تفعيل المعلم ID #{id} إلى: {(newStatus ? "نشط" : "معطل")}");

        return Ok(new { Message = newStatus ? "تم تنشيط المعلم بنجاح." : "تم تعطيل المعلم بنجاح.", IsActive = newStatus });
    }

    [HttpPost("import-excel")]
    [RequireRole(UserRole.Admin, UserRole.Developer)]
    public async Task<IActionResult> ImportFromExcel()
    {
        var (imported, updated, error) = await _svc.ImportExcelTeachersAsync();
        if (error is not null) return BadRequest(new { error });

        await AuditLogger.LogAsync(_db, HttpContext, "ImportExcelTeachers", $"استيراد وتحديث كادر المعلمين ({imported} جديد, {updated} محدث)");
        return Ok(new { message = $"تم استيراد بيانات المعلمين بنجاح ({imported} جديد، {updated} تم تحديث بياناتهم).", imported, updated });
    }

    [HttpGet("{id:int}/comprehensive-report")]
    [RequireRole(UserRole.Admin, UserRole.Teacher, UserRole.Developer)]
    public async Task<IActionResult> GetTeacherComprehensiveReport(int id, [FromQuery] string? fromDate = null, [FromQuery] string? toDate = null)
    {
        var currentUserId = FakeAuth.GetUserId(HttpContext);
        var currentUser = await _db.Users.FindAsync(currentUserId);
        
        Teacher? teacher = null;
        if (currentUser?.Role == UserRole.Teacher)
        {
            if (currentUser.TeacherId.HasValue && currentUser.TeacherId.Value > 0)
            {
                teacher = await _db.Teachers.FindAsync(currentUser.TeacherId.Value);
            }
            if (teacher == null)
            {
                teacher = await _db.Teachers.FirstOrDefaultAsync(t => t.FullName == currentUser.FullName || t.Id == id || t.Id == currentUser.Id);
            }
        }
        else
        {
            teacher = await _db.Teachers.FindAsync(id);
            if (teacher == null && id > 0)
            {
                var userT = await _db.Users.FindAsync(id);
                if (userT != null && userT.TeacherId.HasValue)
                {
                    teacher = await _db.Teachers.FindAsync(userT.TeacherId.Value);
                }
            }
        }

        if (teacher == null) return NotFound(new { error = "المعلم غير موجود." });

        DateOnly? parsedFrom = null;
        if (!string.IsNullOrWhiteSpace(fromDate) && DateOnly.TryParse(fromDate, out var fDate)) parsedFrom = fDate;

        DateOnly? parsedTo = null;
        if (!string.IsNullOrWhiteSpace(toDate) && DateOnly.TryParse(toDate, out var tDate)) parsedTo = tDate;

        var circles = await _db.Circles
            .Where(c => c.TeacherId == teacher.Id)
            .Select(c => c.Id)
            .ToListAsync();

        var students = await _db.Students
            .Include(s => s.Circle)
            .AsNoTracking()
            .Where(s => s.CircleId.HasValue && circles.Contains(s.CircleId.Value))
            .OrderBy(s => s.FullName)
            .ToListAsync();

        var studentIds = students.Select(s => s.Id).ToList();

        // Query sessions directly to prevent Cartesian explosion and dropped rows
        var sessDbQuery = _db.Sessions.AsNoTracking().Where(s => studentIds.Contains(s.StudentId));
        if (parsedFrom.HasValue) sessDbQuery = sessDbQuery.Where(rs => rs.SessionDate >= parsedFrom.Value);
        if (parsedTo.HasValue) sessDbQuery = sessDbQuery.Where(rs => rs.SessionDate <= parsedTo.Value);
        var allSessions = await sessDbQuery.ToListAsync();
        var sessionsByStudent = allSessions.ToLookup(s => s.StudentId);

        // Query attendances directly
        var attDbQuery = _db.Attendances.AsNoTracking().Where(a => studentIds.Contains(a.StudentId));
        if (parsedFrom.HasValue) attDbQuery = attDbQuery.Where(a => a.SessionDate >= parsedFrom.Value);
        if (parsedTo.HasValue) attDbQuery = attDbQuery.Where(a => a.SessionDate <= parsedTo.Value);
        var allAttendances = await attDbQuery.ToListAsync();
        var attendancesByStudent = allAttendances.ToLookup(a => a.StudentId);
        var courseEnrollments = await _db.CourseEnrollments
            .Include(ce => ce.Course)
            .AsNoTracking()
            .Where(ce => studentIds.Contains(ce.StudentId))
            .ToListAsync();

        var courseAttendances = await _db.CourseAttendances
            .Include(ca => ca.Course)
            .AsNoTracking()
            .Where(ca => studentIds.Contains(ca.StudentId))
            .ToListAsync();

        var report = students.Select(s =>
        {
            var attList = attendancesByStudent[s.Id].ToList();
            var sessList = sessionsByStudent[s.Id].ToList();

            var totalAtt = attList.Count;
            var presentCount = attList.Count(a => a.Status == AttendanceStatus.Present);
            var absentCount = attList.Count(a => a.Status == AttendanceStatus.Absent);
            var lateCount = attList.Count(a => a.Status == AttendanceStatus.Late);
            var attRate = totalAtt > 0 ? (int)Math.Round((double)presentCount / totalAtt * 100) : 100;

            return new
            {
                s.Id,
                s.FullName,
                s.StudentIdentityNumber,
                DateOfBirth = s.DateOfBirth.ToString("yyyy-MM-dd"),
                s.FamilyContact,
                s.StudentMobile,
                s.Address,
                s.IsActive,
                CircleName = s.Circle != null ? s.Circle.Name : "بدون حلقة",
                s.TargetAjzaaCount,
                s.PlanType,
                s.DailyPacePages,
                s.CompletedAjzaa,
                // Attendance Summary
                TotalAttendanceDays = totalAtt,
                PresentDaysCount = presentCount,
                AbsentDaysCount = absentCount,
                LateDaysCount = lateCount,
                AttendanceRatePercentage = attRate,
                AttendanceRecords = attList.OrderByDescending(a => a.SessionDate).Select(a => new
                {
                    a.Id,
                    Date = a.SessionDate.ToString("yyyy-MM-dd"),
                    SessionDate = a.SessionDate.ToString("yyyy-MM-dd"),
                    Status = (int)a.Status,
                    StatusText = a.Status == AttendanceStatus.Present ? "حاضر" : (a.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
                }),
                // Recitation Sessions
                TotalRecitationSessions = sessList.Count,
                DidNotReciteCount = sessList.Count(rs => rs.Assessment == AssessmentLevel.DidNotRecite),
                MemorizationSessionsCount = sessList.Count(rs => rs.RecitationType == RecitationType.Memorization && rs.Assessment != AssessmentLevel.DidNotRecite),
                RevisionSessionsCount = sessList.Count(rs => rs.RecitationType == RecitationType.Revision && rs.Assessment != AssessmentLevel.DidNotRecite),
                TotalVersesRecited = sessList.Where(rs => rs.Assessment != AssessmentLevel.DidNotRecite).Sum(rs => Math.Max(0, rs.ToVerse - rs.FromVerse + 1)),
                RecitationSessions = sessList.OrderByDescending(rs => rs.SessionDate).Select(rs => new
                {
                    rs.Id,
                    Date = rs.SessionDate.ToString("yyyy-MM-dd"),
                    SessionDate = rs.SessionDate.ToString("yyyy-MM-dd"),
                    RecitationType = (int)rs.RecitationType,
                    RecitationTypeText = rs.RecitationType == RecitationType.Revision ? "مراجعة وتثبيت" : "حفظ جديد",
                    rs.SurahName,
                    rs.FromVerse,
                    rs.ToVerse,
                    VersesCount = rs.Assessment == AssessmentLevel.DidNotRecite ? 0 : Math.Max(0, rs.ToVerse - rs.FromVerse + 1),
                    Assessment = rs.Assessment.ToString(),
                    AssessmentText = rs.Assessment == AssessmentLevel.DidNotRecite ? "لم يُسمّع" : (rs.Assessment == AssessmentLevel.Excellent ? "ممتاز" : (rs.Assessment == AssessmentLevel.VeryGood ? "جيد جداً" : (rs.Assessment == AssessmentLevel.Good ? "جيد" : (rs.Assessment == AssessmentLevel.Medium ? "متوسط" : "مرفوض")))),
                    rs.Notes,
                    rs.ViaLottery
                }),
                // Courses & Course Attendance
                Courses = courseEnrollments.Where(ce => ce.StudentId == s.Id).Select(ce => new
                {
                    ce.CourseId,
                    CourseName = ce.Course != null ? ce.Course.Name : "",
                    ce.Status,
                    ce.Grade,
                    ce.CertificateCode,
                    PresentCount = courseAttendances.Count(ca => ca.StudentId == s.Id && ca.CourseId == ce.CourseId && ca.Status == AttendanceStatus.Present),
                    AbsentCount = courseAttendances.Count(ca => ca.StudentId == s.Id && ca.CourseId == ce.CourseId && ca.Status == AttendanceStatus.Absent),
                    Attendances = courseAttendances.Where(ca => ca.StudentId == s.Id && ca.CourseId == ce.CourseId).Select(ca => new
                    {
                        Date = ca.SessionDate.ToString("yyyy-MM-dd"),
                        Status = (int)ca.Status,
                        StatusText = ca.Status == AttendanceStatus.Present ? "حاضر" : (ca.Status == AttendanceStatus.Absent ? "غائب" : "متأخر")
                    })
                })
            };
        }).ToList();

        return Ok(new
        {
            TeacherId = teacher.Id,
            TeacherName = teacher.FullName,
            TotalStudents = students.Count,
            Students = report
        });
    }

    [HttpGet("{id:int}/comprehensive-report/printable")]
    public async Task<IActionResult> PrintableComprehensiveReport(int id, [FromQuery] string? fromDate = null, [FromQuery] string? toDate = null, [FromQuery] string? download = null)
    {
        var teacher = await _db.Teachers.FindAsync(id);
        if (teacher == null) return NotFound("المعلم غير موجود");

        var settings = await _db.SystemSettings.FirstOrDefaultAsync() ?? new SystemSettings();

        DateOnly? parsedFrom = DateOnly.TryParse(fromDate, out var pf) ? pf : null;
        DateOnly? parsedTo = DateOnly.TryParse(toDate, out var pt) ? pt : null;

        var circles = await _db.Circles
            .Where(c => c.TeacherId == teacher.Id || (c.AssistantTeacherId.HasValue && c.AssistantTeacherId.Value == teacher.Id))
            .Select(c => c.Id)
            .ToListAsync();

        var students = await _db.Students
            .Include(s => s.Circle)
            .AsNoTracking()
            .Where(s => s.CircleId.HasValue && circles.Contains(s.CircleId.Value))
            .OrderBy(s => s.FullName)
            .ToListAsync();

        var studentIds = students.Select(s => s.Id).ToList();

        var sessQuery = _db.Sessions.AsNoTracking().Where(s => studentIds.Contains(s.StudentId));
        if (parsedFrom.HasValue) sessQuery = sessQuery.Where(rs => rs.SessionDate >= parsedFrom.Value);
        if (parsedTo.HasValue) sessQuery = sessQuery.Where(rs => rs.SessionDate <= parsedTo.Value);
        var allSessions = await sessQuery.ToListAsync();
        var sessionsByStudent = allSessions.ToLookup(s => s.StudentId);

        var attQuery = _db.Attendances.AsNoTracking().Where(a => studentIds.Contains(a.StudentId));
        if (parsedFrom.HasValue) attQuery = attQuery.Where(a => a.SessionDate >= parsedFrom.Value);
        if (parsedTo.HasValue) attQuery = attQuery.Where(a => a.SessionDate <= parsedTo.Value);
        var allAttendances = await attQuery.ToListAsync();
        var attendancesByStudent = allAttendances.ToLookup(a => a.StudentId);

        var distinctDates = allSessions.Select(s => s.SessionDate)
            .Union(allAttendances.Select(a => a.SessionDate))
            .OrderByDescending(d => d)
            .Take(15)
            .ToList();

        var periodText = parsedFrom.HasValue && parsedTo.HasValue 
            ? $"الفترة من {parsedFrom:yyyy-MM-dd} إلى {parsedTo:yyyy-MM-dd}" 
            : (parsedFrom.HasValue ? $"من تاريخ {parsedFrom:yyyy-MM-dd}" : "كامل الفترة المسجلة");

        var autoDownloadScript = download == "pdf" ? "<script>window.addEventListener('DOMContentLoaded', () => { setTimeout(downloadPdf, 600); });</script>" : "";

        var rowsHtml = new System.Text.StringBuilder();
        int counter = 1;
        foreach (var s in students)
        {
            var atts = attendancesByStudent[s.Id].ToList();
            var sess = sessionsByStudent[s.Id].ToList();
            var attRate = atts.Count > 0 ? (int)Math.Round((double)atts.Count(a => a.Status == AttendanceStatus.Present) / atts.Count * 100) : 100;
            var totalVerses = sess.Where(rs => rs.Assessment != AssessmentLevel.DidNotRecite).Sum(rs => Math.Max(0, rs.ToVerse - rs.FromVerse + 1));
            var lastSess = sess.OrderByDescending(rs => rs.SessionDate).FirstOrDefault();
            var lastReciteText = lastSess != null ? $"{lastSess.SurahName} ({lastSess.FromVerse}-{lastSess.ToVerse})" : "لا يوجد";

            rowsHtml.Append($@"
                <tr>
                    <td style=""text-align:center; font-weight:bold;"">{counter++}</td>
                    <td style=""font-weight:bold; color:#0d3b26;"">{s.FullName}</td>
                    <td style=""text-align:center;"">{s.StudentIdentityNumber ?? "-"}</td>
                    <td style=""text-align:center;"">{s.Circle?.Name ?? "-"}</td>
                    <td style=""text-align:center; font-weight:bold;"">{attRate}%</td>
                    <td style=""text-align:center;"">{sess.Count}</td>
                    <td style=""text-align:center; font-weight:bold; color:#059669;"">{totalVerses}</td>
                    <td style=""text-align:center;"">{lastReciteText}</td>
                    <td style=""text-align:center; font-size:11px;"">{(lastSess != null ? lastSess.SessionDate.ToString("yyyy-MM-dd") : "-")}</td>
                </tr>");
        }

        var html = $@"<!DOCTYPE html>
<html lang=""ar"" dir=""rtl"">
<head>
    <meta charset=""UTF-8"">
    <title>كشف متابعة طلاب حلقة الشيخ {teacher.FullName}</title>
    <link rel=""preconnect"" href=""https://fonts.googleapis.com"">
    <link href=""https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&display=swap"" rel=""stylesheet"">
    <script src=""https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js""></script>
    <style>
        body {{
            font-family: 'Cairo', sans-serif;
            background: #f0f2f5;
            margin: 0;
            padding: 20px;
            color: #1f2937;
            direction: rtl;
        }}
        .action-bar {{
            max-width: 1000px;
            margin: 0 auto 20px auto;
            display: flex;
            gap: 12px;
            justify-content: flex-end;
            flex-wrap: wrap;
        }}
        .btn {{
            padding: 10px 20px;
            border-radius: 8px;
            border: none;
            font-family: 'Cairo', sans-serif;
            font-weight: bold;
            font-size: 14px;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s ease;
        }}
        .btn-pdf {{ background: #0d3b26; color: #fff; }}
        .btn-excel {{ background: #059669; color: #fff; }}
        .btn-print {{ background: #4b5563; color: #fff; }}
        .report-page {{
            max-width: 1000px;
            margin: 0 auto;
            background: #ffffff;
            padding: 32px;
            border-radius: 14px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            box-sizing: border-box;
        }}
        .header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid #0d3b26;
            padding-bottom: 16px;
            margin-bottom: 20px;
        }}
        .center-title {{ font-size: 20px; font-weight: 800; color: #0d3b26; }}
        .report-title {{ font-size: 16px; font-weight: 700; color: #c5a059; margin-top: 4px; }}
        .kpi-row {{
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 12px;
            margin-bottom: 20px;
        }}
        .kpi-card {{
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 12px;
            text-align: center;
        }}
        .kpi-val {{ font-size: 20px; font-weight: 800; color: #0d3b26; }}
        .kpi-lbl {{ font-size: 12px; color: #64748b; font-weight: 600; margin-top: 2px; }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
            font-size: 12px;
        }}
        th, td {{
            border: 1px solid #cbd5e1;
            padding: 8px 10px;
        }}
        th {{
            background: #0d3b26;
            color: #ffffff;
            font-weight: 700;
            text-align: center;
        }}
        tr:nth-child(even) {{ background: #f8fafc; }}
        @media print {{
            .action-bar {{ display: none !important; }}
            body {{ background: #fff; padding: 0; }}
            .report-page {{ box-shadow: none; padding: 10px; }}
        }}
    </style>
</head>
<body>
    <div class=""action-bar"">
        <button class=""btn btn-pdf"" onclick=""downloadPdf()"">📥 تحميل الكشف (PDF)</button>
        <button class=""btn btn-excel"" onclick=""exportExcel()"">📊 تصدير كملف إكسل (XLS)</button>
        <button class=""btn btn-print"" onclick=""window.print()"">🖨️ طباعة فورية</button>
    </div>

    <div class=""report-page"" id=""report-container"">
        <div class=""header"">
            <div>
                <div class=""center-title"">{settings.CenterName}</div>
                <div class=""report-title"">كشف متابعة وتسميع طلاب الحلقة الشامل</div>
                <div style=""font-size: 12px; color: #64748b; margin-top: 4px;"">{periodText} | مسجد: {settings.MosqueName}</div>
            </div>
            <div style=""text-align: left;"">
                <div style=""font-weight: bold; font-size: 14px; color: #0d3b26;"">المعلم: {teacher.FullName}</div>
                <div style=""font-size: 12px; color: #64748b;"">تاريخ الاستخراج: {DateTime.Now:yyyy-MM-dd}</div>
            </div>
        </div>

        <div class=""kpi-row"">
            <div class=""kpi-card""><div class=""kpi-val"">{students.Count}</div><div class=""kpi-lbl"">إجمالي طلاب الحلقة</div></div>
            <div class=""kpi-card""><div class=""kpi-val"">{allSessions.Count}</div><div class=""kpi-lbl"">جلسات التسميع</div></div>
            <div class=""kpi-card""><div class=""kpi-val"">{allSessions.Where(rs => rs.Assessment != AssessmentLevel.DidNotRecite).Sum(rs => Math.Max(0, rs.ToVerse - rs.FromVerse + 1))}</div><div class=""kpi-lbl"">إجمالي الآيات المسمعة</div></div>
            <div class=""kpi-card""><div class=""kpi-val"">{allAttendances.Count(a => a.Status == AttendanceStatus.Present)}</div><div class=""kpi-lbl"">أيام الحضور الفعلي</div></div>
        </div>

        <table id=""roster-table"">
            <thead>
                <tr>
                    <th style=""width: 35px;"">#</th>
                    <th>اسم الطالب الكامل</th>
                    <th>رقم الهوية</th>
                    <th>الحلقة</th>
                    <th>نسبة الحضور</th>
                    <th>الجلسات</th>
                    <th>الآيات المسمعة</th>
                    <th>آخر سورة مسمعة</th>
                    <th>تاريخ آخر تسميع</th>
                </tr>
            </thead>
            <tbody>
                {rowsHtml}
            </tbody>
        </table>

        <div style=""margin-top: 30px; display: flex; justify-content: space-between; font-size: 12px; color: #64748b; border-top: 1px dashed #cbd5e1; padding-top: 12px;"">
            <div>توقيع المشيخة / المعلم: ...............................</div>
            <div>اعتماد أمير المركز: الشيخ علي حسن النبيه</div>
        </div>
    </div>

    <script>
        function downloadPdf() {{
            const element = document.getElementById('report-container');
            const opt = {{
                margin:       8,
                filename:     'كشف_حلقة_{teacher.FullName.Replace(" ", "_")}.pdf',
                image:        {{ type: 'jpeg', quality: 0.98 }},
                html2canvas:  {{ scale: 2, useCORS: true, logging: false }},
                jsPDF:        {{ unit: 'mm', format: 'a4', orientation: 'landscape' }}
            }};
            html2pdf().set(opt).from(element).save();
        }}

        function exportExcel() {{
            const table = document.getElementById('roster-table');
            const html = table.outerHTML;
            const url = 'data:application/vnd.ms-excel,' + encodeURIComponent(html);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'كشف_حلقة_{teacher.FullName.Replace(" ", "_")}.xls';
            a.click();
        }}
    </script>
    {autoDownloadScript}
</body>
</html>";

        return Content(html, "text/html", System.Text.Encoding.UTF8);
    }
}
