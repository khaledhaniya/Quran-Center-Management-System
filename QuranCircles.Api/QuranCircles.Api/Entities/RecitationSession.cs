namespace QuranCircles.Api.Entities;

public class RecitationSession
{
    public int Id { get; set; }

    public int StudentId { get; set; }
    public Student? Student { get; set; }

    public DateOnly SessionDate { get; set; }

    public string SurahName { get; set; } = string.Empty;
    public int FromVerse { get; set; }
    public int ToVerse { get; set; }

    public AssessmentLevel Assessment { get; set; }
    public string? Notes { get; set; }

    public bool ViaLottery { get; set; }
}
