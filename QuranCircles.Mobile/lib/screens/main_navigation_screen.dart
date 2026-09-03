import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/offline_sync_manager.dart';
import '../theme/app_theme.dart';
import 'announcements_screen.dart';
import 'certificates_screen.dart';
import 'circle_attendance_screen.dart';
import 'circles_management_screen.dart';
import 'course_attendance_screen.dart';
import 'courses_management_screen.dart';
import 'dashboard_screen.dart';
import 'developer_users_screen.dart';
import 'dynamic_reports_screen.dart';
import 'exams_screen.dart';
import 'login_screen.dart';
import 'parent_audit_screen.dart';
import 'profile_requests_screen.dart';
import 'student_360_screen.dart';
import 'students_management_screen.dart';
import 'teachers_management_screen.dart';
import 'system_settings_screen.dart';
import 'financial_management_screen.dart';
import 'quality_management_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final User currentUser;

  const MainNavigationScreen({super.key, required this.currentUser});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequestsCount();
  }

  Future<void> _fetchPendingRequestsCount() async {
    final role = widget.currentUser.role;
    if (role == 'Admin' || role == 'Developer') {
      try {
        final list = await ApiService.getProfileUpdateRequests();
        final pending = list.where((r) => r['status'] == 'Pending' || r['status'] == 'معلق').length;
        if (mounted) {
          setState(() => _pendingRequestsCount = pending);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.currentUser.role;
    final isDev = role == 'Developer';
    final isAdmin = role == 'Admin' || isDev;
    final isTeacher = role == 'Teacher';
    final isSupervisor = role == 'ExamSupervisor';

    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> items = [];

    // 1. Dashboard is common to all
    screens.add(DashboardScreen(
      currentUser: widget.currentUser,
      onNavigateTab: (index) => setState(() => _currentIndex = index),
    ));
    items.add(const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'));

    // Role-specific screens
    if (isAdmin) {
      screens.add(const DynamicReportsScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.filter_alt), label: 'التقارير'));

      screens.add(const StudentsManagementScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'الطلاب'));

      screens.add(const CirclesManagementScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'الحلقات'));

      screens.add(const TeachersManagementScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.record_voice_over), label: 'المعلمون'));

      screens.add(const CoursesManagementScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.school), label: 'المساقات'));

      screens.add(ExamsScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الاختبارات'));

      if (isDev) {
        screens.add(const DeveloperUsersScreen());
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'المطور'));
      }
    } else if (isTeacher) {
      screens.add(CircleAttendanceScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: 'تحضير الحلقة'));

      screens.add(CourseAttendanceScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.school), label: 'تحضير المساق'));

      screens.add(ExamsScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الترشيحات'));

      screens.add(AnnouncementsScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'الإعلانات'));
    } else if (isSupervisor) {
      screens.add(ExamsScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الاختبارات'));

      screens.add(const CertificatesScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'الشهادات'));

      screens.add(AnnouncementsScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'الإعلانات'));
    } else {
      // Student / Parent
      screens.add(const Student360Screen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'الملف 360°'));

      screens.add(const CertificatesScreen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'الشهادات'));

      screens.add(AnnouncementsScreen(currentUser: widget.currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'الإعلانات'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مركز البيان لتعليم القرآن',
              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'مسجد علي بن أبي طالب',
              style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Live Notifications Bell with Real-Time Badge
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.unreadCount,
            builder: (context, count, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: 'مركز الإشعارات والتنبيهات',
                    onPressed: _showNotificationsSheet,
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Pending Offline Sync Indicator
          ValueListenableBuilder<int>(
            valueListenable: OfflineSyncManager.pendingActionsCount,
            builder: (context, pendingCount, _) {
              if (pendingCount == 0) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.sync, color: Colors.amber),
                tooltip: 'عمليات معلقة بانتظار المزامنة ($pendingCount)',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري مزامنة العمليات المحفوظة أوفلاين مع السيرفر... ⚡')),
                  );
                  final synced = await OfflineSyncManager.syncPendingActions();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تمت مزامنة $synced عملية بنجاح!'), backgroundColor: Colors.green),
                  );
                },
              );
            },
          ),

          if (isAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note),
                  tooltip: 'طلبات التعديل والمعالجة',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ProfileRequestsScreen())).then((_) => _fetchPendingRequestsCount());
                  },
                ),
                if (_pendingRequestsCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: Text(
                        '$_pendingRequestsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primary),
              accountName: Text(
                widget.currentUser.fullName,
                style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                'مركز البيان - مسجد علي بن أبي طالب | ${widget.currentUser.role}',
                style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.accentLight),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppTheme.accent,
                child: Text(
                  widget.currentUser.fullName.isNotEmpty ? widget.currentUser.fullName[0] : 'م',
                  style: AppTheme.cairoStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dashboard, color: AppTheme.primary),
              title: Text('لوحة التحكم والإحصائيات', style: AppTheme.cairoStyle()),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),

            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.filter_alt, color: AppTheme.primary),
                title: Text('مُولد التقارير والفلترة المركّبة الذكية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const DynamicReportsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)),
                title: Text('سجل الصندوق والمالية والتبرعات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                subtitle: Text('كشف حركة الصندوق، سندات القبض والصرف', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const FinancialManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified_user, color: Color(0xFF0D5C3A)),
                title: Text('ملف الجودة والرقابة والتوجيه', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('تقارير الزيارات التفتيشية وتقييم الحلقات', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const QualityManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active, color: AppTheme.primary),
                title: Text('طلبات تعديل ملفات الطلاب والأولياء', style: AppTheme.cairoStyle()),
                trailing: _pendingRequestsCount > 0
                    ? CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Text('$_pendingRequestsCount', style: const TextStyle(color: Colors.white, fontSize: 10)))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ProfileRequestsScreen())).then((_) => _fetchPendingRequestsCount());
                },
              ),
              ListTile(
                leading: const Icon(Icons.family_restroom, color: AppTheme.primary),
                title: Text('سجل الرقابة الأولياء وأبنائهم', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ParentAuditScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: AppTheme.primary),
                title: Text('إدارة الطلاب والحذف النهائي', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const StudentsManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.groups, color: AppTheme.primary),
                title: Text('إدارة الحلقات القرآنية', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CirclesManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over, color: AppTheme.primary),
                title: Text('إدارة المعلمين والمحفظين', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const TeachersManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.school, color: AppTheme.primary),
                title: Text('إدارة المساقات والدورات', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CoursesManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: AppTheme.primary),
                title: Text('إدارة حسابات النظام والرقابة', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const DeveloperUsersScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune, color: AppTheme.primary),
                title: Text('لوحة تحكم إعدادات المنظومة (CMS)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('تخصيص الهوية، المعايير، الصلاحيات والشهادات', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SystemSettingsScreen()));
                },
              ),
            ],

            if (isTeacher) ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: AppTheme.primary),
                title: Text('تنسيب وإدارة طلاب حلقاتي', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('تنسيب طلاب جدد واستعراض بيانات طلاب الحلقة', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const StudentsManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_check, color: AppTheme.primary),
                title: Text('تسجيل حضور الحلقة وقرعة التسميع', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => CircleAttendanceScreen(currentUser: widget.currentUser)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.school, color: AppTheme.primary),
                title: Text('تحضير طلاب المساقات والدورات', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => CourseAttendanceScreen(currentUser: widget.currentUser)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment, color: AppTheme.primary),
                title: Text('ترشيح الطلاب للاختبارات', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => ExamsScreen(currentUser: widget.currentUser)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)),
                title: Text('سجل الصندوق والمالية والتبرعات', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const FinancialManagementScreen()));
                },
              ),
            ],

            if (!isTeacher) ...[
              ListTile(
                leading: const Icon(Icons.assignment, color: AppTheme.primary),
                title: Text('إدارة الاختبارات والترشيحات', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => ExamsScreen(currentUser: widget.currentUser)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: AppTheme.primary),
                title: Text('السجل العام للشهادات الرقمية', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CertificatesScreen()));
                },
              ),
            ],

            ListTile(
              leading: const Icon(Icons.campaign, color: AppTheme.primary),
              title: Text('نشرات وإعلانات المركز', style: AppTheme.cairoStyle()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => AnnouncementsScreen(currentUser: widget.currentUser)));
              },
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('تسجيل الخروج', style: AppTheme.cairoStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex < screens.length ? _currentIndex : 0,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex < items.length ? _currentIndex : 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        selectedLabelStyle: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: AppTheme.cairoStyle(fontSize: 10),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: items,
      ),
    );
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text('تأكيد تسجيل الخروج', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل تريد تسجيل الخروج من حساب (${widget.currentUser.fullName})؟\nسيتطلب الدخول مجدداً كتابة كلمة المرور.',
          style: AppTheme.cairoStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (ctx) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showNotificationsSheet() {
    NotificationService.fetchLiveNotifications(widget.currentUser);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('مركز الإشعارات والتنبيهات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      NotificationService.markAllAsRead();
                    },
                    icon: const Icon(Icons.done_all, size: 16, color: Colors.green),
                    label: Text('تحديد الكل كمقروء', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.green)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),

            // Notifications List
            Expanded(
              child: ValueListenableBuilder<List<CenterNotification>>(
                valueListenable: NotificationService.notificationsList,
                builder: (context, list, _) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey),
                          const SizedBox(height: 10),
                          Text('لا توجد إشعارات جديدة حالياً', style: AppTheme.cairoStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.isRead ? Colors.grey.shade200 : AppTheme.primary.withOpacity(0.15),
                          child: Icon(
                            item.category == 'profile_request' ? Icons.edit_note : Icons.campaign,
                            color: item.isRead ? Colors.grey : AppTheme.primary,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: AppTheme.cairoStyle(
                            fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                            color: item.isRead ? Colors.grey.shade700 : AppTheme.textDark,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.body, style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text(
                              '${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')} - ${item.timestamp.year}/${item.timestamp.month}/${item.timestamp.day}',
                              style: AppTheme.cairoStyle(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                        trailing: !item.isRead
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                              )
                            : null,
                        onTap: () {
                          NotificationService.markAsRead(item.id);
                          Navigator.pop(sheetCtx);
                          if (item.category == 'announcement') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementsScreen(currentUser: widget.currentUser)));
                          } else if (item.category == 'profile_request') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileRequestsScreen()));
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

