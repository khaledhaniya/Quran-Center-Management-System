namespace QuranCircles.Api.DTOs;

using QuranCircles.Api.Entities;

// ====================== Recitation Session ======================
public record CreateSessionDto(
    int StudentId,
    DateOnly SessionDate,
    string SurahName,
    int FromVerse,
    int ToVerse,
    AssessmentLevel Assessment,
    string? Notes,
    bool ViaLottery
);

public record UpdateSessionDto(
    DateOnly SessionDate,
    string SurahName,
    int FromVerse,
    int ToVerse,
    AssessmentLevel Assessment,
    string? Notes
);

public record SessionDto(
    int Id,
    int StudentId,
    string StudentName,
    DateOnly SessionDate,
    string SurahName,
    int FromVerse,
    int ToVerse,
    AssessmentLevel Assessment,
    string AssessmentText,
    string? Notes,
    bool ViaLottery
);

// نتيجة القرعة (اللوتري)
public record LotteryResultDto(
    int StudentId,
    string StudentName,
    int CircleId,
    string CircleName
);

// ====================== Attendance ======================
public record RecordAttendanceDto(
    int StudentId,
    int CircleId,
    DateOnly SessionDate,
    AttendanceStatus Status
);

public record AttendanceDto(
    int Id,
    int StudentId,
    string StudentName,
    int CircleId,
    string CircleName,
    DateOnly SessionDate,
    AttendanceStatus Status,
    string StatusText
);

// ====================== Reports ======================
public record SummaryReportDto(
    DateOnly From,
    DateOnly To,
    int TotalStudents,
    int TotalTeachers,
    int TotalCircles,
    int TotalSessions,
    int TotalVersesRecited,
    int StudentAbsenceCount,
    Dictionary<string, int> AssessmentBreakdown   // مثل: { "ممتاز": 12, "جيد": 5 }
);

// ====================== Parent (read-only) ======================
public record ChildProgressDto(
    int StudentId,
    string StudentName,
    string? CircleName,
    int TotalSessions,
    int AbsenceCount,
    int LateCount,
    List<SessionDto> RecentSessions
);
