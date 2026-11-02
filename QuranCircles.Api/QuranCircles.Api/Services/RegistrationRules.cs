using System.Text.RegularExpressions;

namespace QuranCircles.Api.Services;

public static class RegistrationRules
{
    public static string? Digits(string? value) => value == null ? null : string.Concat(value.Trim().Select(c =>
        c is >= '٠' and <= '٩' ? (char)('0' + c - '٠') :
        c is >= '۰' and <= '۹' ? (char)('0' + c - '۰') : c));

    public static string? IdentityError(string? value, string label, bool required = false)
    {
        var number = Digits(value);
        return string.IsNullOrEmpty(number) && !required ||
            number != null && Regex.IsMatch(number, "^[0-9]{9}$")
            ? null : $"{label} يجب أن يتكون من 9 أرقام بالضبط.";
    }

    public static bool SameIdentity(string? first, string? second) =>
        IdentityError(first, "", true) == null && IdentityError(second, "", true) == null &&
        Digits(first) == Digits(second);

    public static string? PhoneError(string? value, bool required = false)
    {
        var number = Digits(value);
        return string.IsNullOrEmpty(number) && !required ||
            number != null && Regex.IsMatch(number, "^05[69][0-9]{7}$")
            ? null : "رقم الجوال يجب أن يكون 10 أرقام ويبدأ بـ 059 أو 056.";
    }

    public static string? WhatsApp(string? value)
    {
        if (value == null) return null;
        var number = Regex.Replace(Digits(value)!, @"[\s()-]", "");
        if (number == "") return "";
        if (number.StartsWith("00")) number = "+" + number[2..];
        if (Regex.IsMatch(number, "^97[02]")) number = "+" + number;
        if (number.StartsWith('0')) number = number[1..];
        if (!number.StartsWith('+')) number = "+970" + number;
        return number;
    }

    public static string? WhatsAppError(string? value) => string.IsNullOrWhiteSpace(value) ||
        Regex.IsMatch(WhatsApp(value)!, "^\\+97[02]5[0-9]{8}$") ? null :
        "رقم الواتساب غير صالح؛ اختر +970 أو +972 وأدخل رقم الجوال.";
}
