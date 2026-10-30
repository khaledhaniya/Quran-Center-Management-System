using Microsoft.AspNetCore.Mvc.Filters;

namespace QuranCircles.Api.Data;

/// <summary>Serializes identity and account edits within this server process.</summary>
[AttributeUsage(AttributeTargets.Method)]
public sealed class IdentityMutationAttribute : Attribute, IAsyncActionFilter
{
    private static readonly SemaphoreSlim Gate = new(1, 1);

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        await Gate.WaitAsync(context.HttpContext.RequestAborted);
        try { await next(); }
        finally { Gate.Release(); }
    }
}
