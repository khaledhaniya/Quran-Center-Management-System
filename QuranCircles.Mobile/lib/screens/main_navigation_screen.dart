import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
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
          if (isAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active),
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
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
            ],

            if (isTeacher) ...[
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
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                );
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
}
