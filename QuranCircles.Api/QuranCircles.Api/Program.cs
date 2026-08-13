using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://0.0.0.0:5070");

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlite(builder.Configuration.GetConnectionString("Default") ?? "Data Source=quran.db"));

builder.Services.AddScoped<QuranCircles.Api.Services.StudentService>();
builder.Services.AddScoped<QuranCircles.Api.Services.TeacherService>();
builder.Services.AddScoped<QuranCircles.Api.Services.CircleService>();
builder.Services.AddScoped<QuranCircles.Api.Services.SessionService>();
builder.Services.AddScoped<QuranCircles.Api.Services.AttendanceService>();
builder.Services.AddScoped<QuranCircles.Api.Services.ReportService>();
builder.Services.AddScoped<QuranCircles.Api.Services.AnnouncementService>();
builder.Services.AddSingleton<QuranCircles.Api.Services.PasswordHasher>();
builder.Services.AddSingleton<QuranCircles.Api.Services.TokenService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddControllers()
    .AddJsonOptions(opt =>
        opt.JsonSerializerOptions.Converters.Add(
            new System.Text.Json.Serialization.JsonStringEnumConverter()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var hasher = scope.ServiceProvider.GetRequiredService<QuranCircles.Api.Services.PasswordHasher>();
    db.Database.EnsureCreated();
    DbSeeder.Seed(db, hasher);
}

app.UseCors("AllowAll");

app.MapControllers();

app.Run();