import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'student_360_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User currentUser;
  final Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.currentUser,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalCircles = 0;
  int _pendingExams = 0;
  int _scheduledExams = 0;
  int _completedExams = 0;
  List<Student> _myChildren = [];
  int? _selectedChildId;
  bool _isLoading = true;

  bool _isMorning = true;
  bool _isAzkarExpanded = false;

  final List<String> _morningAzkar = [
    'أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له.',
    'اللهم بك أصبحنا، وبك أمسينا، وبك نحيا، وبك نموت، وإليك النشور.',
    'رضيت بالله رباً، وبالإسلام ديناً، وبمحمد صلى الله عليه وسلم نبياً.',
    'يا حي يا قيوم برحمتك أستغيث، أصلح لي شأني كله ولا تكلني إلى نفسي طرفة عين.',
  ];

  final List<String> _eveningAzkar = [
    'أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له.',
    'اللهم بك أمسينا، وبك أصبحنا، وبك نحيا، وبك نموت، وإليك المصير.',
    'أعوذ بكلمات الله التامات من شر ما خلق.',
    'اللهم إني أسألك العفو والعافية في الدنيا والآخرة.',
  ];

  final List<String> _faithReminders = [
    '﴿ خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ ﴾ - حديث شريف',
    '﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾ - سورة المزمل',
    '﴿ إِنَّ هَذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ ﴾ - سورة الإسراء',
    '﴿ يَرْفَعِ اللَّهُ الَّذِينَ آمَنُوا مِنْكُمْ وَالَّذِينَ أُوتُوا الْعِلْمَ دَرَجَاتٍ ﴾ - سورة المجادلة',
    '«اقْرَءُوا الْقُرْآنَ فَإِنَّهُ يَأْتِي يَوْمَ الْقِيَامَةِ شَفِيعًا لأَصْحَابِهِ» - رواه مسلم',
  ];

  late String _currentFaithReminder;

  @override
  void initState() {
    super.initState();
    _currentFaithReminder = _faithReminders[Random().nextInt(_faithReminders.length)];
    _loadStats();
  }

  void _loadStats() async {
    try {
      final role = widget.currentUser.role;
      var students = await ApiService.getStudents();
      var teachers = await ApiService.getTeachers();
      var circles = await ApiService.getCircles();

      List<ExamNomination> nominations = [];
      try {
        nominations = await ApiService.getNominations();
      } catch (_) {}

      _pendingExams = nominations.where((n) => n.status == 'Pending').length;
      _scheduledExams = nominations.where((n) => n.status == 'Scheduled').length;
      _completedExams = nominations.where((n) => n.status == 'Completed').length;

      if (role == 'Parent') {
        _myChildren = students;
        if (_myChildren.isEmpty) {
          try {
            final rawAudit = await ApiService.getParentAuditData();
            for (var p in rawAudit) {
              final pName = (p['parentName'] ?? '').toString().trim();
              final pIdNum = (p['parentIdentityNumber'] ?? '').toString().trim();
              final userPId = (widget.currentUser.parentId ?? widget.currentUser.id).toString();

              if (pName == widget.currentUser.fullName.trim() || 
                  (pIdNum.isNotEmpty && pIdNum == widget.currentUser.username) || 
                  (p['parentId'] != null && p['parentId'].toString() == userPId)) {
                final childrenArr = p['children'] as List? ?? [];
                _myChildren = childrenArr.map((ch) => Student(
                  id: ch['id'] as int? ?? 0,
                  fullName: (ch['fullName'] ?? 'طالب').toString(),
                  circleName: ch['circleName']?.toString(),
                  studentIdentityNumber: ch['studentIdentityNumber']?.toString(),
                  isActive: true,
                )).toList();
                break;
              }
            }
          } catch (_) {}
        }

        if (_myChildren.isNotEmpty && _selectedChildId == null) {
          _selectedChildId = _myChildren.first.id;
        }
        final parentCircleNames = _myChildren.map((s) => s.circleName ?? 'غير مسند').toSet();
        _totalStudents = _myChildren.length;
        _totalCircles = parentCircleNames.where((c) => c != 'غير مسند').length;
        _totalTeachers = _totalCircles;
      } else if (role == 'ExamSupervisor') {
        final nominations = await ApiService.getNominations();
        _pendingExams = nominations.where((n) => n.status == 'Pending').length;
        _scheduledExams = nominations.where((n) => n.status == 'Scheduled').length;
        _completedExams = nominations.where((n) => n.status == 'Completed').length;
      } else if (role == 'Teacher' && widget.currentUser.teacherId != null) {
        circles = circles.where((c) => c.teacherId == widget.currentUser.teacherId).toList();
        final teacherCircleIds = circles.map((c) => c.id).toSet();
        students = students.where((s) => s.circleId != null && teacherCircleIds.contains(s.circleId)).toList();
        teachers = teachers.where((t) => t.id == widget.currentUser.teacherId).toList();
        _totalStudents = students.length;
        _totalCircles = circles.length;
        _totalTeachers = teachers.length;
      } else {
        _totalStudents = students.length;
        _totalTeachers = teachers.length;
        _totalCircles = circles.length;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final azkarList = _isMorning ? _morningAzkar : _eveningAzkar;
    final role = widget.currentUser.role;
    final isTeacher = role == 'Teacher';
    final isParent = role == 'Parent';
    final isStudent = role == 'Student';
    final isSupervisor = role == 'ExamSupervisor';

    String sectionTitle = 'إحصائيات المنظومة العامة للمركز';
    if (isStudent) {
      sectionTitle = 'سجل حفظك وإنجازك الشخصي';
    } else if (isParent) {
      sectionTitle = 'إحصائيات متابعة أبنائك';
    } else if (isSupervisor) {
      sectionTitle = 'إحصائيات الإشراف والاختبارات الشفوية';
    } else if (isTeacher) {
      sectionTitle = 'إحصائيات حلقة وتسميع المعلم';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.accent,
                    child: Text(
                      widget.currentUser.fullName.isNotEmpty ? widget.currentUser.fullName[0] : 'م',
                      style: AppTheme.cairoStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً وسهلاً بك، ${widget.currentUser.fullName}',
                          style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isParent
                              ? 'متابعة أبنائك وسجل الحضور والتسميع'
                              : isSupervisor
                                  ? 'مركز الاعتماد والرصد والاختبارات الشفوية'
                                  : 'مرحباً بك في منصة مركز تحفيظ القرآن الكريم',
                          style: AppTheme.cairoStyle(fontSize: 13, color: AppTheme.accentLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: AppTheme.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, color: AppTheme.accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentFaithReminder,
                      style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ═══ STATS HEADER ROW ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionTitle,
                style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primary),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadStats();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ═══ STAT CARDS TAILORED FOR EACH ROLE ═══
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
              : isSupervisor
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'بانتظار الجدولة',
                                count: '$_pendingExams',
                                icon: Icons.hourglass_top,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                title: 'اختبارات مجدولة',
                                count: '$_scheduledExams',
                                icon: Icons.calendar_month,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                title: 'مجتازة ومعتمدة',
                                count: '$_completedExams',
                                icon: Icons.check_circle,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: const Color(0xFF0D5C3A).withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFF0D5C3A), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_turned_in, color: Color(0xFF0D5C3A), size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('إدارة الاختبارات والجدولة الشفوية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('يمكنك رصد الدرجات واعتتماد شهادات الطلاب فور اجتيازهم', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D5C3A),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () {
                                    if (widget.onNavigateTab != null) {
                                      widget.onNavigateTab!(1);
                                    }
                                  },
                                  child: Text('فتح الشاشة', style: AppTheme.cairoStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : isStudent
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'الحفظ والجزئيات',
                                    count: 'مستمر',
                                    icon: Icons.menu_book,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'نسبة التقييم',
                                    count: 'ممتاز',
                                    icon: Icons.stars,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    title: 'معدل الحضور',
                                    count: 'منتظم',
                                    icon: Icons.verified,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Card(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppTheme.primary, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.school, color: AppTheme.primary, size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('سجل التسميع والحفظ المباشر (360°)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('تابع درجاتك اليومية وسجل الحضور ومساقاتك القرآنية بالتفصيل', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Student360Screen(initialStudentId: widget.currentUser.studentId),
                                          ),
                                        );
                                      },
                                      child: Text('فتح السجل', style: AppTheme.cairoStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                  : isParent
                      ? const SizedBox.shrink()
                      : Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: isTeacher ? 'طلابك بالحلقة' : 'إجمالي الطلاب',
                                count: '$_totalStudents',
                                icon: Icons.person_pin,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                title: isTeacher ? 'حلقاتك' : 'الحلقات',
                                count: '$_totalCircles',
                                icon: Icons.groups,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                title: isTeacher ? 'محفظ الحلقة' : 'المعلمون',
                                count: '$_totalTeachers',
                                icon: Icons.record_voice_over,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
          const SizedBox(height: 12),

          // ═══ PARENT MULTI-CHILD SELECTION & MANAGEMENT SECTION ═══
          if (isParent && !_isLoading) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('أبنائي ومتابعة الحضور والتسميع (${_myChildren.length} أبناء)', style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),

            // Multi-Child Switcher Bar
            if (_myChildren.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('جميع الأبناء (${_myChildren.length})', style: AppTheme.cairoStyle(fontSize: 12, color: _selectedChildId == null ? Colors.white : AppTheme.primary)),
                      selected: _selectedChildId == null,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                      onSelected: (_) => setState(() => _selectedChildId = null),
                    ),
                    const SizedBox(width: 8),
                    ..._myChildren.map((child) {
                      final isSel = _selectedChildId == child.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: isSel ? Colors.white : AppTheme.primary,
                            child: Text(child.fullName.isNotEmpty ? child.fullName[0] : 'ط', style: TextStyle(fontSize: 10, color: isSel ? AppTheme.primary : Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          label: Text(child.fullName, style: AppTheme.cairoStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
                          selected: isSel,
                          selectedColor: AppTheme.primary,
                          onSelected: (_) => setState(() => _selectedChildId = child.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            if (_myChildren.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text('لا يوجد أبناء مسجلون تحت حسابك حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                  ),
                ),
              )
            else
              Column(
                children: (_selectedChildId == null ? _myChildren : _myChildren.where((c) => c.id == _selectedChildId)).map((child) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                child: Text(
                                  child.fullName.isNotEmpty ? child.fullName[0] : 'ط',
                                  style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(child.fullName, style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text('الحلقة القرآنية: ${child.circleName ?? "غير مسند حلقة"}', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: child.isActive ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  child.isActive ? 'نشط بالمركز' : 'حساب معطل',
                                  style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: child.isActive ? Colors.green : Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Student360Screen(initialStudentId: child.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.badge, color: Colors.white, size: 18),
                                  label: Text('الملف الموحد (360°)', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: const BorderSide(color: AppTheme.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showProfileUpdateRequestModal(child),
                                  icon: const Icon(Icons.edit_note, color: AppTheme.primary, size: 18),
                                  label: Text('طلب تعديل البيانات', style: AppTheme.cairoStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 20),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _isMorning ? Icons.wb_sunny : Icons.nights_stay,
                    color: _isMorning ? Colors.orange : Colors.indigo,
                  ),
                  title: Text(
                    _isMorning ? 'أذكار الصباح والمسند اليومي' : 'أذكار المساء والمسند اليومي',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        _isMorning = !_isMorning;
                      });
                    },
                    child: Text(_isMorning ? 'التحويل للمساء' : 'التحويل للصباح', style: AppTheme.cairoStyle(fontSize: 12)),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      for (var zikr in (showAllAzkar ? azkarList : azkarList.take(2)))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              Expanded(
                                child: Text(
                                  zikr,
                                  style: AppTheme.cairoStyle(fontSize: 13, color: AppTheme.textDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAzkarExpanded = !_isAzkarExpanded;
                    });
                  },
                  child: Text(
                    _isAzkarExpanded ? 'عرض أقل' : 'عرض المزيد من الأذكار',
                    style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get showAllAzkar => _isAzkarExpanded;

  void _showProfileUpdateRequestModal(Student child) {
    final contactController = TextEditingController(text: child.familyContact);
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('طلب تعديل بيانات الابن (${child.fullName})', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('أدخل التعديلات أو رقم التواصل المحدث لرفع طلب مباشر لإدارة المركز للمراجعة واعتماد التعديل:', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم هاتف التواصل والعائلة المحدث'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'تفاصيل التغييرات المطلوبة (السكن، الحالة الصحية، الكفالة...) *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              if (notesController.text.trim().isEmpty) return;

              final changes = <String, String>{
                'familyContact': contactController.text.trim(),
                'notes': notesController.text.trim(),
              };

              final ok = await ApiService.submitProfileUpdateRequest(
                studentId: child.id,
                requestedByRole: 'Parent',
                requestedByName: widget.currentUser.fullName,
                changes: changes,
              );

              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);

              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم رفع طلب التعديل بنجاح إلى إدارة المركز وسيتم مراجعته واعتماده.'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('حدث خطأ أثناء تقديم طلب التعديل'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('تقديم الطلب للإدارة'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            count,
            style: AppTheme.cairoStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
