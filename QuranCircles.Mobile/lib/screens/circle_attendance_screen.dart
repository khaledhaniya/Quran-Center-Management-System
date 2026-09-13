import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CircleAttendanceScreen extends StatefulWidget {
  final User currentUser;

  const CircleAttendanceScreen({super.key, required this.currentUser});

  @override
  State<CircleAttendanceScreen> createState() => _CircleAttendanceScreenState();
}

class _CircleAttendanceScreenState extends State<CircleAttendanceScreen> {
  List<Circle> _circles = [];
  Circle? _selectedCircle;
  List<Student> _students = [];
  final Map<int, int> _attendanceStatus = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    try {
      var circlesList = await ApiService.getCircles();
      final isTeacher = widget.currentUser.role == 'Teacher';
      if (isTeacher && widget.currentUser.teacherId != null) {
        circlesList = circlesList.where((c) => c.teacherId == widget.currentUser.teacherId).toList();
      }

      final studentsList = await ApiService.getStudents();

      if (mounted) {
        setState(() {
          _circles = circlesList;
          if (circlesList.isNotEmpty) {
            _selectedCircle = circlesList.first;
            _filterStudents(studentsList);
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
        _attendanceStatus[s.id] = 1;
      }
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _saveAttendance() async {
    if (_selectedCircle == null || _students.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

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
          const SnackBar(content: Text('تم حفظ حضور وغياب الحلقة بنجاح!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
                            style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        if (viaLottery)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('عن طريق القرعة 🎲', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // مسار التسميع (حفظ جديد / مراجعة وتثبيت)
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
                      DropdownMenuItem(value: 1, child: Text('ممتاز (1)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 2, child: Text('جيد جداً (2)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 3, child: Text('جيد (3)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 4, child: Text('متوسط (4)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 5, child: Text('مرفوض/ضعيف (5)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 6, child: Text('❌ لم يُسمّع (6)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          assessmentLevel = val;
                          if (val == 6) {
                            surahController.text = 'لم يُسمّع';
                            fromVerseController.text = '0';
                            toVerseController.text = '0';
                          } else if (surahController.text == 'لم يُسمّع') {
                            surahController.text = 'البقرة';
                            fromVerseController.text = '1';
                            toVerseController.text = '10';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات التحرير والتجويد أو عدم التسميع'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () async {
                  final isDidNot = assessmentLevel == 6;
                  final surah = isDidNot
                      ? (surahController.text.trim().isEmpty ? 'لم يُسمّع' : surahController.text.trim())
                      : surahController.text.trim();
                  final fromV = isDidNot ? 0 : (int.tryParse(fromVerseController.text.trim()) ?? 1);
                  final toV = isDidNot ? 0 : (int.tryParse(toVerseController.text.trim()) ?? 1);

                  if (!isDidNot && surah.isEmpty) return;

                  final ok = await ApiService.saveRecitationSession(
                    studentId: student.id,
                    sessionDate: _formatDate(_selectedDate),
                    surahName: surah,
                    fromVerse: fromV,
                    toVerse: toV,
                    assessment: assessmentLevel,
                    notes: notesController.text.trim(),
                    viaLottery: viaLottery,
                    recitationType: recitationType,
                  );

                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);

                  if (ok) {
                    if (!mounted) return;
                    final msg = isDidNot 
                        ? 'تم تسجيل حالة (لم يُسمّع) للطالب ${student.fullName}'
                        : 'تم تسجيل تسميع سورة $surah بنجاح للطالب ${student.fullName}!';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: isDidNot ? Colors.orange[800] : Colors.green),
                    );
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فشل حفظ جلسة التسميع'), backgroundColor: Colors.red),
                    );
                  }
                },
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label: const Text('حفظ التسميع'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _spinRandomLottery() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب في هذه الحلقة للقرعة')),
      );
      return;
    }

    final random = Random();
    final winnerIndex = random.nextInt(_students.length);
    final winner = _students[winnerIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.casino, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text('نتيجة قرعة التسميع!', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('وقع الاختيار اليوم للتسميع على الطالب:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                winner.fullName,
                style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              Navigator.pop(ctx);
              _showRecitationModal(winner, viaLottery: true);
            },
            icon: const Icon(Icons.menu_book, color: Colors.white),
            label: const Text('رصد التسميع له الآن 📖'),
          ),
        ],
      ),
    );
  }

  void _showComprehensiveReportModal() {
    final tId = widget.currentUser.teacherId ?? widget.currentUser.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeacherComprehensiveReportModal(teacherId: tId, teacherName: widget.currentUser.fullName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحضير الحلقة وقرعة التسميع'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _circles.isEmpty
              ? Center(child: Text('لا يوجد حلقة مسندة لك حالياً', style: AppTheme.cairoStyle()))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.surfaceCard,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<Circle>(
                                  value: _selectedCircle,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'اختر الحلقة'),
                                  items: _circles.map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1));
                                  }).toList(),
                                  onChanged: (val) async {
                                    if (val != null) {
                                      _selectedCircle = val;
                                      final allStudents = await ApiService.getStudents();
                                      _filterStudents(allStudents);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_formatDate(_selectedDate)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    minimumSize: const Size.fromHeight(42),
                                  ),
                                  onPressed: _spinRandomLottery,
                                  icon: const Icon(Icons.casino, color: Colors.white),
                                  label: const Text('إجراء قرعة تسميع عشوائية 🎲'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    minimumSize: const Size.fromHeight(42),
                                  ),
                                  onPressed: _showComprehensiveReportModal,
                                  icon: const Icon(Icons.description, color: Colors.white),
                                  label: const Text('الكشف الشامل 📋'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _students.isEmpty
                          ? Center(child: Text('لا يوجد طلاب ينتمون لهذه الحلقة حالياً', style: AppTheme.cairoStyle()))
                          : ListView.builder(
                              padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 88),
                              itemCount: _students.length,
                              itemBuilder: (ctx, index) {
                                final s = _students[index];
                                final currentStatus = _attendanceStatus[s.id] ?? 1;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(s.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  Text('الهاتف: ${s.familyContact ?? "غير مسجل"}', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted)),
                                                ],
                                              ),
                                            ),
                                            ToggleButtons(
                                              constraints: const BoxConstraints(minWidth: 42, minHeight: 32),
                                              borderRadius: BorderRadius.circular(8),
                                              selectedColor: Colors.white,
                                              fillColor: currentStatus == 1 ? Colors.green : (currentStatus == 2 ? Colors.red : Colors.orange),
                                              isSelected: [
                                                currentStatus == 1,
                                                currentStatus == 2,
                                                currentStatus == 3,
                                              ],
                                              onPressed: (btnIndex) {
                                                setState(() {
                                                  _attendanceStatus[s.id] = btnIndex + 1;
                                                });
                                              },
                                              children: const [
                                                Text('حاضر', style: TextStyle(fontSize: 11)),
                                                Text('غائب', style: TextStyle(fontSize: 11)),
                                                Text('متأخر', style: TextStyle(fontSize: 11)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _showRecitationModal(s),
                                              icon: const Icon(Icons.menu_book, size: 16, color: AppTheme.primary),
                                              label: Text('تسجيل تسميع اليوم 📖', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppTheme.primary,
                        ),
                        onPressed: _isSaving ? null : _saveAttendance,
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle, color: Colors.white),
                        label: Text('حفظ كشف الحضور والتسميع اليومي', style: AppTheme.cairoStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _TeacherComprehensiveReportModal extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const _TeacherComprehensiveReportModal({
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<_TeacherComprehensiveReportModal> createState() => _TeacherComprehensiveReportModalState();
}

class _TeacherComprehensiveReportModalState extends State<_TeacherComprehensiveReportModal> {
  String _selectedPeriod = 'all';
  String? _fromDate;
  String? _toDate;
  String _search = '';
  late Future<Map<String, dynamic>> _futureReport;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    _futureReport = ApiService.getTeacherComprehensiveReport(
      widget.teacherId,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;

      if (period == 'all') {
        _fromDate = null;
        _toDate = null;
      } else if (period == 'current_month') {
        final f = DateTime(year, month, 1);
        final t = DateTime(year, month + 1, 0);
        _fromDate = "${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}";
        _toDate = "${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}";
      } else if (period == 'last_month') {
        final f = DateTime(year, month - 1, 1);
        final t = DateTime(year, month, 0);
        _fromDate = "${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}";
        _toDate = "${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}";
      } else if (period == 'month_8') {
        _fromDate = "$year-08-01";
        _toDate = "$year-08-31";
      } else if (period == 'month_9') {
        _fromDate = "$year-09-01";
        _toDate = "$year-09-30";
      }
      _loadReport();
    });
  }

  String _getArabicDayName(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
        return days[dt.weekday - 1];
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Modal Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'كشف متابعة وتسميع طلاب الحلقة الشامل',
                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 12),

            // Period Selection Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('all', 'كامل الفترة'),
                  _buildPeriodChip('current_month', 'الشهر الحالي'),
                  _buildPeriodChip('last_month', 'الشهر السابق'),
                  _buildPeriodChip('month_8', 'شهر 8 (أغسطس)'),
                  _buildPeriodChip('month_9', 'شهر 9 (سبتمبر)'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'بحث سريع باسم الطالب أو الهوية...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              style: AppTheme.cairoStyle(fontSize: 12),
              onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),

            // Main Content Future
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _futureReport,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text('تعذر تحميل الكشف الشامل', style: AppTheme.cairoStyle(color: Colors.red)),
                    );
                  }

                  final data = snapshot.data!;
                  final studentsRaw = (data['students'] as List? ?? []);

                  // Filter students by search
                  final students = studentsRaw.where((st) {
                    if (_search.isEmpty) return true;
                    final name = (st['fullName'] ?? '').toString().toLowerCase();
                    final idNum = (st['studentIdentityNumber'] ?? '').toString();
                    final phone = (st['studentMobile'] ?? st['familyContact'] ?? '').toString();
                    return name.contains(_search) || idNum.contains(_search) || phone.contains(_search);
                  }).toList();

                  // Compute dates
                  final dateSet = <String>{};
                  for (final st in studentsRaw) {
                    for (final rs in (st['recitationSessions'] as List? ?? [])) {
                      final d = rs['sessionDate'] ?? rs['date'];
                      if (d != null) dateSet.add(d.toString());
                    }
                    for (final a in (st['attendanceRecords'] as List? ?? [])) {
                      final d = a['sessionDate'] ?? a['date'];
                      if (d != null) dateSet.add(d.toString());
                    }
                  }
                  final sortedDates = dateSet.toList()..sort();

                  return ListView(
                    controller: scrollController,
                    children: [
                      // KPI Banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildKpiItem('${studentsRaw.length}', 'طلاب الحلقة', AppTheme.primary),
                            _buildKpiItem('${sortedDates.length}', 'أيام التسميع', Colors.orange.shade800),
                            _buildKpiItem('${data['teacherName'] ?? widget.teacherName}', 'المعلم', Colors.black87),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (students.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: Center(
                            child: Text('لا توجد بيانات مطابقة للبحث أو النطاق.', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                          ),
                        )
                      else
                        ...students.map((st) => _buildStudentComprehensiveCard(st, sortedDates)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String periodKey, String label) {
    final isSelected = _selectedPeriod == periodKey;
    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: ChoiceChip(
        label: Text(label, style: AppTheme.cairoStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        backgroundColor: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onSelected: (_) => _onPeriodChanged(periodKey),
      ),
    );
  }

  Widget _buildKpiItem(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildStudentComprehensiveCard(Map<String, dynamic> st, List<String> circleDates) {
    final recitations = (st['recitationSessions'] as List? ?? []);
    final attendances = (st['attendanceRecords'] as List? ?? []);
    final idNumber = st['studentIdentityNumber']?.toString() ?? '-';
    final mobile = st['studentMobile']?.toString() ?? st['familyContact']?.toString() ?? '-';
    final dob = st['dateOfBirth']?.toString() ?? '-';
    final plan = st['planType']?.toString() ?? 'المعتدلة';
    final attPct = st['attendanceRatePercentage'] ?? 100;

    // Group recitations and attendances by date
    final recByDate = <String, List<dynamic>>{};
    for (final r in recitations) {
      final d = (r['sessionDate'] ?? r['date'])?.toString();
      if (d != null) {
        recByDate.putIfAbsent(d, () => []).add(r);
      }
    }

    final attByDate = <String, dynamic>{};
    for (final a in attendances) {
      final d = (a['sessionDate'] ?? a['date'])?.toString();
      if (d != null) {
        attByDate[d] = a;
      }
    }

    // Days to show: circleDates that fall in this range
    final displayDates = circleDates.where((d) => recByDate.containsKey(d) || attByDate.containsKey(d)).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    st['fullName'] ?? '',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'حضور $attPct%',
                    style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Student Info Badges
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildInfoTag('الهوية: $idNumber'),
                _buildInfoTag('الجوال: $mobile'),
                _buildInfoTag('الميلاد: $dob'),
                _buildInfoTag('الخطة: $plan'),
              ],
            ),
            const Divider(height: 16),

            // Daily Recitation Breakdown
            Text(
              'سجل التسميع والمراجعة اليومي (الحفظ الجديد والمراجعة):',
              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
            ),
            const SizedBox(height: 6),

            if (displayDates.isEmpty)
              Text('لا يوجد تسميعات أو حضور موثق في هذه الفترة.', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted))
            else
              ...displayDates.map((dStr) {
                final dayName = _getArabicDayName(dStr);
                final att = attByDate[dStr];
                final dayRecs = recByDate[dStr] ?? [];

                final isAbsent = att != null && (att['status'] == 2 || att['statusText'] == 'غائب');

                // Memorization
                dynamic memSess;
                try {
                  memSess = dayRecs.firstWhere((r) => r['recitationType'] == 0 || r['recitationTypeText'] == 'حفظ جديد' || (r['surahName'] != null && r['recitationType'] != 1));
                } catch (_) {
                  memSess = null;
                }

                // Revision
                dynamic revSess;
                try {
                  revSess = dayRecs.firstWhere((r) => r['recitationType'] == 1 || r['recitationTypeText'] == 'مراجعة وتثبيت');
                } catch (_) {
                  revSess = null;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$dayName $dStr', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                          if (isAbsent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                              child: Text('غائب', style: AppTheme.cairoStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Dual Bands: Memorization & Revision
                      if (isAbsent)
                        Text('لم يحضر الحلقة في هذا اليوم (غياب)', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.red.shade700))
                      else
                        Row(
                          children: [
                            // Memorization block
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: memSess != null ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: memSess != null ? Colors.green.shade200 : Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الحفظ الجديد:', style: AppTheme.cairoStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                                    Text(
                                      memSess != null ? 'سورة ${memSess['surahName']} (${memSess['fromVerse']}-${memSess['toVerse']})' : 'لم يحفظ',
                                      style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: memSess != null ? Colors.green.shade900 : Colors.red.shade800),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Revision block
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: revSess != null ? Colors.blue.shade50 : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: revSess != null ? Colors.blue.shade200 : Colors.amber.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('المراجعة:', style: AppTheme.cairoStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                                    Text(
                                      revSess != null ? 'سورة ${revSess['surahName']} (${revSess['fromVerse']}-${revSess['toVerse']})' : 'لم يراجع',
                                      style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: revSess != null ? Colors.blue.shade900 : Colors.amber.shade900),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(String text) {
    return Text(
      text,
      style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted),
    );
  }
}
