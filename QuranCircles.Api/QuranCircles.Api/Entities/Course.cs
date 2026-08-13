using System.Text.Json.Serialization;

namespace QuranCircles.Api.Entities;

public class Course
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    
    public int? TeacherId { get; set; }
    public Teacher? Teacher { get; set; }
    
    public int? ExamSupervisorId { get; set; }
    public User? ExamSupervisor { get; set; }
    
    public bool IsActive { get; set; } = true;

    [JsonIgnore]
    public ICollection<CourseEnrollment> Enrollments { get; set; } = new List<CourseEnrollment>();
}
