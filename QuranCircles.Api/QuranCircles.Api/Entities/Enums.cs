namespace QuranCircles.Api.Entities;

public enum AssessmentLevel
{
    Excellent = 1,
    VeryGood = 2,   
    Good = 3,   
    Medium = 4,   
    Rejected = 5  
}

public enum AttendanceStatus
{
    Present = 1,   
    Absent = 2,    
    Late = 3        
}

public enum SessionTiming
{
    Fajr = 1,
    Aser = 2,       
    Maghrib = 3,    
    Isha = 4
}

public enum UserRole
{
    Admin = 1,
    Teacher = 2,
    Student = 3,
    Parent = 4,
    Developer = 5,
    ExamSupervisor = 6
}

public enum AnnouncementTarget
{
    All = 1,
    Circle = 2,
    Teacher = 3,
    Student = 4,
    AllTeachers = 5,
    Admin = 6,
    Parent = 7
}


