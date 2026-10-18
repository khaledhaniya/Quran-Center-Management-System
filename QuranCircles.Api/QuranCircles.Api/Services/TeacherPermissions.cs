using System.Text.RegularExpressions;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace QuranCircles.Api.Services;

public static class TeacherPermissions
{
    public static string[] FromTasks(string? tasks)
    {
        var text=Regex.Replace(tasks??"", "[\u064B-\u065F\u0670\u0640]", "").Replace('أ','ا').Replace('إ','ا').Replace('آ','ا').ToLowerInvariant();
        bool Has(params string[] words)=>words.Any(text.Contains);
        var result=new List<string>();
        if(Has("حلقة","حلقات","محفظ","معلم قران"))result.Add("circles");
        if(Has("دورة","دورات","مساق","مساقات","course"))result.Add("courses");
        if(Has("اختبار","امتحان","لجنة"))result.Add("exams");
        if(Has("المالي","الصندوق","المحافظ"))result.Add("finance");
        if(Has("الجودة","رقابة"))result.Add("quality");
        if(Has("التحفيظ","الحفاظ"))result.Add("memorization");
        if(Has("الواعظ","الندية"))result.Add("talents");
        if(Has("مركز البيان","امير المركز","المدير العام"))result.Add("leadership");
        return result.ToArray();
    }
    public static string[] For(Teacher? teacher)=>teacher?.IsActive==true?FromTasks(teacher.TaskRole):[];
    public static async Task ResolveLinkAsync(AppDbContext db, User user)
    {
        if(user.TeacherId.HasValue||user.Role==UserRole.Student||string.IsNullOrWhiteSpace(user.Username))return;
        var identity=user.Username.Trim();
        var matches=await db.Teachers.Where(t=>t.IsActive&&t.IdentityNumber!=null&&t.IdentityNumber.Trim()==identity).Take(2).ToListAsync();
        if(matches.Count!=1)return;
        user.TeacherId=matches[0].Id;user.Teacher=matches[0];await db.SaveChangesAsync();
    }
}
