namespace QuranCircles.Api.Entities;

public class CirclePlan
{
    public int Id { get; set; }
    public int CircleId { get; set; }
    public int? CourseId { get; set; }
    public string Title { get; set; } = "";
    public string Track { get; set; } = "Quran";
    public string Unit { get; set; } = "صفحة";
    public DateOnly StartsOn { get; set; }
    public DateOnly EndsOn { get; set; }
    public decimal Target { get; set; }
    public decimal Completed { get; set; }
    public string Notes { get; set; } = "";
    public int UpdatedByUserId { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class CircleSchedule
{
    public int Id { get; set; }
    public int CircleId { get; set; }
    // ISO weekdays: Monday=1 ... Sunday=7; centre-local wall clock.
    public string Weekdays { get; set; } = "1,2,3,4,7";
    public string StartTime { get; set; } = "16:00";
    public int DurationMinutes { get; set; } = 60;
    public int Capacity { get; set; } = 20;
    public int? SupervisorUserId { get; set; }
}

public class CircleDay
{
    public int Id { get; set; }
    public int CircleId { get; set; }
    public DateOnly Date { get; set; }
    public int? TeacherId { get; set; }
    public DateTime? OpenedAt { get; set; }
    public DateTime? ClosedAt { get; set; }
    public string Status { get; set; } = "Pending";
    public int? SubstituteUserId { get; set; }
    public string Reason { get; set; } = "";
    public int UpdatedByUserId { get; set; }
    public bool LateAlertSent { get; set; }
}
