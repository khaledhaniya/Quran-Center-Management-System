namespace QuranCircles.Api.Entities;

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    [System.Text.Json.Serialization.JsonIgnore]
    public string PasswordHash { get; set; } = string.Empty;
    [System.Text.Json.Serialization.JsonIgnore]
    public string PlainPassword { get; set; } = string.Empty;
    public UserRole Role { get; set; }
    public string FullName { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public int TokenVersion { get; set; }

    // Optional links
    public int? TeacherId { get; set; }
    public Teacher? Teacher { get; set; }

    public int? StudentId { get; set; }
    public Student? Student { get; set; }

    public int? ParentId { get; set; }
}
