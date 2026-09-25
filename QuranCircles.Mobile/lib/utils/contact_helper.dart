import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactHelper {
  static Future<void> launchWhatsApp(BuildContext context, String phone, {String? text}) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير متوفر'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String clean = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('05')) {
      clean = '972${clean.substring(1)}';
    } else if (clean.startsWith('5') && clean.length == 9) {
      clean = '972$clean';
    }

    final query = text != null && text.isNotEmpty ? '?text=${Uri.encodeComponent(text)}' : '';
    final nativeUri = Uri.parse('whatsapp://send?phone=$clean$query');
    final webUri = Uri.parse('https://wa.me/$clean$query');

    // 1. Try native WhatsApp scheme directly
    try {
      final launched = await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
      if (launched) return;
    } catch (_) {}

    // 2. Fallback to https://wa.me
    try {
      final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 3. Fallback to platform default
    try {
      await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح واتساب: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> launchDialer(BuildContext context, String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير متوفر'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$trimmed');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق الهاتف: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
