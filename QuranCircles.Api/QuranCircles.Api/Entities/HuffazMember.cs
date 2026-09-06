using System.Text.Json.Serialization;

namespace QuranCircles.Api.Entities;

public class HuffazMember
{
    public int Id { get; set; }

    /// <summary>
    /// صفة العضو: "Teacher" معلم بالمركز، "Student" طالب بالمركز، "External" شخص/حافظ خارجي
    /// </summary>
    public string MemberType { get; set; } = "Student";

    /// <summary>
    /// المعلم المرتبط في حال كان العضو معلماً بالمركز
    /// </summary>
    public int? TeacherId { get; set; }
    public Teacher? Teacher { get; set; }

    /// <summary>
    /// الطالب المرتبط في حال كان العضو طالباً بالمركز
    /// </summary>
    public int? StudentId { get; set; }
    public Student? Student { get; set; }

    /// <summary>
    /// الاسم الكامل للحافظ
    /// </summary>
    public string FullName { get; set; } = string.Empty;

    /// <summary>
    /// رقم الهوية
    /// </summary>
    public string? IdentityNumber { get; set; }

    /// <summary>
    /// رقم الهاتف / الواتساب
    /// </summary>
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// كم يحفظ من أجزاء القرآن الكريم (1 إلى 30)
    /// </summary>
    public int MemorizedAjzaaCount { get; set; } = 30;

    /// <summary>
    /// هل أتم حفظ القرآن الكريم كاملاً؟
    /// </summary>
    public bool IsKhatim { get; set; } = true;

    /// <summary>
    /// الرواية أو القراءة أو السند (حفص، ورش، قالون، القراءات العشر...)
    /// </summary>
    public string? Riwayah { get; set; }

    /// <summary>
    /// الشيخ المشرف على المراجعة والتثبيت (يحدد من معلمين المركز المخصصين في الصلاحيات)
    /// </summary>
    public int? SupervisorTeacherId { get; set; }
    public Teacher? SupervisorTeacher { get; set; }

    /// <summary>
    /// خطة المراجعة والتثبيت (سرد 5 أجزاء أسبوعياً، جزء يومي، مقرأة مسائية...)
    /// </summary>
    public string? RevisionPlan { get; set; }

    /// <summary>
    /// ملاحظات وتوصيات
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// تاريخ الانضمام للمنتدى
    /// </summary>
    public DateOnly JoinDate { get; set; } = DateOnly.FromDateTime(DateTime.Today);

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
