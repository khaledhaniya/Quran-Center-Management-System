import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class QualityManagementScreen extends StatefulWidget {
  const QualityManagementScreen({super.key});

  @override
  State<QualityManagementScreen> createState() => _QualityManagementScreenState();
}

class _QualityManagementScreenState extends State<QualityManagementScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _qualityData;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchQualityOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchQualityOverview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getQualityOverview();
      if (mounted) {
        setState(() {
          _qualityData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = (_qualityData?['stats'] as Map<String, dynamic>?) ?? {};
    final circles = (_qualityData?['circles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final courses = (_qualityData?['courses'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0D5C3A),
          icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
          label: Text('زيارة رقابية موحدة', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          onPressed: circles.isEmpty ? null : () => _showNewQualityVisitModal(circles),
        ),
        appBar: AppBar(
          title: Text('ملف الجودة والرقابة والتوجيه', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          backgroundColor: const Color(0xFF0D5C3A),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث مؤشرات الجودة',
              onPressed: _fetchQualityOverview,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                icon: const Icon(Icons.mosque, size: 18),
                text: 'الحلقات القرآنية (${circles.length})',
              ),
              Tab(
                icon: const Icon(Icons.school, size: 18),
                text: 'الدورات العلمية (${courses.length})',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0D5C3A)),
                    SizedBox(height: 14),
                    Text('جاري تحليل مؤشرات الجودة الحقيقية...', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: AppTheme.cairoStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchQualityOverview,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchQualityOverview,
                    child: Column(
                      children: [
                        // Quality KPIs Header
                        _buildQualityKpiHeader(stats),

                        // Tab Views
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildCirclesTab(circles),
                              _buildCoursesTab(courses),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildQualityKpiHeader(Map<String, dynamic> stats) {
    final excellenceRate = stats['excellenceRate'] ?? 0;
    final avgAttendance = stats['avgAttendanceRate'] ?? 0;
    final totalSessions = stats['totalSessions'] ?? 0;
    final totalVerses = stats['totalVerses'] ?? 0;
    final memSessions = stats['memorizationSessions'] ?? 0;
    final revSessions = stats['revisionSessions'] ?? 0;
    final didNotRecite = stats['didNotReciteSessions'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'تقييم الامتياز',
                  value: '$excellenceRate%',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'معدل الحضور',
                  value: '$avgAttendance%',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي الجلسات',
                  value: '$totalSessions',
                  icon: Icons.book_rounded,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFEDE9FE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Sub metrics bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubMetricText('حفظ جديد: $memSessions', Colors.green[700]!),
                _buildSubMetricText('مراجعة: $revSessions', Colors.amber[900]!),
                _buildSubMetricText('لم يُسمّع: $didNotRecite', Colors.red[700]!),
                _buildSubMetricText('الآيات: $totalVerses', Colors.blue[800]!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetricText(String text, Color color) {
    return Text(
      text,
      style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.cairoStyle(fontSize: 9, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                Text(value, style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCirclesTab(List<Map<String, dynamic>> circles) {
    if (circles.isEmpty) {
      return const Center(child: Text('لا توجد حلقات مسجلة حالياً.', style: TextStyle(fontFamily: 'Cairo')));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: circles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _buildCircleQualityCard(circles[i], i + 1),
    );
  }

  Widget _buildCircleQualityCard(Map<String, dynamic> c, int index) {
    final rate = c['attendanceRate'] ?? 100;
    final color = rate >= 90 ? Colors.green : (rate >= 80 ? Colors.blue : Colors.orange);
    final students = (c['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 18,
            child: Text('$index', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  c['name'] ?? 'حلقة قرانية',
                  style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('$rate%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'الشيخ: ${c['teacherName'] ?? 'غير محدد'} (${c['studentCount'] ?? 0} طالب)',
                      style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('حفظ: ${c['memorizationSessions'] ?? 0}', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.green[700]!, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('مراجعة: ${c['revisionSessions'] ?? 0}', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.amber[900]!, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('لم يُسمّع: ${c['didNotReciteSessions'] ?? 0}', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.red[700]!, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('الآيات: ${c['totalVerses'] ?? 0}', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.blue[800]!, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.casino, size: 16, color: Color(0xFFD97706)),
                          label: Text('فحص عينة (Spot-Check)', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                          onPressed: () => _showSpotCheckDialog(c),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.person_pin, size: 16, color: Color(0xFF2563EB)),
                          label: Text('المعلم البديل', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                          onPressed: () => _showSubstituteModeDialog(c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('سجل تفصيلي لطلاب الحلقة (${students.length}):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569))),
                  const SizedBox(height: 8),
                  if (students.isEmpty)
                    const Text('لا يوجد طلاب مسجلين في هذه الحلقة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey))
                  else
                    ...students.map((st) {
                      final stRate = st['attendanceRate'] ?? 100;
                      final stRateColor = stRate >= 90 ? Colors.green : (stRate >= 80 ? Colors.blue : Colors.orange);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(st['fullName'] ?? 'طالب', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(
                                    'حضور: ${st['presentCount'] ?? 0} | غياب: ${st['absentCount'] ?? 0} | لم يُسمّع: ${st['didNotReciteCount'] ?? 0} | الآيات: ${st['totalVerses'] ?? 0}',
                                    style: AppTheme.cairoStyle(fontSize: 10, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: stRateColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text('$stRate%', style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stRateColor)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesTab(List<Map<String, dynamic>> courses) {
    if (courses.isEmpty) {
      return const Center(child: Text('لا توجد دورات علمية مسجلة حالياً.', style: TextStyle(fontFamily: 'Cairo')));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _buildCourseQualityCard(courses[i], i + 1),
    );
  }

  Widget _buildCourseQualityCard(Map<String, dynamic> crs, int index) {
    final rate = crs['attendanceRate'] ?? 100;
    final color = rate >= 90 ? Colors.green : (rate >= 75 ? Colors.blue : Colors.orange);
    final students = (crs['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0D5C3A).withValues(alpha: 0.15),
            radius: 18,
            child: const Icon(Icons.school, color: Color(0xFF0D5C3A), size: 18),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  crs['name'] ?? 'دورة علمية',
                  style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('$rate%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          subtitle: Text(
            'المدرس: ${crs['teacherName'] ?? 'غير محدد'} | المسجلين: ${crs['enrolledCount'] ?? 0} | المجازين: ${crs['passedCount'] ?? 0}',
            style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF64748B)),
          ),
          children: [
            const Divider(height: 1),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الطلاب المسجلون بالدورة (${students.length}):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569))),
                  const SizedBox(height: 8),
                  if (students.isEmpty)
                    const Text('لا يوجد طلاب مسجلون في هذه الدورة حالياً.', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey))
                  else
                    ...students.map((st) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(st['studentName'] ?? 'طالب', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(
                                    'الحالة: ${st['status'] ?? 'مسجل'} | الدرجة: ${st['grade'] ?? '-'} | حضور: ${st['presentCount'] ?? 0} | غياب: ${st['absentCount'] ?? 0}',
                                    style: AppTheme.cairoStyle(fontSize: 10, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewQualityVisitModal(List<Map<String, dynamic>> circles) {
    int selectedCircleId = circles.first['id'] as int;
    final supervisorCtrl = TextEditingController(text: 'مشرف الجودة الميداني');
    final notesCtrl = TextEditingController();
    double punctuality = 95;
    double classMgmt = 90;
    double tajweed = 95;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            top: 20,
            left: 16,
            right: 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in, color: Color(0xFF0D5C3A)),
                    const SizedBox(width: 8),
                    Text('نموذج الزيارة الرقابية الموحد', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0D5C3A))),
                  ],
                ),
                const SizedBox(height: 16),
                Text('اختر الحلقة القرآنية:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedCircleId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: circles.map((c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text('${c['name']} (${c['teacherName'] ?? 'بدون محفظ'})', style: AppTheme.cairoStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCircleId = val);
                  },
                ),
                const SizedBox(height: 12),
                Text('اسم المشرف الزائر:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: supervisorCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: AppTheme.cairoStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معايير التقييم الرقابي الرقمي:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF0D5C3A))),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1. الحضور والانضباط (30%):', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('${punctuality.toInt()}%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800]!)),
                        ],
                      ),
                      Slider(
                        value: punctuality,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: const Color(0xFF0D5C3A),
                        onChanged: (v) => setModalState(() => punctuality = v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('2. إدارة الحلقة والسمت (30%):', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('${classMgmt.toInt()}%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800]!)),
                        ],
                      ),
                      Slider(
                        value: classMgmt,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: const Color(0xFF0D5C3A),
                        onChanged: (v) => setModalState(() => classMgmt = v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('3. تصحيح التلاوة والتجويد (40%):', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('${tajweed.toInt()}%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[900]!)),
                        ],
                      ),
                      Slider(
                        value: tajweed,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: const Color(0xFF0D5C3A),
                        onChanged: (v) => setModalState(() => tajweed = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('الملاحظات والتوجيهات:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'اكتب الملاحظات والتوجيهات للشيخ...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: AppTheme.cairoStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5C3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save),
                    label: Text('حفظ وتوثيق الزيارة الرقابية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final saved = await ApiService.createQualityVisit({
                          'circleId': selectedCircleId,
                          'supervisorName': supervisorCtrl.text.trim(),
                          'visitDate': DateTime.now().toIso8601String().substring(0, 10),
                          'punctualityScore': punctuality.toInt(),
                          'classManagementScore': classMgmt.toInt(),
                          'tajweedCorrectionScore': tajweed.toInt(),
                          'notes': notesCtrl.text.trim(),
                          'isSubstituteModeActive': false,
                        });
                if (!saved) throw StateError('لم يتم حفظ الزيارة على الخادم.');
                        if (!mounted || !context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم توثيق الزيارة الرقابية بنجاح! 📋'), backgroundColor: Colors.green),
                        );
                        _fetchQualityOverview();
                      } catch (e) {
                        if (!mounted || !context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل التوثيق: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSpotCheckDialog(Map<String, dynamic> circle) async {
    final circleId = circle['id'] as int;
    final circleName = circle['name'] ?? 'الحلقة';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0D5C3A))),
    );

    try {
      final res = await ApiService.getSpotCheckCandidates(circleId);
      if (!mounted || !context.mounted) return;
      Navigator.pop(context); // close loader

      final candidates = (res['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (candidates.isEmpty) {
        if (!mounted || !context.mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('فحص عينات عشوائية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            content: Text('لا توجد عينات لطلاب مسجلين في $circleName حالياً.', style: AppTheme.cairoStyle(fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ],
          ),
        );
        return;
      }

      if (!mounted || !context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.casino, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('فحص عينات عشوائية - $circleName', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تم سحب ${candidates.length} طلاب عشوائياً لفحص جودة التثبيت ومطابقة السجل:', style: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  ...candidates.map((st) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st['fullName'] ?? 'طالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0D5C3A))),
                        const SizedBox(height: 4),
                        Text('الأجزاء: ${st['completedAjzaa'] ?? 0} | المستهدف: ${st['targetAjzaaCount'] ?? 1}', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF475569))),
                        const SizedBox(height: 4),
                        Text('المحفوظ السابق: ${st['previousQuranMemorization'] ?? 'لا يوجد'}', style: AppTheme.cairoStyle(fontSize: 10, color: const Color(0xFF64748B))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final saved = await ApiService.createQualityVisit({
                  'circleId': circleId,
                  'supervisorName': 'مشرف الجودة الميداني',
                  'visitDate': DateTime.now().toIso8601String().substring(0, 10),
                  'punctualityScore': 95,
                  'classManagementScore': 90,
                  'tajweedCorrectionScore': 95,
                  'notes': '[فحص عينات عشوائية]: تم فحص ${candidates.length} طلاب بنجاح.',
                  'isSubstituteModeActive': false,
                });
                if (!saved) throw StateError('لم يتم حفظ الزيارة على الخادم.');
                if (!mounted || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم توثيق فحص العينات العشوائية بنجاح! 🎲'), backgroundColor: Colors.green),
                );
              },
              child: const Text('اعتماد وتوثيق الفحص'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      Navigator.pop(context); // close loader
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر جلب العينات: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSubstituteModeDialog(Map<String, dynamic> circle) {
    final circleId = circle['id'] as int;
    final circleName = circle['name'] ?? 'الحلقة';
    final subTeacherCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'غياب الشيخ الأساسي');
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person_pin, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('وضع المعلم البديل - $circleName', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اسم الشيخ أو المشرف البديل:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: subTeacherCtrl,
                decoration: InputDecoration(
                  hintText: 'اكتب اسم الشيخ البديل...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: AppTheme.cairoStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text('سبب التغطية البديلة:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: AppTheme.cairoStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('تفعيل التغطية البديلة للحلقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                value: isActive,
                onChanged: (v) => setDialogState(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                final subName = subTeacherCtrl.text.trim();
                if (subName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الشيخ البديل')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final res = await ApiService.toggleSubstituteMode(
                    circleId: circleId,
                    supervisorName: subName,
                    reason: reasonCtrl.text.trim(),
                    activate: isActive,
                  );
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'تم تحديث وضع المعلم البديل'), backgroundColor: Colors.green),
                  );
                  _fetchQualityOverview();
                } catch (e) {
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل العملية: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تأكيد التكليف'),
            ),
          ],
        ),
      ),
    );
  }
}
