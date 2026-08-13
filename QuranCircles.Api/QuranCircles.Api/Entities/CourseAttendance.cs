namespace QuranCircles.Api.Entities;

public class CourseAttendance
{
    public int Id { get; set; }
    
    public int StudentId { get; set; }
    public Student? Student { get; set; }
    
    public int CourseId { get; set; }
    public Course? Course { get; set; }
    
    public DateOnly SessionDate { get; set; }
    public AttendanceStatus Status { get; set; }
}
