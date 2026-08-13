namespace QuranCircles.Api.Entities;

public class HadithSession
{
    public int Id { get; set; }
    
    public int StudentId { get; set; }
    public Student? Student { get; set; }
    
    public string HadithBook { get; set; } = string.Empty; // e.g. "الأربعين النووية"
    public int HadithNumber { get; set; }
    
    public DateOnly SessionDate { get; set; } = DateOnly.FromDateTime(DateTime.Today);
    public int Points { get; set; } = 10; // e.g. 10 points per hadith
    
    public string? Notes { get; set; }
}
