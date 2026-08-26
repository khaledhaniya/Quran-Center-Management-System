using System;

namespace QuranCircles.Api.Entities;

public class SystemSettings
{
    public int Id { get; set; } = 1;

    // 1. Institutional Identity & Contact
    public string CenterName { get; set; } = "مركز البيان لتعليم القرآن الكريم وتدريس علومه";
    public string MosqueName { get; set; } = "مسجد علي بن أبي طالب";
    public string CenterAddress { get; set; } = "فلسطين - غزة - المقر الرئيسي";
    public string SupportPhone { get; set; } = "+970599000000";
    public string SupportEmail { get; set; } = "info@albayan.quran";
    public string WelcomeMessage { get; set; } = "أهلاً وسهلاً بكم في منصة مركز البيان لتعليم القرآن الكريم والعلوم الشرعية";

    // 2. Academic & Quranic Standards
    public int PassingScoreThreshold { get; set; } = 70;
    public int MinAttendancePercentForExam { get; set; } = 75;
    public int MaxStudentsPerCircle { get; set; } = 20;
    public int MaxAbsenceDaysWarning { get; set; } = 3;

    // 3. Security, Permissions & Access Control
    public bool AllowTeacherEditStudentPlan { get; set; } = true;
    public bool AllowTeacherSelfEnrollment { get; set; } = true;
    public bool HideParentPhoneFromTeacher { get; set; } = false;
    public bool AllowStudentProfileEditRequests { get; set; } = true;
    public bool EnforceDailyAttendanceRecording { get; set; } = true;
    public bool ShowStudentCountToTeacher { get; set; } = true;
    public bool ShowCumulativeAttendance { get; set; } = true;

    // 4. Certificates & Recognition
    public bool EnableCertificates { get; set; } = true;
    public string SignatoryName { get; set; } = "فضيلة الشيخ / رئيس المركز";
    public string SignatoryTitle { get; set; } = "المشرف العام على حلقات تحفيظ القرآن الكريم";
    public bool ShowHonorsBoard { get; set; } = true;

    // 5. Alerts & Communication
    public bool AllowPublicAnnouncements { get; set; } = true;
    public bool EnableAbsenceAutoAlert { get; set; } = true;
    public string AbsenceAlertTemplate { get; set; } = "نود إشعاركم بغياب الطالب/ة اليوم عن حلقة القرآن الكريم، نرجو المتابعة مع إدارة المركز.";

    // 6. UI & Appearance
    public string ThemeStyle { get; set; } = "Classic"; // Classic, Modern, Sapphire, Dark
    public bool MaintenanceMode { get; set; } = false;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
