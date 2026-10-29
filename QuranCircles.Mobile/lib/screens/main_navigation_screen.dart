import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/offline_sync_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/center_logo.dart';
import 'announcements_screen.dart';
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
import 'teacher_operations_screen.dart';
import 'memorization_forum_screen.dart';
import 'preacher_youth_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_sessions_screen.dart';
import 'teacher_circle_students_screen.dart';
import 'teacher_comprehensive_report_screen.dart';
import 'teacher_lottery_screen.dart';
import 'parent_portal_screen.dart';
import 'circle_leaderboard_screen.dart';
import 'offline_sync_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final User currentUser;

  const MainNavigationScreen({super.key, required this.currentUser});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  late User _currentUser;
  int _currentIndex = 0;
  int _pendingRequestsCount = 0;
  String _centerName = 'مركز البيان لتعليم القرآن';
  String _mosqueName = 'مسجد علي بن أبي طالب';
  String _logoUrl = '';
  bool _isMaintenanceMode = false;
  Timer? _settingsRefreshTimer;
  bool _settingsRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _currentUser=widget.currentUser;
    WidgetsBinding.instance.addObserver(this);
    _fetchPendingRequestsCount();
    _loadSystemSettings();
    _settingsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadSystemSettings());
  }

  void _loadSystemSettings() async {
    if (_settingsRequestInFlight) return;
    _settingsRequestInFlight = true;
    try {
      final s = await ApiService.getSystemSettings();
      if (s != null && mounted) {
        AppTheme.setStyle((s['themeStyle'] ?? s['ThemeStyle'] ?? 'Classic').toString());
        final nextCenter = s['centerName'] ?? s['CenterName'] ?? _centerName;
        final nextMosque = s['mosqueName'] ?? s['MosqueName'] ?? _mosqueName;
        final nextLogo = (s['logoUrl'] ?? s['LogoUrl'] ?? '').toString();
        final nextMaintenance = s['maintenanceMode'] == true || s['MaintenanceMode'] == true;
        if (nextCenter != _centerName || nextMosque != _mosqueName || nextLogo != _logoUrl || nextMaintenance != _isMaintenanceMode) {
          setState(() {
            _centerName = nextCenter;
            _mosqueName = nextMosque;
            _logoUrl = nextLogo;
            _isMaintenanceMode = nextMaintenance;
          });
        }
      }
      final latest=await ApiService.refreshSessionProfile();
      if(mounted&&latest!=null&&('${latest.role}|${latest.taskRole}|${latest.childrenCount}|${latest.effectivePermissions.join(',')}'!='${_currentUser.role}|${_currentUser.taskRole}|${_currentUser.childrenCount}|${_currentUser.effectivePermissions.join(',')}')){
        ApiService.invalidateCache();setState((){_currentUser=latest;_currentIndex=0;});
      }
    } catch (_) {
    } finally {
      _settingsRequestInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSystemSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPendingRequestsCount() async {
    final role = _currentUser.role;
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
    final role = _currentUser.role;
    final isDev = role == 'Developer';
    final isAdmin = role == 'Admin' || isDev;
    final isTeacher = role == 'Teacher';
    final isSupervisor = role == 'ExamSupervisor';

    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> items = [];

    // 1. Dashboard is common to all
    screens.add(role=='Parent'?const ParentPortalScreen(embedded:true):DashboardScreen(
      key:ValueKey('${_currentUser.id}|${_currentUser.taskRole}|${_currentUser.effectivePermissions.join(',')}|${_currentUser.childrenCount}'),
      currentUser: _currentUser,
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

      screens.add(ExamsScreen(currentUser: _currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الاختبارات'));

      if (isDev) {
        screens.add(const DeveloperUsersScreen());
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'المطور'));
      }
    } else if (isTeacher) {
      if (_currentUser.isHalaqahTeacher) {
        screens.add(TeacherAttendanceScreen(currentUser: _currentUser));
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: 'حضور الحلقة'));

        screens.add(TeacherSessionsScreen(currentUser: _currentUser));
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.book_outlined), label: 'سجل التسميع'));

        screens.add(TeacherComprehensiveReportScreen(currentUser: _currentUser));
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'كشف المتابعة'));
      }

      if (_currentUser.isCourseTeacher) {
        screens.add(CourseAttendanceScreen(currentUser: _currentUser));
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.school), label: 'تحضير المساق'));

        screens.add(const CoursesManagementScreen());
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'الدورات'));
      }

      if (_currentUser.isHalaqahTeacher || _currentUser.isCourseTeacher || _currentUser.isExamSupervisor) {
        screens.add(ExamsScreen(currentUser: _currentUser));
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الترشيحات'));
      }
    } else if (isSupervisor) {
      screens.add(ExamsScreen(currentUser: _currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الاختبارات'));

      screens.add(AnnouncementsScreen(currentUser: _currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'الإعلانات'));
    } else {
      // Student / Parent
      screens.add(role=='Parent'?const Student360Screen(isParentView:true):const Student360Screen());
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'الملف 360°'));

      screens.add(AnnouncementsScreen(currentUser: _currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'الإعلانات'));
      screens.add(ExamsScreen(currentUser: _currentUser));
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الاختبارات'));
      if (role == 'Parent' && (_currentUser.hasChildren || _currentUser.childrenCount > 0) && _currentUser.teacherId != null && _currentUser.isCourseTeacher) {
        screens.add(const CoursesManagementScreen());
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'دوراتي'));
      }
    }

    screens.add(const CoursesManagementScreen(portfolioOnly: true));
    items.add(const BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'الإنجاز والشهادات'));

    // Maintenance Mode Blocker (For all non-developer users)
    if (_isMaintenanceMode && !isDev) {
      return Scaffold(
        backgroundColor: const Color(0xFF031E12),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.amber, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_rounded, size: 56, color: Colors.amber),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'النظام في وضع الصيانة والتحديث',
                    textAlign: TextAlign.center,
                    style: AppTheme.cairoStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'النظام داخل وضع الصيانة والتحديث حالياً، يرجى التواصل مع المطور للمزيد من التفاصيل.',
                    textAlign: TextAlign.center,
                    style: AppTheme.cairoStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: Text(
                      'تسجيل الخروج',
                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 12,
        centerTitle: false,
        title: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: CenterLogo(logoUrl: _logoUrl, size: 38)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_centerName, style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_mosqueName, style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.accentLight), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: ApiService.usingOfflineData,
            builder: (context, offline, _) =>
                offline || ApiService.authToken == null
                    ? IconButton(
                        icon: const Icon(Icons.cloud_off, color: Colors.amber),
                        tooltip: ApiService.authToken == null
                            ? 'جلسة الدخول منتهية؛ سجّل الدخول للمزامنة'
                            : 'تظهر آخر بيانات محفوظة على الجهاز',
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const OfflineSyncScreen())),
                      )
                    : const SizedBox.shrink(),
          ),
          // Pending Offline Sync Indicator
          ValueListenableBuilder<int>(
            valueListenable: OfflineSyncManager.pendingActionsCount,
            builder: (context, pendingCount, _) {
              if (pendingCount == 0 && OfflineSyncManager.reviewActionsCount.value == 0) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.sync_problem,
                    color: OfflineSyncManager.reviewActionsCount.value > 0 ? Colors.redAccent : Colors.amber),
                tooltip: 'عمليات محفوظة على الجهاز ($pendingCount)',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OfflineSyncScreen())),
              );
            },
          ),

          // Bell Icon restricted ONLY to Admin and Developer accounts
          if (isAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  tooltip: 'طلبات تعديل البيانات والملفات',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ProfileRequestsScreen())).then((_) => _fetchPendingRequestsCount());
                  },
                ),
                if (_pendingRequestsCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Text(
                        _pendingRequestsCount > 9 ? '9+' : '$_pendingRequestsCount',
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
                _currentUser.fullName,
                style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              accountEmail: Text(
                'مركز البيان - مسجد علي بن أبي طالب | ${_currentUser.role}',
                style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.accentLight),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppTheme.accent,
                child: Text(
                  _currentUser.fullName.isNotEmpty ? _currentUser.fullName[0] : 'م',
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

            ListTile(
              leading: const Icon(Icons.sync, color: AppTheme.primary),
              title: Text('المزامنة والحفظ المحلي', style: AppTheme.cairoStyle()),
              trailing: ValueListenableBuilder<int>(
                valueListenable: OfflineSyncManager.pendingActionsCount,
                builder: (_, count, __) => count == 0 ? const SizedBox.shrink()
                    : Text('$count', style: AppTheme.cairoStyle(color: Colors.orange.shade900)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OfflineSyncScreen()));
              },
            ),

            if (isTeacher || isAdmin)
              ListTile(
                leading: const Icon(Icons.emoji_events, color: AppTheme.primary),
                title: Text('صدارة الحلقات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CircleLeaderboardScreen()));
                },
              ),

            if (_currentUser.role == 'Parent' || (_currentUser.hasChildren && _currentUser.childrenCount > 0)) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary.withValues(alpha: 0.12), AppTheme.accent.withValues(alpha: 0.08)],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.family_restroom, color: AppTheme.primary, size: 28),
                  title: Text(
                    'متابعة مستوى أبنائي',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14),
                  ),
                  subtitle: Text(
                    'سجل الحضور والتسميع والتقييم الشامل 360°',
                    style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  trailing: _currentUser.childrenCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentUser.childrenCount} ${_currentUser.childrenCount == 1 ? "ابن" : "أبناء"}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ParentPortalScreen()));
                  },
                ),
              ),
              const Divider(),
            ],

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
                leading: const Icon(Icons.punch_clock, color: AppTheme.primary),
                title: Text('كشف حضور المعلمين والبدلاء', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherOperationsScreen()));
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
                leading: const Icon(Icons.auto_stories, color: Color(0xFFD97706)),
                title: Text('شؤون التحفيظ ومنتدى الحفاظ', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                subtitle: Text('متابعة الخاتمين، روايات القراءة وخطط التثبيت', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const MemorizationForumScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over, color: Color(0xFF0D9488)),
                title: Text('برنامج الفتى الواعظ والأصوات الندية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                subtitle: Text('رعاية المواهب، خطب الجمعة، التلاوات والأذان', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const PreacherYouthScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.family_restroom, color: AppTheme.primary),
                title: Text('تدقيق وحوكمة أبناء أولياء الأمور', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('فك وإعادة الربط، كفالة الأيتام والرقابة', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
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
              if (_currentUser.isHalaqahTeacher) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('أدوات الحلقة القرآنية', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_check, color: AppTheme.primary),
                  title: Text('تسجيل الحضور اليومي', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('رصد حضور وغياب طلاب الحلقة مع التاريخ', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => TeacherAttendanceScreen(currentUser: _currentUser)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.book_outlined, color: AppTheme.primary),
                  title: Text('سجل تسميع الحفظ', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('توثيق الحفظ الجديد والمراجعة وتثبيت الآيات', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => TeacherSessionsScreen(currentUser: _currentUser)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1, color: AppTheme.primary),
                  title: Text('تنسيب وإدارة طلاب حلقاتي', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('استعراض طلاب الحلقة، وتنسيب الطلاب الجدد', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => TeacherCircleStudentsScreen(currentUser: _currentUser)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: AppTheme.primary),
                  title: Text('كشف متابعة وتسميع الطلاب الشامل', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('المصفوفة اليومية على الشاشة وتصدير PDF / Excel', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => TeacherComprehensiveReportScreen(currentUser: _currentUser)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.casino, color: AppTheme.primary),
                  title: Text('قرعة التسميع العشوائية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('اختيار الطالب التالي للتسميع واستبعاد الغائبين', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => TeacherLotteryScreen(currentUser: _currentUser)));
                  },
                ),
                const Divider(),
              ],
              if (_currentUser.isCourseTeacher) ...[
                ListTile(
                  leading: const Icon(Icons.school, color: AppTheme.primary),
                  title: Text('تحضير طلاب المساقات والدورات', style: AppTheme.cairoStyle()),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => CourseAttendanceScreen(currentUser: _currentUser)));
                  },
                ),
              ],
              if (_currentUser.isCourseTeacher || _currentUser.isExamSupervisor) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('البرامج والمسارات المكلّف بها', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (_currentUser.isCourseTeacher)
                  ListTile(
                    leading: const Icon(Icons.menu_book, color: AppTheme.primary),
                    title: Text('الدورات والمسارات التدريبية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('استعراض المسارات وسجل إنجازات الطلاب', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CoursesManagementScreen()));
                    },
                  ),
                if (_currentUser.isExamSupervisor)
                  ListTile(
                    leading: const Icon(Icons.assignment, color: AppTheme.primary),
                    title: Text('إدارة الاختبارات والترشيحات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ترشيح الطلاب لاختبارات القرآن والأجزاء والتجويد', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (ctx) => ExamsScreen(currentUser: _currentUser)));
                    },
                  ),
                const Divider(),
              ],
              if (_currentUser.isFinancialSupervisor)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)),
                  title: Text('سجل الصندوق والمالية والتبرعات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                  subtitle: Text('كشف حركة الصندوق، سندات القبض والصرف', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const FinancialManagementScreen()));
                  },
                ),
              if (_currentUser.isQualitySupervisor)
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Color(0xFF0D5C3A)),
                  title: Text('ملف الجودة والرقابة والتوجيه', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('تقارير الزيارات التفتيشية وتقييم الحلقات', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const QualityManagementScreen()));
                  },
                ),
              if (_currentUser.isQualitySupervisor)
                ListTile(
                  leading: const Icon(Icons.punch_clock, color: AppTheme.primary),
                  title: Text('كشف حضور المعلمين والبدلاء', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherOperationsScreen()));
                  },
                ),
              if (_currentUser.isMemorizationSupervisor)
                ListTile(
                  leading: const Icon(Icons.auto_stories, color: Color(0xFFD97706)),
                  title: Text('شؤون التحفيظ ومنتدى الحفاظ', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                  subtitle: Text('متابعة الخاتمين، روايات القراءة وخطط التثبيت', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const MemorizationForumScreen()));
                  },
                ),
              if (_currentUser.isPreacherSupervisor)
                ListTile(
                  leading: const Icon(Icons.record_voice_over, color: Color(0xFF0D9488)),
                  title: Text('برنامج الفتى الواعظ والأصوات الندية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                  subtitle: Text('رعاية المواهب، خطب الجمعة، التلاوات والأذان', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const PreacherYouthScreen()));
                  },
                ),
            ],

            if (!isTeacher)
              ListTile(
                leading: const Icon(Icons.assignment, color: AppTheme.primary),
                title: Text('إدارة الاختبارات والترشيحات', style: AppTheme.cairoStyle()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => ExamsScreen(currentUser: _currentUser)));
                },
              ),

            ListTile(
              leading: const Icon(Icons.workspace_premium, color: AppTheme.primary),
              title: Text('ملف الإنجاز والشهادات الرقمية', style: AppTheme.cairoStyle()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CoursesManagementScreen(portfolioOnly: true)));
              },
            ),

            ListTile(
              leading: const Icon(Icons.campaign, color: AppTheme.primary),
              title: Text('نشرات وإعلانات المركز', style: AppTheme.cairoStyle()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => AnnouncementsScreen(currentUser: _currentUser)));
              },
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary),
              title: Text('تغيير كلمة المرور', style: AppTheme.cairoStyle()),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordModal();
              },
            ),
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
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD7E8DC)),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x110D5C3A), blurRadius: 14, offset: Offset(0, 5))],
            ),
            child: Text(items[_currentIndex < items.length ? _currentIndex : 0].label ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark, fontSize: 15)),
          ),
        ),
        Expanded(child: IndexedStack(
          index: _currentIndex < screens.length ? _currentIndex : 0,
          children: screens,
        )),
      ]),
      bottomNavigationBar: items.length<2?null:BottomNavigationBar(
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
          'هل تريد تسجيل الخروج من حساب (${_currentUser.fullName})؟\nسيتطلب الدخول مجدداً كتابة كلمة المرور.'
          '${OfflineSyncManager.pendingActionsCount.value + OfflineSyncManager.reviewActionsCount.value > 0 ? '\nتنبيه: توجد عمليات محفوظة على هذا الجهاز لم تُعتمد على الخادم بعد. لن تُحذف عند الخروج، لكنها تحتاج العودة إلى هذا الحساب لمزامنتها.' : ''}',
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

  void _showChangePasswordModal() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                'تغيير كلمة المرور',
                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: currentPwCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPwCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPwCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: AppTheme.cairoStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final current = currentPwCtrl.text.trim();
                      final newPw = newPwCtrl.text;
                      final confirm = confirmPwCtrl.text;

                      if (current.isEmpty || newPw.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('يرجى ملء كافة الحقول', style: AppTheme.cairoStyle())),
                        );
                        return;
                      }
                      if (newPw.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('يجب ألا تقل كلمة المرور عن 8 أحرف', style: AppTheme.cairoStyle())),
                        );
                        return;
                      }
                      if (newPw != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('كلمة المرور وتأكيدها غير متطابقين', style: AppTheme.cairoStyle())),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        final ok = await ApiService.changePassword(
                          currentPassword: current,
                          newPassword: newPw,
                        );
                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          if (ok) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? '✅ تم تحديث كلمة المرور بنجاح' : '❌ فشل تحديث كلمة المرور',
                                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e', style: AppTheme.cairoStyle())),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('تحديث كلمة المرور', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

