using System;

namespace QuranCircles.Api.Entities;

public class SystemSettings
{
    public int Id { get; set; } = 1;
    public string CenterName { get; set; } = "مركز البيان لتعليم القرآن الكريم وتدريس علومه";
    public string MosqueName { get; set; } = "مسجد علي بن أبي طالب";
    public bool ShowStudentCountToTeacher { get; set; } = true;
    public bool ShowCumulativeAttendance { get; set; } = true;
    public bool AllowTeacherSelfEnrollment { get; set; } = true;
    public bool AllowPublicAnnouncements { get; set; } = true;
    public bool EnableCertificates { get; set; } = true;
    public string SupportPhone { get; set; } = "0599000000";
    public string WelcomeMessage { get; set; } = "أهلاً وسهلاً بكم في نظام مركز البيان لتعليم القرآن الكريم";
    public string ThemeStyle { get; set; } = "Classic";
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
