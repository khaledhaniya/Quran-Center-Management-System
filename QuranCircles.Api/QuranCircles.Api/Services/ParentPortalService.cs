using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

public class ParentPortalService(AppDbContext db)
{
    public async Task<object> BuildAsync(User user, DateOnly? fromDate=null, DateOnly? toDate=null)
    {
        var today=CenterClock.Today;var from=fromDate??new DateOnly(today.Year,today.Month,1);var to=toDate??today;
        if(to<from||to>today||to.DayNumber-from.DayNumber>366)throw new ArgumentException("اختر فترة صحيحة لا تتجاوز سنة وتنتهي اليوم أو قبله.");
        var students=await new ReportService(db).GetSmartChildrenForParentAsync(user);
        var ids=students.Select(s=>s.Id).ToArray();
        var circleIds=students.Where(s=>s.CircleId.HasValue).Select(s=>s.CircleId!.Value).Distinct().ToArray();
        var circles=await db.Circles.Include(c=>c.Teacher).AsNoTracking().Where(c=>circleIds.Contains(c.Id)).ToDictionaryAsync(c=>c.Id);
        var sessions=await db.Sessions.AsNoTracking().Where(s=>ids.Contains(s.StudentId)&&s.SessionDate>=from&&s.SessionDate<=to).OrderByDescending(s=>s.SessionDate).ThenByDescending(s=>s.Id).ToListAsync();
        var attendance=await db.Attendances.AsNoTracking().Where(a=>ids.Contains(a.StudentId)&&a.SessionDate>=from&&a.SessionDate<=to).OrderByDescending(a=>a.SessionDate).ToListAsync();
        var enrollments=await db.CourseEnrollments.Include(e=>e.Course).ThenInclude(c=>c!.Teacher).AsNoTracking().Where(e=>ids.Contains(e.StudentId)).ToListAsync();
        var evaluated=await db.ExamNominations.AsNoTracking().Where(n=>ids.Contains(n.StudentId)&&n.CourseId.HasValue&&n.Result!=null&&(n.Status=="Completed"||n.Status=="Failed")).Select(n=>new {n.StudentId,n.CourseId}).ToListAsync();
        var evaluatedKeys=evaluated.Select(n=>(n.StudentId,n.CourseId)).ToHashSet();
        var talents=await db.TalentRecords.AsNoTracking().Where(t=>ids.Contains(t.StudentId)&&t.EventDate>=from&&t.EventDate<=to).GroupBy(t=>t.StudentId).Select(g=>new {Id=g.Key,Count=g.Count()}).ToDictionaryAsync(g=>g.Id,g=>g.Count);
        var children=students.Select(s=>{
            var rec=sessions.Where(r=>r.StudentId==s.Id).ToList();var att=attendance.Where(a=>a.StudentId==s.Id).ToList();
            var circle=s.CircleId.HasValue?circles.GetValueOrDefault(s.CircleId.Value):null;
            return new {
                studentId=s.Id,studentName=s.FullName,circleName=circle?.Name??"غير مسند",isActive=s.IsActive,
                profile=new {familyContact=s.FamilyContact??"",studentMobile=s.StudentMobile??"",currentAddress=s.CurrentAddress??s.Address??"",healthStatus=s.HealthStatus??"",notes=s.Notes??""},
                teacherName=circle?.Teacher?.FullName??"لم يحدد",teacherPhone=string.IsNullOrWhiteSpace(circle?.Teacher?.WhatsappNumber)?circle?.Teacher?.Contact??"":circle.Teacher.WhatsappNumber,
                completedAjzaaCount=ReportService.CompletedParts(s),targetAjzaaCount=s.TargetAjzaaCount,
                totalSessions=rec.Count,presentCount=att.Count(a=>a.Status==AttendanceStatus.Present),
                absentCount=att.Count(a=>a.Status==AttendanceStatus.Absent),excusedAbsentCount=att.Count(a=>a.Status==AttendanceStatus.ExcusedAbsent),lateCount=att.Count(a=>a.Status==AttendanceStatus.Late),
                attendanceRate=att.Count==0?(double?)null:ReportService.Percentage(att.Count(a=>a.Status is AttendanceStatus.Present or AttendanceStatus.Late),att.Count),
                newPages=Math.Round(rec.Where(r=>r.RecitationType==RecitationType.Memorization).Sum(ReportService.Pages),2),
                reviewPages=Math.Round(rec.Where(r=>r.RecitationType!=RecitationType.Memorization).Sum(ReportService.Pages),2),
                talentsCount=talents.GetValueOrDefault(s.Id),
                recentSessions=rec.Take(5).Select(r=>new {date=r.SessionDate.ToString("yyyy-MM-dd"),surah=r.SurahName,type=SessionService.RecitationTypeText(r.RecitationType),pages=ReportService.Pages(r),assessment=SessionService.AssessmentText(r.Assessment)}),
                recentAttendance=att.Take(5).Select(a=>new {date=a.SessionDate.ToString("yyyy-MM-dd"),status=a.Status switch {AttendanceStatus.Present=>"حاضر",AttendanceStatus.Late=>"متأخر",AttendanceStatus.ExcusedAbsent=>"غائب بعذر",_=>"غائب دون عذر"}}),
                courses=enrollments.Where(e=>e.StudentId==s.Id).Select(e=>new {id=e.CourseId,name=e.Course?.Name??"دورة",teacherName=e.Course?.Teacher?.FullName??"لم يحدد",status=evaluatedKeys.Contains((e.StudentId,(int?)e.CourseId))?e.Status switch {"Passed"=>"ناجح","Certified"=>"معتمد","Failed"=>"لم يجتز",_=>"مسجل"}:"مسجل",grade=evaluatedKeys.Contains((e.StudentId,(int?)e.CourseId))?e.Grade:null})
            };
        }).ToList();
        return new {from=from.ToString("yyyy-MM-dd"),to=to.ToString("yyyy-MM-dd"),today=today.ToString("yyyy-MM-dd"),
            summary=new {childrenCount=children.Count,totalSessions=children.Sum(c=>c.totalSessions),absentCount=children.Sum(c=>c.absentCount),excusedAbsentCount=children.Sum(c=>c.excusedAbsentCount)},children};
    }
}
