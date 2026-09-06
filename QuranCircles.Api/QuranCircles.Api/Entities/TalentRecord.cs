using System.Text.Json.Serialization;

namespace QuranCircles.Api.Entities;

public class TalentRecord
{
    public int Id { get; set; }

    public int StudentId { get; set; }
    public Student? Student { get; set; }

    /// <summary>
    /// نوع الموهبة: الفتى الواعظ - فن الخطابة، الأصوات الندية - تلاوة خاشعة، الأصوات الندية - أذان وإقامة، الإمامة المحرابية، الإنشاد الديني
    /// </summary>
    public string TalentType { get; set; } = string.Empty;

    /// <summary>
    /// عنوان الخطبة أو الموعظة أو السورة / نوع الأذان
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// طريقة التحضير (بحث ومطالعة ذاتية، تدريب ومتابعة مع الشيخ المشرف، تلقين وتدريب منزلي...)
    /// </summary>
    public string? PreparationMethod { get; set; }

    /// <summary>
    /// نص أو عناصر ومحاور الخطبة التي سيقولها الطالب
    /// </summary>
    public string? SpeechContent { get; set; }

    /// <summary>
    /// المناسبة ومكان الإلقاء (منبر الجمعة التجريبي، موعظة بعد العصر، كلمة طابور...)
    /// </summary>
    public string? Occasion { get; set; }

    /// <summary>
    /// تاريخ الإلقاء أو التسجيل
    /// </summary>
    public DateOnly EventDate { get; set; } = DateOnly.FromDateTime(DateTime.Today);

    /// <summary>
    /// الشيخ المشرف والموجه للموهبة
    /// </summary>
    public int? SupervisorTeacherId { get; set; }
    public Teacher? SupervisorTeacher { get; set; }

    /// <summary>
    /// رابط الفيديو أو الصورة أو التسجيل الصوتي
    /// </summary>
    public string? MediaUrl { get; set; }

    /// <summary>
    /// نوع الوسيط: video, audio, image, link
    /// </summary>
    public string? MediaType { get; set; } = "video";

    /// <summary>
    /// التقييم أو الدرجة (مثال: ممتاز، 95%)
    /// </summary>
    public string? EvaluationScore { get; set; }

    /// <summary>
    /// ملاحظات الأداء والفصاحة والخشوع والتوجيهات
    /// </summary>
    public string? PerformanceNotes { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
