using System.Text.Json.Serialization;

namespace QuranCircles.Api.Entities;

public class ExamResult
{
    public int Id { get; set; }
    
    public int ExamNominationId { get; set; }
    
    [JsonIgnore]
    public ExamNomination? ExamNomination { get; set; }
    
    public int ExaminerId { get; set; } // User ID of examiner
    
    public int MajorMistakes { get; set; } // اللحن الجلي
    public int MinorMistakes { get; set; } // اللحن الخفي
    
    public double Grade { get; set; }
    public string? Notes { get; set; }
    
    public DateTime ExamDate { get; set; } = DateTime.Now;
}
