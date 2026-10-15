namespace QuranCircles.Api.Services;

public static class CenterClock
{
    public static DateTime Now
    {
        get
        {
            var zone = Environment.GetEnvironmentVariable("CENTER_TIME_ZONE") ?? "Asia/Hebron";
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(zone));
        }
    }
    public static DateOnly Today => DateOnly.FromDateTime(Now);
}
