namespace QuranCircles.Api.Entities;

using System;

public class ProfileUpdateRequest
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int? StudentId { get; set; }
    public string RequestedByRole { get; set; } = "Student"; // Student or Parent
    public string RequestedByName { get; set; } = string.Empty;
    public string ChangesJson { get; set; } = string.Empty; // JSON dictionary of requested changes
    public string Status { get; set; } = "Pending"; // Pending, Approved, Rejected
    public DateTime RequestDate { get; set; } = DateTime.UtcNow;
    public string? ReviewerNotes { get; set; }
    public DateTime? ReviewDate { get; set; }
}
