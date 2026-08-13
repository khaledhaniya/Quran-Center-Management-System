namespace QuranCircles.Api.Entities;

public class CourseEnrollment
{
    public int Id { get; set; }
    
    public int CourseId { get; set; }
    public Course? Course { get; set; }
    
    public int StudentId { get; set; }
    public Student? Student { get; set; }
    
    public double? Grade { get; set; }
    
    // Enrolled, Passed, Failed, Certified
    public string Status { get; set; } = "Enrolled";
    
    public string? CertificateCode { get; set; }
    
    public DateOnly EnrollmentDate { get; set; } = DateOnly.FromDateTime(DateTime.Today);
    public DateOnly? CertificateDate { get; set; }
}
