using QuranCircles.Api.Entities;
using QuranCircles.Api.Data;

namespace QuranCircles.Api.Services;

// One definition for the parent audit, dashboards and teacher removal.
public static class ParentLinks
{
    public static IQueryable<Student> ChildrenQuery(AppDbContext db, User user)
    {
        var ids=new[] {user.Id,user.ParentId??user.Id}.Distinct().ToArray();
        var username=user.Username.Trim();var identity=user.Teacher?.IdentityNumber?.Trim()??"";
        return db.Students.Where(s=>s.ParentId.HasValue?ids.Contains(s.ParentId.Value):
            s.ParentIdentityNumber!=null&&s.ParentIdentityNumber.Trim()!=""&&
            (s.ParentIdentityNumber.Trim()==username||(identity!=""&&s.ParentIdentityNumber.Trim()==identity)));
    }
    public static bool IsChild(User parent, Student child)
    {
        if (child.ParentId.HasValue)
            return child.ParentId == parent.Id || child.ParentId == parent.ParentId;
        var identity = child.ParentIdentityNumber?.Trim();
        if (!string.IsNullOrEmpty(identity))
            return identity == parent.Username.Trim() || identity == parent.Teacher?.IdentityNumber?.Trim();
        return false; // A shared telephone number alone is not proof of guardianship.
    }
}
