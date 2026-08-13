namespace QuranCircles.Api.Entities;

public class Attendance
{
    public int Id { get; set; }

    public int StudentId { get; set; }
    public Student? Student { get; set; }

    public int CircleId { get; set; }
    public Circle? Circle { get; set; }

    public DateOnly SessionDate { get; set; }
    public AttendanceStatus Status { get; set; }
}
