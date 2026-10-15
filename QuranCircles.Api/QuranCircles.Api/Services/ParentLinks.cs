using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Services;

// One definition for the parent audit, dashboards and teacher removal.
public static class ParentLinks
{
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
