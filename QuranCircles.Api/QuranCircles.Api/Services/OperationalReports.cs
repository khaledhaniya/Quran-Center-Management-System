using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using System.Globalization;

namespace QuranCircles.Api.Services;

public record ReportFilter(string Kind = "all", DateOnly? From = null, DateOnly? To = null, int? CircleId = null,
    string? Search = null, int AbsenceThreshold = 3, int[]? StudentIds = null);

public class OperationalReports(AppDbContext db)
{
    public static readonly Dictionary<string, string> Catalog = new() {
        ["all"] = "دليل الطلاب والحلقات", ["sard_report"] = "سجل الإنجاز والتسميع", ["combined_chains"] = "السلاسل المجتمعة",
        ["khatimun_ijaza"] = "الخاتمون والتثبيت والإجازة", ["juz_path"] = "مسار أجزاء الحفظ",
        ["cumulative_absence"] = "الغياب التراكمي والإنذارات", ["teacher_discipline"] = "التزام المعلمين والجلسات",
        ["weekday_absence"] = "الحضور حسب أيام الأسبوع", ["exam_results"] = "نتائج الاختبارات والترشيحات",
        ["circle_scorecard"] = "بطاقة أداء الحلقات", ["intensive_followup"] = "المتابعة المكثفة",
        ["parent_governance"] = "حوكمة الأبناء وأولياء الأمور", ["whatsapp_directory"] = "دليل التواصل",
        ["specialized_activities"] = "الأنشطة التخصصية", ["certificates"] = "الشهادات الصادرة", ["finance"] = "الحركات المالية"
    };

    public async Task<ReportTable> BuildAsync(ReportFilter filter)
    {
        if (!Catalog.ContainsKey(filter.Kind)) throw new ArgumentException("نوع التقرير غير معروف.");
        var today = CenterClock.Today; var from = filter.From ?? new DateOnly(today.Year, today.Month, 1); var to = filter.To ?? today;
        if (to < from || to.DayNumber - from.DayNumber > 3660 || filter.AbsenceThreshold < 1) throw new ArgumentException("نطاق التقرير غير صالح.");
        var students = await db.Students.Include(s => s.Circle).AsNoTracking().ToListAsync();
        students = students.Where(s => (!filter.CircleId.HasValue || s.CircleId == filter.CircleId) &&
            (filter.StudentIds == null || filter.StudentIds.Contains(s.Id)) &&
            (string.IsNullOrWhiteSpace(filter.Search) || s.FullName.Contains(filter.Search.Trim()) || (s.StudentIdentityNumber ?? "").Contains(filter.Search.Trim()))).ToList();
        var ids = students.Select(s => s.Id).ToHashSet();
        var sessions = await db.Sessions.AsNoTracking().Where(s => s.SessionDate >= from && s.SessionDate <= to && ids.Contains(s.StudentId)).ToListAsync();
        var attendance = await db.Attendances.AsNoTracking().Where(a => a.SessionDate >= from && a.SessionDate <= to && ids.Contains(a.StudentId)).ToListAsync();
        string Name(int id) => students.FirstOrDefault(s => s.Id == id)?.FullName ?? "";
        string Circle(int id) => students.FirstOrDefault(s => s.Id == id)?.Circle?.Name ?? "غير مسند";
        string F(double n) => n.ToString("0.##", CultureInfo.InvariantCulture);
        var rows = new List<string[]>(); string[] columns;
        switch (filter.Kind)
        {
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
                columns = ["الحلقة", "التاريخ", "الحالة", "بداية فعلية UTC", "إغلاق UTC", "البديل / المستخدم", "الملاحظة"];
                var circles = await db.Circles.AsNoTracking().ToListAsync();
                rows = (await db.CircleDays.AsNoTracking().Where(d => d.Date >= from && d.Date <= to && (!filter.CircleId.HasValue || d.CircleId == filter.CircleId)).ToListAsync())
                    .Select(d => new[] { circles.FirstOrDefault(c => c.Id == d.CircleId)?.Name ?? "", d.Date.ToString(), d.Status, d.OpenedAt?.ToString("HH:mm") ?? "لم تبدأ", d.ClosedAt?.ToString("HH:mm") ?? "لم تغلق", d.SubstituteUserId?.ToString() ?? "", d.Reason }).ToList(); break;
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
        return new ReportTable(Catalog[filter.Kind], columns, rows, $"{from:yyyy-MM-dd} — {to:yyyy-MM-dd} • {rows.Count} سجل");
    }
}
