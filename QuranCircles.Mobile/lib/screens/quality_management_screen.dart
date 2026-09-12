import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class QualityManagementScreen extends StatefulWidget {
  const QualityManagementScreen({Key? key}) : super(key: key);

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
                    }).toList(),
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
                    }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
