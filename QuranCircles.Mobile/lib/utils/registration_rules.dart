import 'package:flutter/services.dart';

class RegistrationRules {
  static const defaultPassword = '123456';
  static String digits(String value) =>
      value.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
        final code = match[0]!.codeUnitAt(0);
        return String.fromCharCode(48 + code - (code >= 0x6f0 ? 0x6f0 : 0x660));
      });
  static String? identityError(String? value, {bool required = true}) {
    final number = digits(value?.trim() ?? '');
    return number.isEmpty && !required || RegExp(r'^[0-9]{9}$').hasMatch(number)
        ? null
        : 'أدخل رقم هوية من 9 أرقام بالضبط';
  }

  static bool sameIdentity(String first, String second) =>
      identityError(first) == null &&
      identityError(second) == null &&
      digits(first.trim()) == digits(second.trim());
  static String? phoneError(String? value, {bool required = true}) {
    final number = digits(value?.trim() ?? '');
    return number.isEmpty && !required ||
            RegExp(r'^05[69][0-9]{7}$').hasMatch(number)
        ? null
        : '10 أرقام تبدأ بـ 059 أو 056';
  }

  static String? passwordError(String? value, {bool required = false}) =>
      (value?.trim().isEmpty ?? true) && !required ||
              (value?.trim().length ?? 0) >= 6
          ? null
          : 'كلمة المرور 6 أحرف على الأقل';
  static ({String code, String number}) splitWhatsApp(String value) {
    var number = digits(value).replaceAll(RegExp(r'[\s()+-]'), '');
    if (number.startsWith('00')) number = number.substring(2);
    var code = '+970';
    if (number.startsWith('970') || number.startsWith('972')) {
      code = '+${number.substring(0, 3)}';
      number = number.substring(3);
    }
    if (number.startsWith('0')) number = number.substring(1);
    return (code: code, number: number);
  }

  static String? whatsAppError(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^5[0-9]{8}$').hasMatch(splitWhatsApp(value).number)
        ? null
        : 'أدخل رقم جوال صحيح للواتساب';
  }
}

class LimitedDigitsFormatter extends TextInputFormatter {
  final int length;
  const LimitedDigitsFormatter(this.length);
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = RegistrationRules.digits(newValue.text)
        .replaceAll(RegExp('[^0-9]'), '');
    if (text.length > length) text = text.substring(0, length);
    final cursor = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: cursor));
  }
}
