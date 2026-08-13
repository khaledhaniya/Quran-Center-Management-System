namespace QuranCircles.Api.Entities;

public class Student
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public DateOnly DateOfBirth { get; set; }
    public string FamilyContact { get; set; } = string.Empty;
    public DateOnly RegistrationDate { get; set; }
    public bool IsActive { get; set; } = true;

    public int? CircleId { get; set; }
    public Circle? Circle { get; set; }

    public int? ParentId { get; set; }

    // Extended Excel Fields
    public string? StudentIdentityNumber { get; set; }
    public string? PreviousQuranMemorization { get; set; }
    public string? StudentMobile { get; set; }
    public string? StudentWhatsapp { get; set; }
    public string? HealthStatus { get; set; }
    public string? FatherStatus { get; set; }
    public string? MotherStatus { get; set; }
    public string? Kinship { get; set; }
    public string? ParentIdentityNumber { get; set; }
    public string? WhatsappNumber { get; set; }
    public string? WalletNumber { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankName { get; set; }
    public string? OriginalAddress { get; set; }
    public string? OriginalHousingType { get; set; }
    public string? OriginalHousingStatus { get; set; }
    public string? CurrentAddress { get; set; }
    public string? CurrentHousingType { get; set; }
    public string? Notes { get; set; }

    // العلاقات
    public ICollection<RecitationSession> Sessions { get; set; } = new List<RecitationSession>();
    public ICollection<Attendance> AttendanceRecords { get; set; } = new List<Attendance>();
}
