using System;

namespace QuranCircles.Api.Entities;

public class Announcement
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public DateTime DateTimeSent { get; set; } = DateTime.UtcNow;
    public AnnouncementTarget TargetType { get; set; }
    public int? TargetId { get; set; }
    public string SenderName { get; set; } = string.Empty;
}
