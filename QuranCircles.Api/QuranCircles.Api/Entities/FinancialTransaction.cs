using System;

namespace QuranCircles.Api.Entities;

public enum TransactionType
{
    Income = 1,   // وارد / تبرع / إيراد
    Expense = 2   // صادر / مصروف / نفقات
}

public enum PaymentMethod
{
    Cash = 1,       // كاش (نقداً)
    AppWallet = 2,  // تطبيق / محفظة إلكترونية (Jawwal Pay / PalPay / إلخ)
    Bank = 3        // تحويل / حساب بنكي
}

public class FinancialTransaction
{
    public int Id { get; set; }
    public TransactionType Type { get; set; } // Income or Expense
    public decimal Amount { get; set; } // المبلغ
    public string Currency { get; set; } = "ILS"; // شيكل / دولار / دينار
    
    public string Title { get; set; } = string.Empty; // البيان / العنوان الرئيسي
    public string? Category { get; set; } // التصنيف (تبرعات عامة، كفالة حلقات، مكافآت معلمين، صيانة، ضيافة، جوائز...)
    
    // للتبرعات والواردات
    public string? DonorName { get; set; } // اسم المتبرع (فاعل خير / فلان)
    public string? DonorSource { get; set; } // طرف مين التبرع / جهة التبرع أو الواسطة (مثال: طرف الشيخ فلان / جمعية كذا)
    
    // للمصروفات والصادرات
    public string? RecipientName { get; set; } // المستلم / الجهة المصروف لها
    
    public PaymentMethod PaymentMethod { get; set; } // Cash, AppWallet, Bank
    public string? PaymentDetails { get; set; } // تفاصيل الدفع / اسم التطبيق أو المحفظة أو البنك أو رقم العملية
    
    public DateTime TransactionDate { get; set; } = DateTime.UtcNow; // تاريخ المعاملة
    public string? ReferenceNumber { get; set; } // رقم السند / الوصل / الفاتورة
    public string? Notes { get; set; } // ملاحظات إضافية
    
    public int? CreatedByUserId { get; set; } // المستخدم الذي أضاف السند
    public string? CreatedByName { get; set; } // اسم من سجل السند
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
