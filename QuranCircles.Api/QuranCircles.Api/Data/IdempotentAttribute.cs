using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Entities;

namespace QuranCircles.Api.Data;

/// Stores the mutation and its receipt in the same database transaction.
[AttributeUsage(AttributeTargets.Method)]
public sealed class IdempotentAttribute : Attribute, IAsyncActionFilter
{
    private static readonly SemaphoreSlim Gate = new(1, 1);

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var key = context.HttpContext.Request.Headers["Idempotency-Key"].ToString();
        if (string.IsNullOrEmpty(key)) { await next(); return; }
        var userId = FakeAuth.GetUserId(context.HttpContext);
        if (userId == null) { context.Result = new UnauthorizedResult(); return; }
        if (key.Length > 128 || key.Any(char.IsControl)) {
            context.Result = new BadRequestObjectResult(new { error = "مفتاح العملية غير صالح." }); return;
        }
        var db = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
        var options = context.HttpContext.RequestServices.GetRequiredService<Microsoft.Extensions.Options.IOptions<JsonOptions>>().Value.JsonSerializerOptions;
        var receiptId = Hash($"{userId}:{context.HttpContext.Request.Path}:{key}");
        var bodyHash = Hash(JsonSerializer.Serialize(context.ActionArguments, options));
        await Gate.WaitAsync(context.HttpContext.RequestAborted);
        try
        {
            var receipt = await db.IdempotencyReceipts.AsNoTracking().FirstOrDefaultAsync(r => r.Id == receiptId);
            if (receipt != null)
            {
                context.Result = receipt.RequestHash == bodyHash
                    ? receipt.StatusCode == 204
                        ? new NoContentResult()
                        : new ContentResult { Content = receipt.ResponseJson, ContentType = "application/json; charset=utf-8", StatusCode = receipt.StatusCode }
                    : new ConflictObjectResult(new { error = "استُخدم مفتاح العملية مع بيانات مختلفة." });
                return;
            }
            // SQL Server retry strategies require explicit transactions inside ExecuteAsync.
            var invoked = false;
            await db.Database.CreateExecutionStrategy().ExecuteAsync(async () => {
                // MVC action delegates cannot safely be re-entered on a DB retry.
                // A retry is made as a new HTTP request with the same operation key.
                if (invoked) throw new InvalidOperationException("Retry this request with the same Idempotency-Key.");
                invoked = true;
                await using var transaction = await db.Database.BeginTransactionAsync();
                var executed = await next();
                if (executed.Exception != null && !executed.ExceptionHandled) return;
                // Several successful write endpoints return 204 (NoContentResult).
                // Without a receipt and commit here, disposing the transaction undoes
                // the write even though the client has already received success.
                var statusCode = executed.Result switch
                {
                    ObjectResult result => result.StatusCode ?? 200,
                    StatusCodeResult result => result.StatusCode,
                    ContentResult result => result.StatusCode ?? 200,
                    EmptyResult => 200,
                    _ => 0
                };
                if (statusCode is >= 200 and < 300)
                {
                    db.IdempotencyReceipts.Add(new IdempotencyReceipt {
                        Id = receiptId, RequestHash = bodyHash, StatusCode = statusCode,
                        ResponseJson = executed.Result switch
                        {
                            ObjectResult result => JsonSerializer.Serialize(result.Value, options),
                            ContentResult result => result.Content ?? string.Empty,
                            _ => string.Empty
                        }
                    });
                    await db.SaveChangesAsync();
                    await transaction.CommitAsync();
                }
            });
        }
        finally { Gate.Release(); }
    }

    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
