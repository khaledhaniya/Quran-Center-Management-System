import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CircleAttendanceScreen extends StatefulWidget {
  final User currentUser;

  const CircleAttendanceScreen({super.key, required this.currentUser});

  @override
  State<CircleAttendanceScreen> createState() => _CircleAttendanceScreenState();
}

class _CircleAttendanceScreenState extends State<CircleAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Circle> _circles = [];
  Circle? _selectedCircle;
  List<Student> _students = [];
  List<Student> _allCenterStudents = [];
  final Map<int, int> _attendanceStatus = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _allowTeacherSelfEnrollment = true;

  // Tab 2: Sessions State
  Student? _selectedStudentForSessions;
  List<Map<String, dynamic>> _studentSessions = [];
  bool _isLoadingSessions = false;

  // Tab 4: Lottery State
  bool _excludeAbsentees = true;
  Student? _lotteryWinner;
  bool _isDrawingLottery = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadInitialData() async {
    try {
      final circlesFuture = ApiService.getCircles();
      final studentsFuture = ApiService.getStudents();
      final settingsFuture = ApiService.getSystemSettings();

      final results = await Future.wait([circlesFuture, studentsFuture, settingsFuture]);

      var circlesList = results[0] as List<Circle>;
      final allStudents = results[1] as List<Student>;
      final settings = results[2] as Map<String, dynamic>?;

      final isTeacher = widget.currentUser.role == 'Teacher';
      if (isTeacher && widget.currentUser.teacherId != null) {
        circlesList = circlesList.where((c) => c.teacherId == widget.currentUser.teacherId).toList();
      }

      if (mounted) {
        setState(() {
          _circles = circlesList;
          _allCenterStudents = allStudents;
          if (settings != null) {
            _allowTeacherSelfEnrollment = settings['allowTeacherSelfEnrollment'] == true;
          }
          if (circlesList.isNotEmpty) {
            _selectedCircle = circlesList.first;
            _filterStudents(allStudents);
          }
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

  void _filterStudents(List<Student> allStudents) {
    if (_selectedCircle == null) return;
    final filtered = allStudents.where((s) => s.circleId == _selectedCircle!.id).toList();
    setState(() {
      _students = filtered;
      _attendanceStatus.clear();
      for (var s in filtered) {
        _attendanceStatus[s.id] = 1; // 1: حاضر
      }
      if (filtered.isNotEmpty && _selectedStudentForSessions == null) {
        _selectStudentForSessions(filtered.first);
      }
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _saveAttendance() async {
    if (_selectedCircle == null || _students.isEmpty) return;

    setState(() => _isSaving = true);

    final dateStr = _formatDate(_selectedDate);
    final records = _students.map((s) {
      return {
        'studentId': s.id,
        'status': _attendanceStatus[s.id] ?? 1,
      };
    }).toList();

    try {
      final ok = await ApiService.saveCircleAttendance(_selectedCircle!.id, dateStr, records);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ وتحديث سجل حضور وغياب الحلقة بنجاح! ☁️'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Student Enrollment Modal (Controlled by CMS) ---
  void _showEnrollStudentModal() {
    if (!_allowTeacherSelfEnrollment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تنسيب الطلاب بواسطة المعلم معطّل حالياً من قبل إدارة المنظومة.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCircle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الحلقة أولاً.'), backgroundColor: Colors.orange),
      );
      return;
    }

    String searchFilter = '';
    String filterType = 'all'; // all, unassigned, assigned
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchFilter.trim().toLowerCase();
          final filteredList = _allCenterStudents.where((s) {
            final hasCircle = s.circleId != null && s.circleId! > 0;
            if (filterType == 'unassigned' && hasCircle) return false;
            if (filterType == 'assigned' && !hasCircle) return false;

            if (query.isEmpty) return true;
            return s.fullName.toLowerCase().contains(query) ||
                (s.studentIdentityNumber != null && s.studentIdentityNumber!.contains(query)) ||
                (s.familyContact != null && s.familyContact!.contains(query));
          }).toList();

          final currentCount = _students.length;
          const maxCap = 20;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_add_alt_1, color: AppTheme.primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'تنسيب طالب للحلقة القرآنيّة',
                            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentCount >= maxCap ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: currentCount >= maxCap ? Colors.red.shade200 : Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سعة حلقة (${_selectedCircle!.name}): $currentCount / $maxCap طالب',
                          style: AppTheme.cairoStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: currentCount >= maxCap ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                        if (currentCount >= maxCap)
                          const Text('الحلقة ممتلئة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search Box
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم، رقم الهوية أو الهاتف...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onChanged: (val) => setModalState(() => searchFilter = val),
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('جميع الطلاب'),
                        selected: filterType == 'all',
                        onSelected: (val) => setModalState(() => filterType = 'all'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('غير مسندين'),
                        selected: filterType == 'unassigned',
                        onSelected: (val) => setModalState(() => filterType = 'unassigned'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('مسندين بحلقات'),
                        selected: filterType == 'assigned',
                        onSelected: (val) => setModalState(() => filterType = 'assigned'),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Students List
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(child: Text('لا توجد نتائج مطابقة لبحثك', style: AppTheme.cairoStyle()))
                        : ListView.builder(
                            itemCount: filteredList.length,
                            itemBuilder: (listCtx, idx) {
                              final st = filteredList[idx];
                              final isAlreadyInCircle = st.circleId == _selectedCircle!.id;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isAlreadyInCircle ? Colors.green.shade100 : Colors.grey.shade200,
                                    child: Icon(
                                      isAlreadyInCircle ? Icons.check : Icons.person,
                                      color: isAlreadyInCircle ? Colors.green.shade800 : Colors.grey.shade700,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(st.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  subtitle: Text(
                                    'الهوية: ${st.studentIdentityNumber ?? "-"} | الحلقة الحالية: ${st.circleName ?? "غير مسند"}',
                                    style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                  trailing: isAlreadyInCircle
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Text('منسّب بحلقتك', style: AppTheme.cairoStyle(fontSize: 10.5, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: const Size(60, 32),
                                          ),
                                          onPressed: (isSubmitting || currentCount >= maxCap)
                                              ? null
                                              : () async {
                                                  setModalState(() => isSubmitting = true);
                                                  try {
                                                    await ApiService.enrollStudentInCircle(_selectedCircle!.id, st.id);
                                                    if (!mounted) return;
                                                    Navigator.pop(ctx);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('تم تنسيب الطالب (${st.fullName}) للحلقة بنجاح!'), backgroundColor: Colors.green),
                                                    );
                                                    // Refresh
                                                    final freshStudents = await ApiService.getStudents();
                                                    setState(() {
                                                      _allCenterStudents = freshStudents;
                                                      _filterStudents(freshStudents);
                                                    });
                                                  } catch (e) {
                                                    setModalState(() => isSubmitting = false);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                                    );
                                                  }
                                                },
                                          child: Text('تنسيب +', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Sessions Tab Logic ---
  void _selectStudentForSessions(Student student) async {
    setState(() {
      _selectedStudentForSessions = student;
      _isLoadingSessions = true;
    });

    try {
      final sessions = await ApiService.getStudentSessions(student.id);
      if (mounted) {
        setState(() {
          _studentSessions = sessions;
          _isLoadingSessions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  void _showRecitationModal(Student student, {bool viaLottery = false}) {
    final surahController = TextEditingController(text: 'البقرة');
    final fromVerseController = TextEditingController(text: '1');
    final toVerseController = TextEditingController(text: '10');
    final notesController = TextEditingController();
    int assessmentLevel = 1;
    int recitationType = 1; // 1: حفظ جديد, 2: مراجعة وتثبيت

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDidNotRecite = assessmentLevel == 6;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('تسجيل تسميع اليوم للطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            student.fullName,
                            style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        if (viaLottery)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('بالقرعة 🎲', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              '📖 حفظ جديد',
                              style: AppTheme.cairoStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: recitationType == 1 ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          selected: recitationType == 1,
                          selectedColor: AppTheme.primary,
                          onSelected: (val) {
                            if (val) setModalState(() => recitationType = 1);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              '🔁 مراجعة وتثبيت',
                              style: AppTheme.cairoStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: recitationType == 2 ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          selected: recitationType == 2,
                          selectedColor: Colors.amber[800],
                          onSelected: (val) {
                            if (val) setModalState(() => recitationType = 2);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Opacity(
                    opacity: isDidNotRecite ? 0.5 : 1.0,
                    child: TextField(
                      controller: surahController,
                      enabled: !isDidNotRecite,
                      decoration: const InputDecoration(labelText: 'اسم السورة *'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Opacity(
                    opacity: isDidNotRecite ? 0.5 : 1.0,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fromVerseController,
                            enabled: !isDidNotRecite,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'من آية *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: toVerseController,
                            enabled: !isDidNotRecite,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'إلى آية *'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: assessmentLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'التقييم ومستوى الحفظ *'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('ممتاز (بدون أخطاء)')),
                      DropdownMenuItem(value: 2, child: Text('جيد جداً (1 - 2 خطأ)')),
                      DropdownMenuItem(value: 3, child: Text('جيد (3 - 4 أخطاء)')),
                      DropdownMenuItem(value: 4, child: Text('متوسط (بحاجة لتثبيت)')),
                      DropdownMenuItem(value: 5, child: Text('ضعيف (إعادة التسميع)')),
                      DropdownMenuItem(value: 6, child: Text('لم يُسمّع اليوم ❌')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => assessmentLevel = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات وتوجيهات الشيخ للمعلم والولي (اختياري)',
                      hintText: 'أحكام تجويد، مخارج حروف، تنبيهات...',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () async {
                  final sName = surahController.text.trim();
                  final fromV = int.tryParse(fromVerseController.text.trim()) ?? 1;
                  final toV = int.tryParse(toVerseController.text.trim()) ?? 1;

                  if (!isDidNotRecite && sName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء إدخال اسم السورة'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);

                  try {
                    final ok = await ApiService.saveRecitationSession(
                      studentId: student.id,
                      sessionDate: _formatDate(_selectedDate),
                      surahName: isDidNotRecite ? 'لم يُسمّع' : sName,
                      fromVerse: isDidNotRecite ? 0 : fromV,
                      toVerse: isDidNotRecite ? 0 : toV,
                      assessment: assessmentLevel,
                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                      viaLottery: viaLottery,
                      recitationType: recitationType,
                    );

                    if (!mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم توثيق جلسة التسميع بنجاح! 📖'), backgroundColor: Colors.green),
                      );
                      if (_selectedStudentForSessions?.id == student.id) {
                        _selectStudentForSessions(student);
                      }
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('حفظ التسميع'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Tab 4: Lottery Logic ---
  void _executeLottery() async {
    if (_selectedCircle == null || _students.isEmpty) return;

    setState(() {
      _isDrawingLottery = true;
      _lotteryWinner = null;
    });

    List<Student> pool = _students;
    if (_excludeAbsentees) {
      pool = _students.where((s) => (_attendanceStatus[s.id] ?? 1) != 2).toList();
    }

    if (pool.isEmpty) {
      setState(() => _isDrawingLottery = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب متاحين للسحب (جميع الطلاب غائبون أو القائمة فارغة).'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Try backend API first, fallback to pool random
    Student winner;
    try {
      final res = await ApiService.drawLottery(_selectedCircle!.id, _formatDate(_selectedDate));
      final winnerId = res['studentId'];
      final matched = _students.firstWhere((s) => s.id == winnerId, orElse: () => pool[Random().nextInt(pool.length)]);
      winner = matched;
    } catch (_) {
      winner = pool[Random().nextInt(pool.length)];
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isDrawingLottery = false;
        _lotteryWinner = winner;
      });
    }
  }

  // --- Export & Printable Roster Actions ---
  void _openPrintableRoster({bool downloadPdf = false}) async {
    final tId = widget.currentUser.teacherId ?? widget.currentUser.id;
    final dateStr = _formatDate(_selectedDate);
    final url = '${ApiService.baseUrl}/teachers/$tId/comprehensive-report/printable?fromDate=$dateStr&download=${downloadPdf ? "pdf" : "none"}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الرابط: $url'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('شؤون وتسميع الحلقة القرآنيّة'),
            if (_selectedCircle != null)
              Text(
                'حلقة: ${_selectedCircle!.name} | ${_students.length} طالب',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.how_to_reg, size: 20), text: 'تحضير الغياب والحضور'),
            Tab(icon: Icon(Icons.menu_book, size: 20), text: 'سجل التسميع والحفظ'),
            Tab(icon: Icon(Icons.table_chart, size: 20), text: 'كشف المتابعة الشامل'),
            Tab(icon: Icon(Icons.casino, size: 20), text: 'القرعة الإلكترونية'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _circles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد حلقة قرآنية مسندة إليك حالياً',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'إذا كان لديك تكليف إداري آخر (كالجودة، شؤون التحفيظ، أو الفتى الواعظ)، يمكنك الوصول له من القائمة الجانبية.',
                          textAlign: TextAlign.center,
                          style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAttendanceTab(),
                    _buildSessionsTab(),
                    _buildComprehensiveRosterTab(),
                    _buildLotteryTab(),
                  ],
                ),
    );
  }

  // ==========================================
  // TAB 1: تسجيل الحضور والغياب (مع التاريخ وتنسيب الطلاب)
  // ==========================================
  Widget _buildAttendanceTab() {
    return Column(
      children: [
        // Control Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Circle>(
                      value: _selectedCircle,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الحلقة المستهدفة',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _circles.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _selectedCircle = val;
                          _filterStudents(_allCenterStudents);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2022),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 15, color: AppTheme.primary),
                      label: Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Action Ribbon: Capacity + Enroll Student Button (Controlled by CMS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'عدد الطلاب: ${_students.length}',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  if (_allowTeacherSelfEnrollment)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      onPressed: _showEnrollStudentModal,
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: Text(
                        'تنسيب طالب للحلقة',
                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Students Attendance List
        Expanded(
          child: _students.isEmpty
              ? Center(child: Text('لا يوجد طلاب مسندون لهذه الحلقة حالياً', style: AppTheme.cairoStyle()))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _students.length,
                  itemBuilder: (ctx, index) {
                    final s = _students[index];
                    final currentStatus = _attendanceStatus[s.id] ?? 1;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.fullName,
                                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'الهوية: ${s.studentIdentityNumber ?? "غير مسجل"}',
                                    style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Attendance Toggle Choice
                            ToggleButtons(
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 30),
                              borderRadius: BorderRadius.circular(8),
                              selectedColor: Colors.white,
                              fillColor: currentStatus == 1
                                  ? Colors.green.shade600
                                  : (currentStatus == 2
                                      ? Colors.red.shade600
                                      : (currentStatus == 3 ? Colors.orange.shade700 : Colors.amber.shade800)),
                              isSelected: [
                                currentStatus == 1,
                                currentStatus == 2,
                                currentStatus == 3,
                                currentStatus == 4,
                              ],
                              onPressed: (btnIndex) {
                                setState(() {
                                  _attendanceStatus[s.id] = btnIndex + 1;
                                });
                              },
                              children: const [
                                Text('حاضر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('غائب', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('متأخر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('بعذر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Save Button
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveAttendance,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload, color: Colors.white),
              label: Text(
                _isSaving ? 'جاري الحفظ على السيرفر...' : 'حفظ وتحديث سجل الحضور للحلقتك',
                style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: سجل التسميع وحفظ الآيات
  // ==========================================
  Widget _buildSessionsTab() {
    return Column(
      children: [
        // Students Selector Horizontal Ribbon
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey.shade50,
          child: SizedBox(
            height: 48,
            child: _students.isEmpty
                ? const Center(child: Text('لا يوجد طلاب'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _students.length,
                    itemBuilder: (ctx, idx) {
                      final s = _students[idx];
                      final isSelected = _selectedStudentForSessions?.id == s.id;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          avatar: Icon(Icons.person, size: 14, color: isSelected ? Colors.white : AppTheme.primary),
                          label: Text(s.fullName, style: AppTheme.cairoStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (val) {
                            if (val) _selectStudentForSessions(s);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Selected Student Header & Add Recitation Button
        if (_selectedStudentForSessions != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStudentForSessions!.fullName,
                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'جلسات التسميع المسجلة: ${_studentSessions.length}',
                        style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRecitationModal(_selectedStudentForSessions!),
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: Text('تسجيل تسميع جديد', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

        // Timeline of Recitations
        Expanded(
          child: _isLoadingSessions
              ? const Center(child: CircularProgressIndicator())
              : _studentSessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('لا توجد جلسات تسميع مسجلة لهذا الطالب', style: AppTheme.cairoStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _studentSessions.length,
                      itemBuilder: (ctx, idx) {
                        final sess = _studentSessions[idx];
                        final surah = sess['surahName'] ?? '-';
                        final fromV = sess['fromVerse'] ?? 0;
                        final toV = sess['toVerse'] ?? 0;
                        final date = sess['sessionDate'] ?? '-';
                        final assessment = sess['assessment']?.toString() ?? '1';
                        final isDidNotRecite = surah == 'لم يُسمّع' || assessment == '6';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDidNotRecite ? Colors.red.shade100 : Colors.green.shade100,
                              child: Icon(
                                isDidNotRecite ? Icons.close : Icons.check,
                                color: isDidNotRecite ? Colors.red : Colors.green.shade800,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              isDidNotRecite ? 'لم يُسمّع اليوم' : 'سورة $surah (الآيات $fromV - $toV)',
                              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              'التاريخ: $date ${sess['notes'] != null ? "• ملاحظات: ${sess['notes']}" : ""}',
                              style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDidNotRecite ? Colors.red.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isDidNotRecite ? 'لم يُسمّع' : (assessment == '1' ? 'ممتاز' : (assessment == '2' ? 'جيد جداً' : 'مقبول')),
                                style: TextStyle(
                                  color: isDidNotRecite ? Colors.red.shade800 : Colors.blue.shade800,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: كشف المتابعة والتسميع الشامل (مع إكسل و PDF)
  // ==========================================
  Widget _buildComprehensiveRosterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Luxury Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D3B26), Color(0xFF1B6B48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'كشف متابعة وتسميع طلاب الحلقة الشامل',
                      style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Icon(Icons.table_view, color: AppTheme.accent, size: 24),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'كشف رقمي رسمي يوثق الحفظ اليومي، المراجعة والتثبيت، ونسب الحضور مع ميزات التصدير والطباعة.',
                  style: AppTheme.cairoStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                ),
                const SizedBox(height: 12),

                // Action Buttons for PDF & Excel
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: const Color(0xFF0D3B26),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _openPrintableRoster(downloadPdf: true),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('تحميل الكشف PDF 📥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D3B26),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _openPrintableRoster(downloadPdf: false),
                        icon: const Icon(Icons.grid_on, size: 16, color: Colors.green),
                        label: const Text('كشف إكسل / طباعة 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Circle Students Roster Overview
          Text('طلاب الحلقة المسجلون في الكشف (${_students.length}):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          ..._students.map((st) {
            final status = _attendanceStatus[st.id] ?? 1;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(st.fullName.isNotEmpty ? st.fullName[0] : 'ط', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(st.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: Text(
                  'الحفظ الحالي: ${st.completedAjzaa != null ? "${st.completedAjzaa} جزء" : "قيد المتابعة"} | الهوية: ${st.studentIdentityNumber ?? "-"}',
                  style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 1 ? Colors.green.shade50 : (status == 2 ? Colors.red.shade50 : Colors.orange.shade50),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: status == 1 ? Colors.green.shade300 : Colors.red.shade300),
                  ),
                  child: Text(
                    status == 1 ? 'حاضر اليوم' : (status == 2 ? 'غائب اليوم' : 'متأخر'),
                    style: TextStyle(
                      color: status == 1 ? Colors.green.shade800 : Colors.red.shade800,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: القرعة العشوائية الإلكترونية للتسميع
  // ==========================================
  Widget _buildLotteryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.casino, color: AppTheme.accent, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'إعدادات القرعة العشوائية للتسميع',
                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(
                      'استبعاد الطلاب الغائبين لتاريخ اليوم',
                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      'تضمن القرعة استبعاد أي طالب مرصود كـ "غائب" في جدول الحضور لضمان اختيار طالب متواجد فعلياً.',
                      style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    value: _excludeAbsentees,
                    activeColor: AppTheme.primary,
                    onChanged: (val) => setState(() => _excludeAbsentees = val),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isDrawingLottery ? null : _executeLottery,
                    icon: _isDrawingLottery
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, color: Colors.white),
                    label: Text(
                      _isDrawingLottery ? 'جاري سحب القرعة...' : 'سحب القرعة الآن 🎲',
                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Winner Display Box
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _lotteryWinner != null ? AppTheme.accent : Colors.grey.shade200,
                  width: _lotteryWinner != null ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _lotteryWinner == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.casino_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'اضغط على "سحب القرعة" لاختيار الطالب التالي للتسميع',
                          textAlign: TextAlign.center,
                          style: AppTheme.cairoStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                        ),
                        const SizedBox(height: 14),
                        Text('وقع الاختيار للتسميع اليوم على الطالب المبارك:', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
                        const SizedBox(height: 6),
                        Text(
                          _lotteryWinner!.fullName,
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 4),
                        Text('الحلقة: ${_selectedCircle?.name ?? "-"}', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: const Color(0xFF0D3B26),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showRecitationModal(_lotteryWinner!, viaLottery: true),
                          icon: const Icon(Icons.menu_book),
                          label: const Text('رصد التسميع له الآن 📖', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
