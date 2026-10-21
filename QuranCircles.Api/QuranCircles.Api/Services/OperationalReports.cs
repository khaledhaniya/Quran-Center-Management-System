using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System.Globalization;

namespace QuranCircles.Api.Services;

public record ReportFilter(string Kind = "all", DateOnly? From = null, DateOnly? To = null, int? CircleId = null,
    string? Search = null, int AbsenceThreshold = 3, int[]? StudentIds = null, int? CourseId = null, int? TeacherId = null, string? Status = null);

public class OperationalReports(AppDbContext db)
{
    public static readonly Dictionary<string, string> Catalog = new() {
        ["all"] = "دليل الطلاب والحلقات", ["sard_report"] = "سجل الإنجاز والتسميع", ["combined_chains"] = "السلاسل المجتمعة",
        ["khatimun_ijaza"] = "الخاتمون والتثبيت والإجازة", ["juz_path"] = "مسار أجزاء الحفظ",
        ["cumulative_absence"] = "الغياب التراكمي والإنذارات", ["teacher_discipline"] = "التزام المعلمين والجلسات",
        ["weekday_absence"] = "الحضور حسب أيام الأسبوع", ["exam_results"] = "نتائج الاختبارات والترشيحات",
        ["circle_scorecard"] = "بطاقة أداء الحلقات", ["intensive_followup"] = "المتابعة المكثفة",
        ["parent_governance"] = "حوكمة الأبناء وأولياء الأمور", ["whatsapp_directory"] = "دليل التواصل",
        ["specialized_activities"] = "الأنشطة التخصصية", ["certificates"] = "الشهادات الصادرة", ["finance"] = "الحركات المالية",
        ["circle_roster"] = "كشف طلاب الحلقات والمتابعة القرآنية", ["course_roster"] = "كشف الطلاب المسجلين في الدورات والرقابة الأكاديمية"
    };

    public async Task<ReportTable> BuildAsync(ReportFilter filter)
    {
        if (!Catalog.ContainsKey(filter.Kind) && filter.Kind != "student_profile") throw new ArgumentException("نوع التقرير غير معروف.");
        var today = CenterClock.Today; var from = filter.From ?? new DateOnly(today.Year, today.Month, 1); var to = filter.To ?? today;
        if(filter.Kind == "student_profile") { if(filter.StudentIds?.Length != 1) throw new ArgumentException("اختر طالباً واحداً للملف الموحد."); from = DateOnly.MinValue; }
        if (to < from || (filter.Kind != "student_profile" && to.DayNumber - from.DayNumber > 3660) || filter.AbsenceThreshold < 1) throw new ArgumentException("نطاق التقرير غير صالح.");
        var students = await db.Students.Include(s => s.Circle).AsNoTracking().Where(s => (!filter.CircleId.HasValue || s.CircleId == filter.CircleId) &&
            (filter.StudentIds == null || filter.StudentIds.Contains(s.Id)) &&
            (string.IsNullOrWhiteSpace(filter.Search) || s.FullName.Contains(filter.Search.Trim()) || (s.StudentIdentityNumber ?? "").Contains(filter.Search.Trim()))).ToListAsync();
        var ids = students.Select(s => s.Id).ToHashSet();
        var sessions = new[] { "sard_report", "intensive_followup", "circle_scorecard", "circle_roster", "student_profile" }.Contains(filter.Kind)
            ? await db.Sessions.AsNoTracking().Where(s => s.SessionDate >= from && s.SessionDate <= to && ids.Contains(s.StudentId)).ToListAsync() : new List<RecitationSession>();
        var attendance = new[] { "cumulative_absence", "weekday_absence", "circle_scorecard", "circle_roster", "student_profile" }.Contains(filter.Kind)
            ? await db.Attendances.AsNoTracking().Where(a => a.SessionDate >= from && a.SessionDate <= to && ids.Contains(a.StudentId)).ToListAsync() : new List<Attendance>();
        var lookup = students.ToDictionary(s => s.Id);
        string Name(int id) => lookup.GetValueOrDefault(id)?.FullName ?? "";
        string Circle(int id) => lookup.GetValueOrDefault(id)?.Circle?.Name ?? "غير مسند";
        string F(double n) => n.ToString("0.##", CultureInfo.InvariantCulture);
        var rows = new List<string[]>(); string[] columns;
        switch (filter.Kind)
        {
            case "student_profile":
                var student = students.SingleOrDefault() ?? throw new ArgumentException("الطالب غير موجود.");
                columns = ["القسم", "التاريخ", "البيان", "النتيجة"];
                rows.AddRange(new[] { new[] { "بيانات الطالب", "", "الاسم", student.FullName }, new[] { "بيانات الطالب", "", "الهوية", student.StudentIdentityNumber ?? "" },
                    new[] { "بيانات الطالب", "", "الحلقة", Circle(student.Id) }, new[] { "خطة الحفظ", "", "الأجزاء المنجزة / المستهدفة", $"{ReportService.CompletedParts(student)} / {student.TargetAjzaaCount}" } });
                var completed = (student.CompletedAjzaa ?? "").Split(',').Select(x => int.TryParse(x, out var n) ? n : 0).ToHashSet();
                rows.AddRange(Enumerable.Range(1,30).Select(n => new[] { "خريطة الحفظ", "", $"الجزء {n}", completed.Contains(n) ? "مكتمل" : "قيد الحفظ" }));
                rows.AddRange(sessions.OrderByDescending(s => s.SessionDate).Select(s => new[] { "التسميع", s.SessionDate.ToString("yyyy-MM-dd"), $"{SessionService.RecitationTypeText(s.RecitationType)} • {s.SurahName} {s.FromVerse}–{s.ToVerse}", $"{F(ReportService.Pages(s))} صفحة • {F(ReportService.Score(s))}%" }));
                rows.AddRange(attendance.OrderByDescending(a => a.SessionDate).Select(a => new[] { "الحضور", a.SessionDate.ToString("yyyy-MM-dd"), "حضور الحلقة", a.Status switch { AttendanceStatus.Present => "حاضر", AttendanceStatus.Late => "متأخر", AttendanceStatus.ExcusedAbsent => "غائب بعذر", _ => "غائب دون عذر" } }));
                var threshold = await db.SystemSettings.AsNoTracking().Select(s => s.PassingScoreThreshold).FirstOrDefaultAsync();if(threshold <= 0)threshold=70;
                var profileExams = await db.ExamNominations.Include(e => e.Result).Include(e => e.Course).AsNoTracking().Where(e => e.StudentId == student.Id && e.Status == "Completed" && e.Result != null && e.Result.Grade >= threshold).ToListAsync();
                rows.AddRange(profileExams.Select(e => new[] { "اختبار معتمد", e.ExamDate?.ToString("yyyy-MM-dd") ?? "", e.Course?.Name ?? $"الأجزاء {e.JuzStart}–{e.JuzEnd}", F(e.Result!.Grade) }));
                var profileCourses = await db.CourseEnrollments.Include(e => e.Course).AsNoTracking().Where(e => e.StudentId == student.Id && (e.Status == "Passed" || e.Status == "Certified") && e.CertificateCode != null && e.Grade >= threshold).ToListAsync();
                rows.AddRange(profileCourses.Select(e => new[] { "شهادة دورة", e.CertificateDate?.ToString("yyyy-MM-dd") ?? "", e.Course?.Name ?? "دورة", $"{e.CertificateCode} • {e.Grade}" }));
                rows.AddRange((await db.TalentRecords.AsNoTracking().Where(t => t.StudentId == student.Id).ToListAsync()).Select(t => new[] { "موهبة ونشاط", t.EventDate.ToString("yyyy-MM-dd"), t.Title, t.TalentType }));
                break;
            case "course_roster":
                columns = ["الدورة", "المعلم", "الطالب", "الهوية", "الحالة", "الدرجة", "حاضر", "غائب", "غياب بعذر"];
                var enrollments = await db.CourseEnrollments.Include(e => e.Course).ThenInclude(c => c!.Teacher).AsNoTracking()
                    .Where(e => ids.Contains(e.StudentId) && (!filter.CourseId.HasValue || e.CourseId == filter.CourseId)).OrderBy(e => e.Course!.Name).ThenBy(e => e.StudentId).ToListAsync();
                var courseIds = enrollments.Select(e => e.CourseId).Distinct().ToList();
                var courseAttendance = await db.CourseAttendances.AsNoTracking().Where(a => courseIds.Contains(a.CourseId) && ids.Contains(a.StudentId) && a.SessionDate >= from && a.SessionDate <= to).ToListAsync();
                rows = enrollments.Select(e => { var a = courseAttendance.Where(a => a.CourseId == e.CourseId && a.StudentId == e.StudentId).ToList(); return new[] {
                    e.Course?.Name ?? "", e.Course?.Teacher?.FullName ?? "غير معين", Name(e.StudentId), lookup[e.StudentId].StudentIdentityNumber ?? "",
                    e.Status switch { "Passed" => "ناجح", "Certified" => "معتمد", "Failed" => "لم يجتز", _ => "مسجل" }, e.Grade?.ToString("0.##") ?? "لم ترصد",
                    a.Count(x => x.Status is AttendanceStatus.Present or AttendanceStatus.Late).ToString(), a.Count(x => x.Status == AttendanceStatus.Absent).ToString(), a.Count(x => x.Status == AttendanceStatus.ExcusedAbsent).ToString() }; }).ToList(); break;
            case "circle_roster":
                columns = ["الحلقة", "المعلم", "الطالب", "الهوية", "حالة الطالب", "الأجزاء المكتملة", "جلسات التسميع", "صفحات الحفظ", "صفحات المراجعة", "الحضور %"];
                var circleTeachers = await db.Circles.Include(c => c.Teacher).AsNoTracking().ToDictionaryAsync(c => c.Id, c => c.Teacher == null ? "غير معين" : c.Teacher.FullName);
                rows = students.OrderBy(s => s.CircleId).ThenBy(s => s.FullName).Select(s => { var rec = sessions.Where(x => x.StudentId == s.Id).ToList(); var a = attendance.Where(x => x.StudentId == s.Id).ToList(); return new[] {
                    Circle(s.Id), s.CircleId is int cid ? circleTeachers.GetValueOrDefault(cid, "غير معين") : "غير معين", s.FullName, s.StudentIdentityNumber ?? "", s.IsActive ? "نشط" : "معلق", ReportService.CompletedParts(s).ToString(),
                    rec.Count.ToString(), F(rec.Where(x => x.RecitationType == RecitationType.Memorization).Sum(ReportService.Pages)), F(rec.Where(x => x.RecitationType != RecitationType.Memorization).Sum(ReportService.Pages)),
                    a.Count == 0 ? "لم يرصد" : F(ReportService.Percentage(a.Count(x => x.Status is AttendanceStatus.Present or AttendanceStatus.Late), a.Count)) }; }).ToList(); break;
            case "sard_report":
                columns = ["الطالب", "الحلقة", "التاريخ", "المسار", "السورة والآيات", "الصفحات", "الدرجة"];
                rows = sessions.OrderBy(s => s.SessionDate).ThenBy(s => s.Id).Select(s => new[] { Name(s.StudentId), Circle(s.StudentId), s.SessionDate.ToString(), SessionService.RecitationTypeText(s.RecitationType), $"{s.SurahName} {s.FromVerse}–{s.ToVerse}", F(ReportService.Pages(s)) + (s.Pages == null ? " تقديري" : ""), F(ReportService.Score(s)) }).ToList(); break;
            case "combined_chains":
            case "exam_results":
                columns = ["الطالب", "الحلقة", "النوع", "الأجزاء", "الحالة", "التاريخ", "الدرجة"];
                var exams = await db.ExamNominations.Include(e => e.Result).AsNoTracking().Where(e => ids.Contains(e.StudentId)).ToListAsync();
                rows = exams.Where(e => filter.Kind == "combined_chains" ? e.NominationType == "Combined" : e.NominationDate >= from && e.NominationDate <= to)
                    .Select(e => new[] { Name(e.StudentId), Circle(e.StudentId), e.NominationType == "Combined" ? "سلاسل مجتمعة" : e.NominationType == "Course" ? "دورة" : "قرآن", $"{e.JuzStart}–{e.JuzEnd}", e.Status, e.ExamDate?.ToString("yyyy-MM-dd") ?? "لم يحدد", e.Result == null ? "لم يختبر" : F(e.Result.Grade) }).ToList(); break;
            case "cumulative_absence":
                columns = ["الطالب", "الحلقة", "غياب دون عذر", "غياب بعذر", "التواصل"];
                rows = students.Select(s => new { s, Absent = attendance.Where(a => a.StudentId == s.Id && a.Status == AttendanceStatus.Absent).Select(a => a.SessionDate).Distinct().Count() })
                    .Where(x => x.Absent >= filter.AbsenceThreshold).Select(x => new[] { x.s.FullName, Circle(x.s.Id), x.Absent.ToString(), attendance.Count(a => a.StudentId == x.s.Id && a.Status == AttendanceStatus.ExcusedAbsent).ToString(), x.s.FamilyContact ?? "" }).ToList(); break;
            case "weekday_absence":
                columns = ["اليوم", "حاضر", "متأخر", "غائب بعذر", "غائب دون عذر"];
                var weekdays = new[] { "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت" };
                rows = Enumerable.Range(0, 7).Select(d => new[] { weekdays[d] }.Concat(new[] { AttendanceStatus.Present, AttendanceStatus.Late, AttendanceStatus.ExcusedAbsent, AttendanceStatus.Absent }.Select(status => attendance.Count(a => (int)a.SessionDate.DayOfWeek == d && a.Status == status).ToString())).ToArray()).ToList(); break;
            case "intensive_followup":
                columns = ["الطالب", "الحلقة", "متوسط آخر 3 جلسات", "التواصل"];
                rows = students.Select(s => new { s, Recent = sessions.Where(x => x.StudentId == s.Id).OrderByDescending(x => x.SessionDate).ThenByDescending(x => x.Id).Take(3).ToList() })
                    .Where(x => x.Recent.Count == 3 && x.Recent.All(s => ReportService.Score(s) < 70))
                    .Select(x => new[] { x.s.FullName, Circle(x.s.Id), F(x.Recent.Average(ReportService.Score)), x.s.FamilyContact ?? "" }).ToList(); break;
            case "parent_governance":
                columns = ["الطالب", "الحلقة", "ولي الأمر", "حالة الحساب", "التواصل"];
                var parents = await db.Users.Include(u => u.Teacher).Where(u => u.Role != UserRole.Student).AsNoTracking().ToListAsync();
                rows = students.Select(s => { var p = parents.FirstOrDefault(u => ParentLinks.IsChild(u, s)); return new[] { s.FullName, Circle(s.Id), p?.FullName ?? "غير مربوط", p == null ? "لا يوجد حساب" : p.IsActive ? "نشط" : "معلق", s.FamilyContact ?? "" }; }).ToList(); break;
            case "juz_path":
                columns = ["الطالب", "الحلقة", "الأجزاء المنجزة", "عدد الأجزاء", "المتبقي من القرآن"];
                rows = students.Select(s => new[] { s.FullName, Circle(s.Id), s.CompletedAjzaa ?? "", ReportService.CompletedParts(s).ToString(), (30 - ReportService.CompletedParts(s)).ToString() }).ToList(); break;
            case "khatimun_ijaza":
                columns = ["الطالب", "المرحلة", "الرواية", "خطة التثبيت", "تاريخ الانضمام"];
                var huffaz = await db.HuffazMembers.AsNoTracking().Where(h => h.StudentId.HasValue && ids.Contains(h.StudentId.Value)).ToListAsync();
                rows = huffaz.Select(h => new[] { h.FullName, h.IsKhatim ? "خاتم" : "قيد الحفظ", h.Riwayah ?? "", h.RevisionPlan ?? "", h.JoinDate.ToString() }).ToList(); break;
            case "specialized_activities":
                columns = ["الطالب", "الحلقة", "المسار", "المشاركة", "التاريخ", "التقييم"];
                rows = (await db.TalentRecords.AsNoTracking().Where(t => ids.Contains(t.StudentId) && t.EventDate >= from && t.EventDate <= to).ToListAsync())
                    .Select(t => new[] { Name(t.StudentId), Circle(t.StudentId), t.TalentType, t.Title, t.EventDate.ToString(), t.EvaluationScore?.ToString() ?? "" }).ToList(); break;
            case "certificates":
                columns = ["الطالب", "الدورة", "الرمز", "تاريخ الإصدار", "الدرجة"];
                rows = (await db.CourseEnrollments.Include(e => e.Course).AsNoTracking().Where(e => ids.Contains(e.StudentId) && e.CertificateCode != null && e.CertificateDate >= from && e.CertificateDate <= to).ToListAsync())
                    .Select(e => new[] { Name(e.StudentId), e.Course?.Name ?? "", e.CertificateCode!, e.CertificateDate.ToString()!, e.Grade?.ToString() ?? "" }).ToList(); break;
            case "teacher_discipline":
                columns = ["الحلقة", "المعلم الأصلي", "التاريخ", "الحالة", "بداية مقررة", "بداية فعلية", "إغلاق الحلقة", "التأخير بالدقائق", "المعلم البديل", "سبب الغياب أو الإجازة"];
                rows = TeacherAttendanceService.Filter(await new TeacherAttendanceService(db).BuildAsync(from, to, filter.CircleId), filter.TeacherId, filter.Status, filter.Search).Select(d => new[] {
                    d.CircleName, d.TeacherName, d.Date.ToString("yyyy-MM-dd"), d.StatusText + (d.IsAutomatic ? " • رصد تلقائي" : ""), d.ScheduledStart ?? "غير محدد", d.OpenedAt ?? "لم تبدأ", d.ClosedAt ?? "لم تغلق",
                    d.LateMinutes?.ToString() ?? "", d.SubstituteName, d.Reason }).ToList(); break;
            case "circle_scorecard":
                columns = ["الحلقة", "الطلاب", "الحضور %", "جلسات التسميع", "صفحات الحفظ", "صفحات المراجعة", "متوسط الإتقان"];
                rows = students.GroupBy(s => s.CircleId).Select(g => { var gIds = g.Select(s => s.Id).ToHashSet(); var a = attendance.Where(a => a.CircleId == g.Key).ToList(); var rec = sessions.Where(s => gIds.Contains(s.StudentId)).ToList(); return new[] { g.First().Circle?.Name ?? "غير مسند", g.Count().ToString(), F(ReportService.Percentage(a.Count(a => a.Status is AttendanceStatus.Present or AttendanceStatus.Late), a.Count)), rec.Count.ToString(), F(rec.Where(s => s.RecitationType == RecitationType.Memorization).Sum(ReportService.Pages)), F(rec.Where(s => s.RecitationType != RecitationType.Memorization).Sum(ReportService.Pages)), rec.Count == 0 ? "لا توجد بيانات" : F(rec.Average(ReportService.Score)) }; }).ToList(); break;
            case "finance":
                columns = ["التاريخ", "البيان", "النوع", "المبلغ", "العملة", "الطرف", "السند"];
                var start = from.ToDateTime(TimeOnly.MinValue); var end = to.AddDays(1).ToDateTime(TimeOnly.MinValue);
                rows = (await db.FinancialTransactions.AsNoTracking().Where(t => t.TransactionDate >= start && t.TransactionDate < end).OrderBy(t => t.TransactionDate).ToListAsync())
                    .Select(t => new[] { t.TransactionDate.ToString("yyyy-MM-dd"), t.Title, t.Type == TransactionType.Income ? "وارد" : "صادر", t.Amount.ToString("0.00"), t.Currency, t.DonorName ?? t.RecipientName ?? "", t.ReferenceNumber ?? "" }).ToList(); break;
            default:
                columns = ["الطالب", "الهوية", "الحلقة", "الحالة", "هاتف الطالب", "هاتف ولي الأمر"];
                rows = students.OrderBy(s => s.FullName).Select(s => new[] { s.FullName, s.StudentIdentityNumber ?? "", Circle(s.Id), s.IsActive ? "نشط" : "معلق", s.StudentMobile ?? "", s.FamilyContact ?? "" }).ToList(); break;
        }
        return new ReportTable(filter.Kind == "student_profile" ? $"الملف الموحد للطالب • {students.Single().FullName}" : Catalog[filter.Kind], columns, rows,
            filter.Kind == "student_profile" ? $"السجل الكامل حتى {to:yyyy-MM-dd}" : $"{from:yyyy-MM-dd} — {to:yyyy-MM-dd} • {rows.Count} سجل");
    }
}
