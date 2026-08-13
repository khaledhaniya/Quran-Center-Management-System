namespace QuranCircles.Api.Entities;

public class AuditLog
{
    public int Id { get; set; }
    
    public string Username { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty; // e.g. "UpdateGrade", "NominateStudent", "IssueCertificate"
    public string Details { get; set; } = string.Empty;
    
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string IpAddress { get; set; } = string.Empty;
}
