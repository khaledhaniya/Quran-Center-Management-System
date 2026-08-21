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

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
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
                const SizedBox(height: 14),

                TextField(
                  controller: surahController,
                  decoration: const InputDecoration(labelText: 'اسم السورة *'),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromVerseController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'من آية *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: toVerseController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'إلى آية *'),
                      ),
                    ),
                  ],
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
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => assessmentLevel = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات التحرير والتجويد (اختياري)'),
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
                final surah = surahController.text.trim();
                final fromV = int.tryParse(fromVerseController.text.trim()) ?? 1;
                final toV = int.tryParse(toVerseController.text.trim()) ?? 1;

                if (surah.isEmpty) return;

                final ok = await ApiService.saveRecitationSession(
                  studentId: student.id,
                  sessionDate: _formatDate(_selectedDate),
                  surahName: surah,
                  fromVerse: fromV,
                  toVerse: toV,
                  assessment: assessmentLevel,
                  notes: notesController.text.trim(),
                  viaLottery: viaLottery,
                );

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);

                if (ok) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تسجيل تسميع سورة $surah بنجاح للطالب ${student.fullName}!'), backgroundColor: Colors.green),
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
        ),
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

  void _showComprehensiveReportModal() async {
    final tId = widget.currentUser.teacherId ?? widget.currentUser.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Map<String, dynamic>>(
            future: ApiService.getTeacherComprehensiveReport(tId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(child: Text('تعذر تحميل الكشف الشامل', style: AppTheme.cairoStyle(color: Colors.red)));
              }

              final data = snapshot.data!;
              final students = (data['students'] as List? ?? []);

              return ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description, color: AppTheme.primary, size: 24),
                          const SizedBox(width: 8),
                          Text('الكشف الشامل لطلاب الحلقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('${students.length}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                            Text('إجمالي الطلاب', style: AppTheme.cairoStyle(fontSize: 11)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('${data['teacherName'] ?? widget.currentUser.fullName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('المعلم المشرف', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (students.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(child: Text('لا يوجد طلاب مسجلون بحلقتك حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted))),
                    )
                  else
                    ...students.map((st) {
                      final recitations = (st['recitationSessions'] as List? ?? []);
                      final completedSet = (st['completedAjzaa']?.toString() ?? '').split(',').where((x) => x.isNotEmpty).toList();
                      final plan = st['planType'] ?? 'المعتدلة';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(st['fullName'] ?? '', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('حضور: ${st['attendanceRatePercentage'] ?? 100}%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('الهاتف: ${st['familyContact'] ?? "-"} | الخطة: $plan | الأجزاء المكتملة: ${completedSet.length}', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const Divider(),
                              Text('آخر التسميعات:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (recitations.isEmpty)
                                Text('لا يوجد تسميعات مسجلة بعد.', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted))
                              else
                                ...recitations.take(3).map((r) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('سورة ${r['surahName']} (${r['fromVerse']}-${r['toVerse']})', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                          Text('${r['assessmentText'] ?? r['assessment']}', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.green.shade800)),
                                        ],
                                      ),
                                    )),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
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
