namespace QuranCircles.Api.Entities;

public class ExamNomination
{
    public int Id { get; set; }
    
    public int StudentId { get; set; }
    public Student? Student { get; set; }
    
    public int TeacherId { get; set; }
    public Teacher? Teacher { get; set; }
    
    // "Quran" or "Course"
    public string NominationType { get; set; } = "Quran";
    
    public int? CourseId { get; set; }
    public Course? Course { get; set; }
    
    public int? JuzStart { get; set; }
    public int? JuzEnd { get; set; }
    
    // Pending, Scheduled, Completed, Cancelled
    public string Status { get; set; } = "Pending";
    
    public DateOnly NominationDate { get; set; } = DateOnly.FromDateTime(DateTime.Today);
    public DateTime? ExamDate { get; set; }
    
    public ExamResult? Result { get; set; }
}
