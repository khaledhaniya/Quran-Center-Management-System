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

    public ICollection<Circle> Circles { get; set; } = new List<Circle>();
}
