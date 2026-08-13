namespace QuranCircles.Api.DTOs;

using System;
using QuranCircles.Api.Entities;

public record CreateAnnouncementDto(
    string Title,
    string Content,
    AnnouncementTarget TargetType,
    int? TargetId
);

public record AnnouncementDto(
    int Id,
    string Title,
    string Content,
    DateTime DateTimeSent,
    AnnouncementTarget TargetType,
    int? TargetId,
    string TargetName,
    string SenderName
);
