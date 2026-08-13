namespace QuranCircles.Api.Entities;

public class Circle
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public SessionTiming Timing { get; set; }
    public bool IsActive { get; set; } = true;

    public int? TeacherId { get; set; }
    public Teacher? Teacher { get; set; }

    public ICollection<Student> Students { get; set; } = new List<Student>();
}
