import 'package:flutter/material.dart';

class TeacherRoleItem {
  final String title;
  final IconData icon;
  final Color color;

  const TeacherRoleItem({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherRoleItem && runtimeType == other.runtimeType && title == other.title;

  @override
  int get hashCode => title.hashCode;
}

class TeacherRoleHelper {
  static const List<String> availableInputRoles = [
    'معلم حلقة',
    'مساعد حلقة',
    'مشرف اختبارات',
    'شؤون التحفيظ',
    'الجودة والرقابة',
    'الملف المالي',
    'معلم دورات',
    'الفتى الواعظ',
    'أمير المركز',
  ];

  static List<TeacherRoleItem> getTeacherRolesList(String? taskRole) {
    if (taskRole == null || taskRole.trim().isEmpty) {
      return const [
        TeacherRoleItem(
          title: 'غير مكلف',
          icon: Icons.schedule,
          color: Colors.grey,
        ),
      ];
    }

    final t = taskRole.trim();
    if (t == 'بدون تكليف' ||
        t == 'غير مكلف' ||
        t == 'معلق' ||
        t == 'بدون مهام' ||
        t == 'لا يوجد' ||
        t == 'لا يوجد تكليف' ||
        t == '-' ||
        t.isEmpty) {
      return const [
        TeacherRoleItem(
          title: 'غير مكلف',
          icon: Icons.schedule,
          color: Colors.grey,
        ),
      ];
    }

    final List<TeacherRoleItem> roles = [];
    final seenTitles = <String>{};

    void addRole(TeacherRoleItem item) {
      if (!seenTitles.contains(item.title)) {
        seenTitles.add(item.title);
        roles.add(item);
      }
    }

    if (t.contains('مركز البيان') || t.contains('أمير المركز') || t.contains('البيان')) {
      addRole(const TeacherRoleItem(
        title: 'أمير المركز (المدير العام)',
        icon: Icons.military_tech,
        color: Color(0xFFD97706),
      ));
    }

    if (t.contains('معلم حلقة') || t.contains('شيخ ومحفّظ') || t.contains('محفظ حلقة') || t.contains('محفّظ')) {
      addRole(const TeacherRoleItem(
        title: 'معلّم ومحفّظ حلقة',
        icon: Icons.mosque,
        color: Color(0xFF10B981),
      ));
    }

    if (t.contains('مساعد حلقة')) {
      addRole(const TeacherRoleItem(
        title: 'مساعد حلقة قرآنية',
        icon: Icons.handshake,
        color: Color(0xFF0D9488),
      ));
    }

    if (t.contains('الفتى الواعظ') || t.contains('الأصوات الندية')) {
      addRole(const TeacherRoleItem(
        title: 'مشرف الفتى الواعظ والأصوات الندية',
        icon: Icons.record_voice_over,
        color: Color(0xFFE11D48),
      ));
    }

    if (t.contains('اختبار') || t.contains('مشرف اختبارات')) {
      addRole(const TeacherRoleItem(
        title: 'مشرف اختبارات',
        icon: Icons.assignment_turned_in,
        color: Color(0xFFF59E0B),
      ));
    }

    if (t.contains('التحفيظ') || t.contains('منتدى الحفاظ')) {
      addRole(const TeacherRoleItem(
        title: 'مشرف شؤون التحفيظ ومنتدى الحفاظ',
        icon: Icons.menu_book,
        color: Color(0xFF4F46E5),
      ));
    }

    if (t.contains('الجودة') || t.contains('رقابة')) {
      addRole(const TeacherRoleItem(
        title: 'مسؤول الجودة والرقابة والتوجيه',
        icon: Icons.verified_user,
        color: Color(0xFF0284C7),
      ));
    }

    if (t.contains('الملف المالي') || t.contains('المالي') || t.contains('الصندوق')) {
      addRole(const TeacherRoleItem(
        title: 'المسؤول المالي ومسؤول المحافظ',
        icon: Icons.account_balance_wallet,
        color: Color(0xFF059669),
      ));
    }

    if (t.contains('معلم دورات') || (t.contains('الدورات') && !t.contains('حلقة'))) {
      addRole(const TeacherRoleItem(
        title: 'معلم الدورات العلمية والتجويد',
        icon: Icons.school,
        color: Color(0xFF6B7280),
      ));
    }

    if (roles.isEmpty) {
      // Split by comma or plus if custom roles
      final parts = t.split(RegExp(r'[,+]')).map((p) => p.trim()).where((p) => p.isNotEmpty);
      for (var p in parts) {
        if (!seenTitles.contains(p)) {
          seenTitles.add(p);
          roles.add(TeacherRoleItem(
            title: p,
            icon: Icons.stars,
            color: Colors.teal.shade800,
          ));
        }
      }
    }

    if (roles.isEmpty) {
      return const [
        TeacherRoleItem(
          title: 'غير مكلف',
          icon: Icons.schedule,
          color: Colors.grey,
        ),
      ];
    }

    return roles;
  }
}
