namespace QuranCircles.Api.DTOs;

using System;
using System.Collections.Generic;
using QuranCircles.Api.Entities;

// ====================== Student ======================
public record CreateStudentDto(
    string FullName,
    string? Address,
    DateOnly? DateOfBirth,
    string? FamilyContact,
    int? CircleId,
    int? ParentId,
    string? Username,
    string? Password,
    string? StudentIdentityNumber = null,
    string? PreviousQuranMemorization = null,
    string? StudentMobile = null,
    string? StudentWhatsapp = null,
    string? HealthStatus = null,
    string? FatherStatus = null,
    string? MotherStatus = null,
    string? Kinship = null,
    string? ParentIdentityNumber = null,
    string? WhatsappNumber = null,
    string? WalletNumber = null,
    string? BankAccountNumber = null,
    string? BankName = null,
    string? OriginalAddress = null,
    string? OriginalHousingType = null,
    string? OriginalHousingStatus = null,
    string? CurrentAddress = null,
    string? CurrentHousingType = null,
    string? Notes = null,
    string? ParentName = null
);

public record UpdateStudentDto(
    string? FullName = null,
    string? Address = null,
    DateOnly? DateOfBirth = null,
    string? FamilyContact = null,
    int? CircleId = null,
    int? ParentId = null,
    bool? IsActive = null,
    string? StudentIdentityNumber = null,
    string? PreviousQuranMemorization = null,
    string? StudentMobile = null,
    string? StudentWhatsapp = null,
    string? HealthStatus = null,
    string? FatherStatus = null,
    string? MotherStatus = null,
    string? Kinship = null,
    string? ParentIdentityNumber = null,
    string? WhatsappNumber = null,
    string? WalletNumber = null,
    string? BankAccountNumber = null,
    string? BankName = null,
    string? OriginalAddress = null,
    string? OriginalHousingType = null,
    string? OriginalHousingStatus = null,
    string? CurrentAddress = null,
    string? CurrentHousingType = null,
    string? Notes = null,
    string? ParentName = null,
    int? TargetAjzaaCount = null,
    string? PlanType = null,
    DateOnly? PlanStartDate = null,
    DateOnly? PlanTargetDate = null,
    double? DailyPacePages = null,
    string? CompletedAjzaa = null
);

public record StudentDto(
    int Id,
    string FullName,
    string? Address,
    DateOnly? DateOfBirth,
    string? FamilyContact,
    DateOnly RegistrationDate,
    bool IsActive,
    int? CircleId,
    string? CircleName,
    int? ParentId,
    string? StudentIdentityNumber = null,
    string? PreviousQuranMemorization = null,
    string? StudentMobile = null,
    string? StudentWhatsapp = null,
    string? HealthStatus = null,
    string? FatherStatus = null,
    string? MotherStatus = null,
    string? Kinship = null,
    string? ParentIdentityNumber = null,
    string? WhatsappNumber = null,
    string? WalletNumber = null,
    string? BankAccountNumber = null,
    string? BankName = null,
    string? OriginalAddress = null,
    string? OriginalHousingType = null,
    string? OriginalHousingStatus = null,
    string? CurrentAddress = null,
    string? CurrentHousingType = null,
    string? Notes = null
);

// ====================== Teacher ======================
public record CreateTeacherDto(
    string FullName,
    string? Address,
    DateOnly? DateOfBirth,
    string? Contact,
    string? Username,
    string? Password,
    string? IdentityNumber = null,
    string? WhatsappNumber = null,
    string? SocialStatus = null,
    int? FamilyMembersCount = null,
    string? MosqueName = null,
    string? Qualification = null,
    string? TaskRole = null,
    string? WalletNumber = null,
    string? WalletOwner = null,
    string? MemorizedAjzaa = null,
    string? StudentsCountTarget = null
);

public record UpdateTeacherDto(
    string? FullName = null,
    string? Address = null,
    DateOnly? DateOfBirth = null,
    string? Contact = null,
    bool? IsActive = null,
    string? IdentityNumber = null,
    string? WhatsappNumber = null,
    string? SocialStatus = null,
    int? FamilyMembersCount = null,
    string? MosqueName = null,
    string? Qualification = null,
    string? TaskRole = null,
    string? WalletNumber = null,
    string? WalletOwner = null,
    string? MemorizedAjzaa = null,
    string? StudentsCountTarget = null
);

public record TeacherDto(
    int Id,
    string FullName,
    string? Address,
    DateOnly? DateOfBirth,
    string? Contact,
    DateOnly RegistrationDate,
    bool IsActive,
    string? IdentityNumber = null,
    string? WhatsappNumber = null,
    string? SocialStatus = null,
    int? FamilyMembersCount = null,
    string? MosqueName = null,
    string? Qualification = null,
    string? TaskRole = null,
    string? WalletNumber = null,
    string? WalletOwner = null,
    string? MemorizedAjzaa = null,
    string? StudentsCountTarget = null
);

// ====================== Circle ======================
public record CreateCircleDto(
    string Name,
    SessionTiming Timing,
    int? TeacherId,
    int? AssistantTeacherId = null
);

public record UpdateCircleDto(
    string Name,
    SessionTiming Timing,
    int? TeacherId,
    bool IsActive,
    int? AssistantTeacherId = null
);

public record CircleDto(
    int Id,
    string Name,
    SessionTiming Timing,
    bool IsActive,
    int? TeacherId,
    string? TeacherName,
    int? AssistantTeacherId,
    string? AssistantTeacherName,
    int StudentCount,
    List<StudentBriefDto>? Students
);

public record StudentBriefDto(int Id, string FullName);

public record AssignStudentDto(int StudentId);

// ====================== Exams DTOs ======================
public class CreateNominationDto
{
    public int StudentId { get; set; }
    public string NominationType { get; set; } = "Quran";
    public int? CourseId { get; set; }
    public int? JuzStart { get; set; }
    public int? JuzEnd { get; set; }
}

public class ScheduleExamDto
{
    public int NominationId { get; set; }
    public DateTime ExamDate { get; set; }
}

public class EvaluateExamDto
{
    public int NominationId { get; set; }
    public int MajorMistakes { get; set; }
    public int MinorMistakes { get; set; }
    public double Grade { get; set; }
    public string? Notes { get; set; }
}
