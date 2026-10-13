using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuranCircles.Api.Data;
using QuranCircles.Api.Entities;
using QuranCircles.Api.Services;

namespace QuranCircles.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FinanceController : ControllerBase
{
    private readonly AppDbContext _db;

    public FinanceController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary([FromQuery] string? startDate, [FromQuery] string? endDate)
    {
        var query = _db.FinancialTransactions.AsQueryable();

        if (DateTime.TryParse(startDate, out var sDate))
        {
            query = query.Where(t => t.TransactionDate >= sDate);
        }
        if (DateTime.TryParse(endDate, out var eDate))
        {
            var endOfDay = eDate.Date.AddDays(1).AddTicks(-1);
            query = query.Where(t => t.TransactionDate <= endOfDay);
        }

        var all = await query.ToListAsync();

        var totalIncome = all.Where(t => t.Type == TransactionType.Income).Sum(t => t.Amount);
        var totalExpense = all.Where(t => t.Type == TransactionType.Expense).Sum(t => t.Amount);
        var netBalance = totalIncome - totalExpense;

        var cashIncome = all.Where(t => t.Type == TransactionType.Income && t.PaymentMethod == PaymentMethod.Cash).Sum(t => t.Amount);
        var cashExpense = all.Where(t => t.Type == TransactionType.Expense && t.PaymentMethod == PaymentMethod.Cash).Sum(t => t.Amount);
        var cashBalance = cashIncome - cashExpense;

        var appIncome = all.Where(t => t.Type == TransactionType.Income && t.PaymentMethod == PaymentMethod.AppWallet).Sum(t => t.Amount);
        var appExpense = all.Where(t => t.Type == TransactionType.Expense && t.PaymentMethod == PaymentMethod.AppWallet).Sum(t => t.Amount);
        var appWalletBalance = appIncome - appExpense;

        var bankIncome = all.Where(t => t.Type == TransactionType.Income && t.PaymentMethod == PaymentMethod.Bank).Sum(t => t.Amount);
        var bankExpense = all.Where(t => t.Type == TransactionType.Expense && t.PaymentMethod == PaymentMethod.Bank).Sum(t => t.Amount);
        var bankBalance = bankIncome - bankExpense;

        var donorsCount = all.Where(t => t.Type == TransactionType.Income && !string.IsNullOrWhiteSpace(t.DonorName))
                             .Select(t => t.DonorName!.Trim().ToLower())
                             .Distinct()
                             .Count();

        return Ok(new
        {
            totalIncome,
            totalExpense,
            netBalance,
            cashBalance,
            cashIncome,
            cashExpense,
            appWalletBalance,
            appIncome,
            appExpense,
            bankBalance,
            bankIncome,
            bankExpense,
            donorsCount,
            totalTransactions = all.Count
        });
    }

    [HttpGet("transactions")]
    public async Task<IActionResult> GetTransactions(
        [FromQuery] string? search,
        [FromQuery] int? type,
        [FromQuery] int? paymentMethod,
        [FromQuery] string? category,
        [FromQuery] string? startDate,
        [FromQuery] string? endDate)
    {
        var query = _db.FinancialTransactions.AsQueryable();

        if (type.HasValue && type.Value > 0)
        {
            query = query.Where(t => (int)t.Type == type.Value);
        }

        if (paymentMethod.HasValue && paymentMethod.Value > 0)
        {
            query = query.Where(t => (int)t.PaymentMethod == paymentMethod.Value);
        }

        if (!string.IsNullOrWhiteSpace(category))
        {
            query = query.Where(t => t.Category == category.Trim());
        }

        if (DateTime.TryParse(startDate, out var sDate))
        {
            query = query.Where(t => t.TransactionDate >= sDate);
        }
        if (DateTime.TryParse(endDate, out var eDate))
        {
            var endOfDay = eDate.Date.AddDays(1).AddTicks(-1);
            query = query.Where(t => t.TransactionDate <= endOfDay);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(t =>
                t.Title.ToLower().Contains(q) ||
                (t.DonorName != null && t.DonorName.ToLower().Contains(q)) ||
                (t.DonorSource != null && t.DonorSource.ToLower().Contains(q)) ||
                (t.RecipientName != null && t.RecipientName.ToLower().Contains(q)) ||
                (t.Category != null && t.Category.ToLower().Contains(q)) ||
                (t.ReferenceNumber != null && t.ReferenceNumber.ToLower().Contains(q)) ||
                (t.Notes != null && t.Notes.ToLower().Contains(q)) ||
                (t.PaymentDetails != null && t.PaymentDetails.ToLower().Contains(q))
            );
        }

        var list = await query.OrderByDescending(t => t.TransactionDate)
                              .ThenByDescending(t => t.Id)
                              .ToListAsync();

        return Ok(list);
    }

    [HttpGet("transactions/{id}")]
    public async Task<IActionResult> GetTransaction(int id)
    {
        var item = await _db.FinancialTransactions.FindAsync(id);
        if (item == null) return NotFound(new { error = "السند غير موجود." });
        return Ok(item);
    }

    [HttpPost("transactions")]
    public async Task<IActionResult> CreateTransaction([FromBody] FinancialTransaction model)
    {
        if (model == null) return BadRequest(new { error = "بيانات غير صالحة." });
        if (model.Amount <= 0) return BadRequest(new { error = "يجب أن يكون المبلغ أكبر من صفر." });
        if (string.IsNullOrWhiteSpace(model.Title)) return BadRequest(new { error = "يرجى تحديد البيان / عنوان المعاملة." });

        if (model.TransactionDate == default)
        {
            model.TransactionDate = DateTime.UtcNow;
        }

        model.CreatedAt = DateTime.UtcNow;
        _db.FinancialTransactions.Add(model);
        await _db.SaveChangesAsync();

        var typeStr = model.Type == TransactionType.Income ? "سند قبض / وارد" : "سند صرف / صادر";
        await AuditLogger.LogAsync(_db, HttpContext, "CreateFinancialTransaction", $"إضافة {typeStr} بمبلغ {model.Amount} {model.Currency} - البيان: {model.Title}");

        return CreatedAtAction(nameof(GetTransaction), new { id = model.Id }, model);
    }

    [HttpPut("transactions/{id}")]
    public async Task<IActionResult> UpdateTransaction(int id, [FromBody] FinancialTransaction model)
    {
        var item = await _db.FinancialTransactions.FindAsync(id);
        if (item == null) return NotFound(new { error = "السند غير موجود." });

        if (model.Amount <= 0) return BadRequest(new { error = "يجب أن يكون المبلغ أكبر من صفر." });
        if (string.IsNullOrWhiteSpace(model.Title)) return BadRequest(new { error = "يرجى تحديد البيان / عنوان المعاملة." });

        item.Type = model.Type;
        item.Amount = model.Amount;
        item.Currency = string.IsNullOrWhiteSpace(model.Currency) ? "ILS" : model.Currency;
        item.Title = model.Title.Trim();
        item.Category = model.Category?.Trim();
        item.DonorName = model.DonorName?.Trim();
        item.DonorSource = model.DonorSource?.Trim();
        item.RecipientName = model.RecipientName?.Trim();
        item.PaymentMethod = model.PaymentMethod;
        item.PaymentDetails = model.PaymentDetails?.Trim();
        if (model.TransactionDate != default) item.TransactionDate = model.TransactionDate;
        item.ReferenceNumber = model.ReferenceNumber?.Trim();
        item.Notes = model.Notes?.Trim();

        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "UpdateFinancialTransaction", $"تعديل سند مالي رقم #{id} بمبلغ {item.Amount} {item.Currency}");

        return Ok(item);
    }

    [HttpDelete("transactions/{id}")]
    public async Task<IActionResult> DeleteTransaction(int id)
    {
        var item = await _db.FinancialTransactions.FindAsync(id);
        if (item == null) return NotFound(new { error = "السند غير موجود." });

        _db.FinancialTransactions.Remove(item);
        await _db.SaveChangesAsync();

        await AuditLogger.LogAsync(_db, HttpContext, "DeleteFinancialTransaction", $"حذف سند مالي رقم #{id} - {item.Title}");

        return Ok(new { message = "تم حذف السند بنجاح." });
    }

    [HttpGet("categories")]
    public async Task<IActionResult> GetCategories()
    {
        var cats = await _db.FinancialTransactions
                            .Where(t => !string.IsNullOrWhiteSpace(t.Category))
                            .Select(t => t.Category!)
                            .Distinct()
                            .ToListAsync();

        var defaults = new List<string>
        {
            "تبرعات عامة للمركز",
            "كفالة حلقات قرآنية",
            "مكافآت كادر المعلمين",
            "جوائز وتكريم الطلاب",
            "مطبوعات وقرطاسية وشهادات",
            "ضيافة وأنشطة مركزية",
            "صيانة وتجهيزات وتأهيل",
            "فواتير وخدمات",
            "أخرى"
        };

        foreach (var d in defaults)
        {
            if (!cats.Contains(d)) cats.Add(d);
        }

        return Ok(cats);
    }

    [HttpGet("export")]
    public async Task<IActionResult> Export([FromQuery] string? format = "xls")
    {
        var list = await _db.FinancialTransactions
                            .OrderByDescending(t => t.TransactionDate)
                            .ThenByDescending(t => t.Id)
                            .ToListAsync();

        if (string.Equals(format, "csv", StringComparison.OrdinalIgnoreCase))
        {
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("رقم السند,النوع,البيان,التصنيف,المبلغ (₪),طريقة الدفع,المتبرع/المستلم,الجهة/الواسطة,التاريخ,ملاحظات");
            foreach (var t in list)
            {
                var typeStr = t.Type == TransactionType.Income ? "إيراد / تبرع" : "مصروف / نفقة";
                var personStr = t.Type == TransactionType.Income ? (t.DonorName ?? "-") : (t.RecipientName ?? "-");
                var methodStr = t.PaymentMethod switch
                {
                    PaymentMethod.Cash => "كاش (نقداً)",
                    PaymentMethod.AppWallet => "محفظة إلكترونية",
                    PaymentMethod.Bank => "حساب بنكي",
                    _ => "أخرى"
                };
                sb.AppendLine($"\"{t.Id}\",\"{typeStr}\",\"{t.Title?.Replace("\"", "\"\"")}\",\"{t.Category?.Replace("\"", "\"\"")}\",\"{t.Amount}\",\"{methodStr}\",\"{personStr.Replace("\"", "\"\"")}\",\"{t.DonorSource?.Replace("\"", "\"\"")}\",\"{t.TransactionDate:yyyy-MM-dd}\",\"{t.Notes?.Replace("\"", "\"\"")}\"");
            }

            var bytes = System.Text.Encoding.UTF8.GetPreamble().Concat(System.Text.Encoding.UTF8.GetBytes(sb.ToString())).ToArray();
            return File(bytes, "text/csv; charset=utf-8", $"كشف_حركة_الصندوق_{DateTime.Today:yyyy-MM-dd}.csv");
        }
        else
        {
            var sb = new System.Text.StringBuilder();
            sb.Append(@"<html xmlns:o=""urn:schemas-microsoft-com:office:office"" xmlns:x=""urn:schemas-microsoft-com:office:excel"" xmlns=""http://www.w3.org/TR/REC-html40"">
<head><meta charset=""utf-8""><style>
table { border-collapse: collapse; width: 100%; direction: rtl; font-family: Tahoma, Arial, sans-serif; }
th { background-color: #0d5c3a; color: #ffffff; border: 1px solid #000; padding: 10px; font-size: 13px; text-align: center; }
td { border: 1px solid #cccccc; padding: 8px; font-size: 12px; text-align: center; }
.income { color: #166534; font-weight: bold; }
.expense { color: #991b1b; font-weight: bold; }
</style></head><body>
<h2 style=""text-align:center; color:#0d5c3a;"">مركز البيان لتعليم القرآن الكريم - كشف حركة الصندوق المالي المعتمد</h2>
<p style=""text-align:center; color:#64748b;"">تاريخ الاستخراج: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + @"</p>
<table>
<thead>
<tr>
<th>رقم السند</th>
<th>النوع</th>
<th>البيان / الشرح</th>
<th>التصنيف</th>
<th>المبلغ (₪)</th>
<th>طريقة الدفع</th>
<th>المتبرع / المستلم</th>
<th>الجهة / الواسطة</th>
<th>تاريخ السند</th>
<th>ملاحظات</th>
</tr>
</thead><tbody>");

            foreach (var t in list)
            {
                var typeStr = t.Type == TransactionType.Income ? "إيراد / تبرع" : "مصروف / نفقة";
                var typeClass = t.Type == TransactionType.Income ? "income" : "expense";
                var personStr = t.Type == TransactionType.Income ? (t.DonorName ?? "-") : (t.RecipientName ?? "-");
                var methodStr = t.PaymentMethod switch
                {
                    PaymentMethod.Cash => "كاش (نقداً)",
                    PaymentMethod.AppWallet => "محفظة إلكترونية",
                    PaymentMethod.Bank => "حساب بنكي",
                    _ => "أخرى"
                };
                sb.Append($@"<tr>
<td>#{t.Id}</td>
<td class=""{typeClass}"">{typeStr}</td>
<td>{System.Net.WebUtility.HtmlEncode(t.Title)}</td>
<td>{System.Net.WebUtility.HtmlEncode(t.Category ?? "-")}</td>
<td><strong>{t.Amount:N2}</strong></td>
<td>{methodStr}</td>
<td>{System.Net.WebUtility.HtmlEncode(personStr)}</td>
<td>{System.Net.WebUtility.HtmlEncode(t.DonorSource ?? "-")}</td>
<td>{t.TransactionDate:yyyy-MM-dd}</td>
<td>{System.Net.WebUtility.HtmlEncode(t.Notes ?? "-")}</td>
</tr>");
            }

            sb.Append("</tbody></table></body></html>");
            var bytes = System.Text.Encoding.UTF8.GetPreamble().Concat(System.Text.Encoding.UTF8.GetBytes(sb.ToString())).ToArray();
            return File(bytes, "application/vnd.ms-excel", $"كشف_حساب_الصندوق_{DateTime.Today:yyyy-MM-dd}.xls");
        }
    }
}
