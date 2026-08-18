import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ExamsScreen extends StatefulWidget {
  final User currentUser;

  const ExamsScreen({super.key, required this.currentUser});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<ExamNomination> _nominations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNominations();
  }

  void _loadNominations() async {
    try {
      final list = await ApiService.getNominations();
      if (mounted) {
        setState(() {
          _nominations = list;
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

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showNominateDialog() async {
    final isTeacher = widget.currentUser.role == 'Teacher';
    List<Student> allStudents = [];
    List<Student> quranStudents = [];
    List<Course> courses = [];

    try {
      allStudents = await ApiService.getStudents();
      courses = await ApiService.getCourses();

      if (isTeacher) {
        final teacherId = widget.currentUser.teacherId ?? widget.currentUser.id;
        final circles = await ApiService.getCircles();
        final teacherCircleIds = circles
            .where((c) => c.teacherId == teacherId)
            .map((c) => c.id)
            .toSet();

        quranStudents = allStudents.where((s) => s.circleId != null && teacherCircleIds.contains(s.circleId)).toList();
        courses = courses.where((c) => c.teacherId == teacherId).toList();
      } else {
        quranStudents = List.from(allStudents);
      }
    } catch (_) {}

    if (!mounted) return;

    String nominationType = 'Quran';
    String juzSelectionMode = 'Single'; // 'Single' or 'Range'
    Student? selectedStudent = (nominationType == 'Quran' ? quranStudents : allStudents).isNotEmpty 
        ? (nominationType == 'Quran' ? quranStudents : allStudents).first 
        : null;
    Course? selectedCourse = courses.isNotEmpty ? courses.first : null;
    int singleJuz = 1;
    int juzStart = 1;
    int juzEnd = 1;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final activeStudentsList = nominationType == 'Quran' ? quranStudents : allStudents;
          if (selectedStudent == null || !activeStudentsList.contains(selectedStudent)) {
            selectedStudent = activeStudentsList.isNotEmpty ? activeStudentsList.first : null;
          }

          return AlertDialog(
            title: Text('تقديم طلب ترشيح للاختبار', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: nominationType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوع الاختبار *'),
                    items: const [
                      DropdownMenuItem(value: 'Quran', child: Text('حفظ قرآن كريم (أجزاء)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'Course', child: Text('اختبار مساق / دورة شرعية', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          nominationType = val;
                          final newList = nominationType == 'Quran' ? quranStudents : allStudents;
                          selectedStudent = newList.isNotEmpty ? newList.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  if (activeStudentsList.isNotEmpty)
                    DropdownButtonFormField<Student>(
                      value: selectedStudent,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'اختر الطالب *'),
                      items: activeStudentsList.map((s) => DropdownMenuItem(value: s, child: Text(s.fullName, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                      onChanged: (val) => setModalState(() => selectedStudent = val),
                    )
                  else
                    Text(
                      nominationType == 'Quran' 
                          ? 'لا يوجد طلاب ينتمون لحلقتك القرآنية حالياً' 
                          : 'لا يوجد طلاب مسندون لك حالياً', 
                      style: AppTheme.cairoStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 12),

                if (nominationType == 'Course' && courses.isNotEmpty) ...[
                  DropdownButtonFormField<Course>(
                    value: selectedCourse,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'اختر المساق/الدورة *'),
                    items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                    onChanged: (val) => setModalState(() => selectedCourse = val),
                  ),
                ] else if (nominationType == 'Quran') ...[
                  DropdownButtonFormField<String>(
                    value: juzSelectionMode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'طريقة تحديد الأجزاء *'),
                    items: const [
                      DropdownMenuItem(value: 'Single', child: Text('جزء واحد فقط', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'Range', child: Text('نطاق أجزاء (من - إلى)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => juzSelectionMode = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  if (juzSelectionMode == 'Single')
                    DropdownButtonFormField<int>(
                      value: singleJuz,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'اختر الجزء *'),
                      items: List.generate(30, (i) => i + 1)
                          .map((j) => DropdownMenuItem(value: j, child: Text('الجزء $j', overflow: TextOverflow.ellipsis, maxLines: 1)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            singleJuz = val;
                            juzStart = val;
                            juzEnd = val;
                          });
                        }
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: juzStart,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'من الجزء'),
                            items: List.generate(30, (i) => i + 1)
                                .map((j) => DropdownMenuItem(value: j, child: Text('الجزء $j', overflow: TextOverflow.ellipsis, maxLines: 1)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  juzStart = val;
                                  if (juzEnd < juzStart) juzEnd = juzStart;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: juzEnd,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'إلى الجزء'),
                            items: List.generate(30, (i) => i + 1)
                                .map((j) => DropdownMenuItem(value: j, child: Text('الجزء $j', overflow: TextOverflow.ellipsis, maxLines: 1)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => juzEnd = val);
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStudent == null) return;
                if (nominationType == 'Course' && selectedCourse == null) return;

                final finalJuzStart = nominationType == 'Quran' ? (juzSelectionMode == 'Single' ? singleJuz : juzStart) : 1;
                final finalJuzEnd = nominationType == 'Quran' ? (juzSelectionMode == 'Single' ? singleJuz : juzEnd) : 1;

                try {
                  final ok = await ApiService.nominateExam(
                    studentId: selectedStudent!.id,
                    nominationType: nominationType,
                    courseId: nominationType == 'Course' ? selectedCourse?.id : null,
                    juzStart: finalJuzStart,
                    juzEnd: finalJuzEnd,
                  );

                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadNominations();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تقديم طلب الترشيح للاختبار بنجاح!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تقديم الترشيح'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showScheduleDialog(ExamNomination nomination) {
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('جدولة موعد الاختبار الشفوي', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الطالب: ${nomination.studentName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                title: Text('التاريخ والوقت:', style: AppTheme.cairoStyle(fontSize: 13)),
                subtitle: Text(
                  _formatDateTime(selectedDateTime),
                  style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                trailing: const Icon(Icons.edit_calendar, color: AppTheme.primary),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null) {
                    if (!context.mounted) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (pickedTime != null) {
                      setModalState(() {
                        selectedDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dateIsoStr = selectedDateTime.toIso8601String();
                  final ok = await ApiService.scheduleExam(nomination.id, dateIsoStr);

                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);

                  if (ok) {
                    _loadNominations();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم جدولة موعد الاختبار بنجاح!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تأكيد الجدولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEvaluateDialog(ExamNomination nomination) {
    final majorController = TextEditingController(text: '0');
    final minorController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    double currentGrade = 100.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          void calculateGrade() {
            int maj = int.tryParse(majorController.text) ?? 0;
            int min = int.tryParse(minorController.text) ?? 0;
            double g = max(0.0, 100.0 - (maj * 5.0 + min * 2.0));
            setModalState(() {
              currentGrade = g;
            });
          }

          return AlertDialog(
            title: Text('تقييم ورصد علامة الاختبار', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الطالب: ${nomination.studentName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  Text('التفاصيل: ${nomination.formattedDetails}', style: AppTheme.cairoStyle(fontSize: 13)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: majorController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'أخطاء جليّة (-5)'),
                          onChanged: (_) => calculateGrade(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minorController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'أخطاء خفيّة (-2)'),
                          onChanged: (_) => calculateGrade(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentGrade >= 60 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: currentGrade >= 60 ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('النتيجة النهائية المحسوبة:', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${currentGrade.toStringAsFixed(1)}%',
                          style: AppTheme.cairoStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: currentGrade >= 60 ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات وتوجيهات لجنة الاختبار (اختياري)'),
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
                  try {
                    int maj = int.tryParse(majorController.text) ?? 0;
                    int min = int.tryParse(minorController.text) ?? 0;

                    final res = await ApiService.evaluateExam(
                      nominationId: nomination.id,
                      majorMistakes: maj,
                      minorMistakes: min,
                      grade: currentGrade,
                      notes: notesController.text,
                      code2FA: '123456',
                    );

                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);

                    if (res.isNotEmpty) {
                      _loadNominations();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم اعتماد العلامة بنجاح! النتيجة: $currentGrade%'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('اعتماد النتيجة والشهادة'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _selectedFilter = 'All';

  Widget _buildHeroStat(String label, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(count, style: AppTheme.cairoStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.cairoStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.currentUser.role;
    final canNominate = role == 'Teacher' || role == 'Admin' || role == 'Developer';
    final isSupervisor = role == 'ExamSupervisor' || role == 'Admin' || role == 'Developer';

    final pendingCount = _nominations.where((n) => n.status == 'Pending').length;
    final scheduledCount = _nominations.where((n) => n.status == 'Scheduled').length;
    final completedCount = _nominations.where((n) => n.status == 'Completed').length;
    final failedCount = _nominations.where((n) => n.status == 'Failed').length;

    List<ExamNomination> filteredList = _nominations;
    if (_selectedFilter == 'Quran') {
      filteredList = _nominations.where((n) => n.nominationType == 'Quran').toList();
    } else if (_selectedFilter == 'Course') {
      filteredList = _nominations.where((n) => n.nominationType == 'Course').toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الاختبارات والترشيحات'),
      ),
      floatingActionButton: canNominate
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              onPressed: _showNominateDialog,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: Text('ترشيح طالب', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ═══════ Supervisor Hero Card ═══════
                if (isSupervisor)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A2E23), Color(0xFF0D5C3A), Color(0xFF157347)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCDA250), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF0D5C3A).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.verified_user, color: Colors.amber, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('مركز الاعتماد والرقابة الشفوية', style: AppTheme.cairoStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text('لوحة قيادة مشرف الاختبارات', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildHeroStat('بانتظار\nالجدولة', '$pendingCount', Icons.hourglass_top, Colors.amber),
                            const SizedBox(width: 6),
                            _buildHeroStat('مجدولة\nوجاهزة', '$scheduledCount', Icons.calendar_month, Colors.lightBlueAccent),
                            const SizedBox(width: 6),
                            _buildHeroStat('اجتازوا\nومعتمدة', '$completedCount', Icons.check_circle, Colors.greenAccent),
                            const SizedBox(width: 6),
                            _buildHeroStat('لم\nيجتازوا', '$failedCount', Icons.cancel, Colors.redAccent),
                          ],
                        ),
                      ],
                    ),
                  ),

                // ═══════ Filter Chips ═══════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('الكل', style: AppTheme.cairoStyle(fontSize: 12, color: _selectedFilter == 'All' ? Colors.white : Colors.black87)),
                          selected: _selectedFilter == 'All',
                          selectedColor: AppTheme.primary,
                          onSelected: (_) => setState(() => _selectedFilter = 'All'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('القرآن', style: AppTheme.cairoStyle(fontSize: 12, color: _selectedFilter == 'Quran' ? Colors.white : Colors.black87)),
                          selected: _selectedFilter == 'Quran',
                          selectedColor: const Color(0xFF0D5C3A),
                          onSelected: (_) => setState(() => _selectedFilter = 'Quran'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('الدورات', style: AppTheme.cairoStyle(fontSize: 12, color: _selectedFilter == 'Course' ? Colors.white : Colors.black87)),
                          selected: _selectedFilter == 'Course',
                          selectedColor: Colors.indigo,
                          onSelected: (_) => setState(() => _selectedFilter = 'Course'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════ List ═══════
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_outlined, size: 50, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('لا يوجد طلبات ترشيح في هذا التصنيف', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 88),
                          itemCount: filteredList.length,
                          itemBuilder: (ctx, index) {
                            final item = filteredList[index];

                            Color statusColor = Colors.orange;
                            String statusText = 'بانتظار المشرف';
                            IconData statusIcon = Icons.hourglass_top;

                            if (item.status == 'Scheduled') {
                              statusColor = Colors.blue;
                              statusText = 'مجدول للاختبار';
                              statusIcon = Icons.calendar_month;
                            } else if (item.status == 'Completed') {
                              statusColor = Colors.green;
                              statusText = 'مكتمل واجتاز';
                              statusIcon = Icons.check_circle;
                            } else if (item.status == 'Failed') {
                              statusColor = Colors.red;
                              statusText = 'مكتمل ولم يجتز';
                              statusIcon = Icons.cancel;
                            }

                            final isPending = item.status == 'Pending';
                            final isScheduled = item.status == 'Scheduled';

                            final isQuran = item.nominationType == 'Quran';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row: Name + Status
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.studentName,
                                                style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isQuran ? const Color(0xFF0D5C3A).withValues(alpha: 0.12) : Colors.indigo.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      isQuran ? '📖 قرآن كريم' : '🎓 دورة',
                                                      style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isQuran ? const Color(0xFF0D5C3A) : Colors.indigo),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(statusIcon, size: 12, color: statusColor),
                                              const SizedBox(width: 4),
                                              Text(statusText, style: AppTheme.cairoStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),

                                    // Details
                                    Text(
                                      'تفاصيل: ${item.formattedDetails}',
                                      style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'الحلقة: ${item.halaqahName} | المعلم: ${item.teacherName}',
                                      style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                    if (item.examDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.event, size: 14, color: Colors.blue.shade800),
                                            const SizedBox(width: 4),
                                            Text(
                                              'الموعد: ${item.examDate}',
                                              style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                            ),
                                          ],
                                        ),
                                      ),

                                    if (item.result != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: item.status == 'Completed' ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: item.status == 'Completed' ? Colors.green.shade200 : Colors.red.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(item.status == 'Completed' ? Icons.emoji_events : Icons.warning_amber, size: 16, color: item.status == 'Completed' ? Colors.green.shade800 : Colors.red.shade800),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'النتيجة: ${item.result!.grade}% (جلي: ${item.result!.majorMistakes}، خفي: ${item.result!.minorMistakes})',
                                                style: AppTheme.cairoStyle(fontSize: 11, color: item.status == 'Completed' ? Colors.green.shade900 : Colors.red.shade900, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // ═══ Action Buttons: ONLY for Supervisor/Admin/Developer ═══
                                    if (isSupervisor && (isPending || isScheduled)) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (isPending)
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue.shade700,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _showScheduleDialog(item),
                                              icon: const Icon(Icons.calendar_month, size: 14),
                                              label: Text('جدولة موعد', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                            ),
                                          if (isScheduled)
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.statusPresent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _showEvaluateDialog(item),
                                              icon: const Icon(Icons.edit_note, size: 14),
                                              label: Text('تقييم واختبار', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

