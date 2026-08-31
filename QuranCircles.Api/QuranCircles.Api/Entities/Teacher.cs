namespace QuranCircles.Api.Entities;

public class Teacher
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public DateOnly DateOfBirth { get; set; }
    public string Contact { get; set; } = string.Empty;
    public DateOnly RegistrationDate { get; set; }
    public bool IsActive { get; set; } = true;

    // Full 29-8 Center Database Columns
    public string? IdentityNumber { get; set; }
    public string? WhatsappNumber { get; set; }
    public string? SocialStatus { get; set; }
    public int? FamilyMembersCount { get; set; }
    public string? MosqueName { get; set; }
    public string? Qualification { get; set; }
    public string? TaskRole { get; set; }
    public string? WalletNumber { get; set; }
    public string? WalletOwner { get; set; }
    public string? MemorizedAjzaa { get; set; }
    public string? StudentsCountTarget { get; set; }

    public ICollection<Circle> Circles { get; set; } = new List<Circle>();
}
