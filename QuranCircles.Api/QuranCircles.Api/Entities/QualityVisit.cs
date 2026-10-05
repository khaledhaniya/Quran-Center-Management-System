using System;

namespace QuranCircles.Api.Entities;

public class QualityVisit
{
    public int Id { get; set; }
    public int CircleId { get; set; }
    public Circle? Circle { get; set; }
    public string SupervisorName { get; set; } = string.Empty;
    public DateOnly VisitDate { get; set; } = DateOnly.FromDateTime(DateTime.Today);
    public int PunctualityScore { get; set; } = 100; // 0-100
    public int ClassManagementScore { get; set; } = 100; // 0-100
    public int TajweedCorrectionScore { get; set; } = 100; // 0-100
    public int OverallQualityScore { get; set; } = 100;
    public string? Notes { get; set; }
    public string? SpotCheckedStudentsJson { get; set; }
    public bool IsSubstituteModeActive { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
