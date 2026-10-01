import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeacherSessionsScreen extends StatefulWidget {
  final User currentUser;
  const TeacherSessionsScreen({super.key, required this.currentUser});

  @override
  State<TeacherSessionsScreen> createState() => _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends State<TeacherSessionsScreen> {
  bool _isLoading = true;
  List<Circle> _circles = [];
  Circle? _selectedCircle;
  List<Student> _circleStudents = [];
  Student? _selectedStudent;

  bool _isLoadingSessions = false;
  List<Map<String, dynamic>> _studentSessions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialCircles();
  }

  Future<void> _loadInitialCircles() async {
    setState(() => _isLoading = true);
    try {
      final circles = await ApiService.getCircles();
      final activeCircles = circles.where((c) => c.isActive).toList();

      List<Circle> myCircles = activeCircles;
      if (widget.currentUser.role == 'Teacher') {
        myCircles = activeCircles.where((c) {
          final tName = c.teacherName.trim();
          final uName = widget.currentUser.fullName.trim();
          return tName.isNotEmpty && (tName == uName || tName.contains(uName) || uName.contains(tName));
        }).toList();
        if (myCircles.isEmpty) myCircles = activeCircles;
      }

      if (mounted) {
        setState(() {
          _circles = myCircles;
          if (myCircles.isNotEmpty) {
            _selectedCircle = myCircles.first;
          }
          _isLoading = false;
        });

        if (_selectedCircle != null) {
          await _loadCircleStudents();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCircleStudents() async {
    if (_selectedCircle == null) return;
    setState(() {
      _isLoading = true;
      _circleStudents = [];
      _selectedStudent = null;
      _studentSessions = [];
    });

    try {
      final circleDetails = await ApiService.getCircle(_selectedCircle!.id);
      final students = circleDetails?.students ?? [];
      if (mounted) {
        setState(() {
          _circleStudents = students;
          _isLoading = false;
          if (students.isNotEmpty) {
            _selectedStudent = students.first;
          }
        });
        if (_selectedStudent != null) {
          await _loadStudentSessions(_selectedStudent!.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentSessions(int studentId) async {
    setState(() => _isLoadingSessions = true);
    try {
      final sessions = await ApiService.getStudentSessions(studentId);
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

  void _showSessionForm({Map<String, dynamic>? existingSession}) {
    if (_selectedStudent == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SessionFormModal(
        student: _selectedStudent!,
        existingSession: existingSession,
        onSaved: () {
          _loadStudentSessions(_selectedStudent!.id);
        },
      ),
    );
  }

  Future<void> _deleteSession(int sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد الحذف', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من رغبتك في حذف جلسة التسميع هذه؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: AppTheme.cairoStyle())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiService.deleteRecitationSession(sessionId);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف جلسة التسميع بنجاح', style: AppTheme.cairoStyle())),
        );
        _loadStudentSessions(_selectedStudent!.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('سجل تسميع حفظ ومراجعة القرآن', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _circles.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Circle & Student Selection Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    children: [
                      // Circle Dropdown
                      DropdownButtonFormField<Circle>(
                        value: _selectedCircle,
                        decoration: InputDecoration(
                          labelText: 'الحلقة القرآنية:',
                          labelStyle: AppTheme.cairoStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _circles.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCircle = val);
                            _loadCircleStudents();
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Horizontal Student Pills
                      if (_circleStudents.isNotEmpty)
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _circleStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, idx) {
                              final s = _circleStudents[idx];
                              final isSelected = _selectedStudent?.id == s.id;
                              return ChoiceChip(
                                label: Text(s.fullName, style: AppTheme.cairoStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                backgroundColor: Colors.grey.shade100,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedStudent = s);
                                    _loadStudentSessions(s.id);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Selected Student Header & Add Session Button
                if (_selectedStudent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الطالب: ${_selectedStudent!.fullName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                            Text('الحلقة: ${_selectedCircle?.name ?? ""}', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('تسميع جديد', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _showSessionForm(),
                        ),
                      ],
                    ),
                  ),

                // Sessions List / Timeline
                Expanded(
                  child: _isLoadingSessions
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : _selectedStudent == null
                          ? Center(child: Text('يرجى اختيار طالب من القائمة أعلاه', style: AppTheme.cairoStyle(color: Colors.grey)))
                          : _studentSessions.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.hourglass_empty, size: 50, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      Text('لا يوجد جلسات تسميع مسجلة لهذا الطالب بعد', style: AppTheme.cairoStyle(color: Colors.grey.shade600)),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                                        icon: const Icon(Icons.add),
                                        label: Text('تسجيل أول تسميع الآن', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                                        onPressed: () => _showSessionForm(),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: _studentSessions.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (ctx, idx) {
                                    final s = _studentSessions[idx];
                                    final assessment = s['assessment'];
                                    final isDidNotRecite = assessment == 'DidNotRecite' || assessment == 6;

                                    // True mapping matching backend AssessmentText
                                    final assessText = _getAssessmentText(assessment, s['assessmentText']);
                                    final assessColor = _getAssessmentColor(assessment);

                                    final isRevision = s['recitationType'] == 2 ||
                                        s['recitationType'] == '2' ||
                                        s['recitationType'] == 'Revision' ||
                                        (s['recitationTypeText'] ?? '').toString().contains('مراجعة');

                                    final surah = s['surahName'] ?? '';
                                    final fromV = s['fromVerse'] ?? 0;
                                    final toV = s['toVerse'] ?? 0;
                                    final date = s['sessionDate'] ?? '';
                                    final notes = s['notes'] ?? '';
                                    final bool viaLottery = s['viaLottery'] == true;

                                    return Card(
                                      elevation: 1.5,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header row with Surah & Date
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isDidNotRecite ? Icons.cancel_outlined : Icons.menu_book,
                                                        color: isDidNotRecite ? Colors.red : AppTheme.primary,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          isDidNotRecite ? 'لم يُسمّع اليوم' : 'سورة $surah (الآيات $fromV - $toV)',
                                                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(date, style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Badges row
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (!isDidNotRecite)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isRevision ? Colors.orange.shade50 : Colors.green.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: isRevision ? Colors.orange.shade300 : Colors.green.shade300),
                                                    ),
                                                    child: Text(
                                                      isRevision ? 'مراجعة وتثبيت' : 'حفظ جديد',
                                                      style: AppTheme.cairoStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isRevision ? Colors.orange.shade900 : Colors.green.shade900),
                                                    ),
                                                  ),
                                                if (viaLottery)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.blue.shade300),
                                                    ),
                                                    child: Text('عبر القرعة', style: AppTheme.cairoStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                                  ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: assessColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: assessColor.withValues(alpha: 0.5)),
                                                  ),
                                                  child: Text(
                                                    assessText,
                                                    style: AppTheme.cairoStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: assessColor),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            if (notes.toString().trim().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text('ملاحظة الشيخ: $notes', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700)),
                                            ],

                                            const SizedBox(height: 8),
                                            // Action Buttons
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  icon: const Icon(Icons.edit, size: 14),
                                                  label: Text('تعديل', style: AppTheme.cairoStyle(fontSize: 11)),
                                                  onPressed: () => _showSessionForm(existingSession: s),
                                                ),
                                                TextButton.icon(
                                                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                                  label: Text('حذف', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.red)),
                                                  onPressed: () => _deleteSession(s['id']),
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
              ],
            ),
    );
  }

  String _getAssessmentText(dynamic level, dynamic providedText) {
    if (providedText != null && providedText.toString().trim().isNotEmpty) {
      return providedText.toString();
    }
    switch (level?.toString()) {
      case '1':
      case 'Excellent':
        return 'ممتاز';
      case '2':
      case 'VeryGood':
        return 'جيد جداً';
      case '3':
      case 'Good':
        return 'جيد';
      case '4':
      case 'Medium':
        return 'مقبول';
      case '5':
      case 'Rejected':
        return 'بحاجة لإعادة';
      case '6':
      case 'DidNotRecite':
        return 'لم يُسمّع';
      default:
        return 'مقبول';
    }
  }

  Color _getAssessmentColor(dynamic level) {
    switch (level?.toString()) {
      case '1':
      case 'Excellent':
        return Colors.green.shade800;
      case '2':
      case 'VeryGood':
        return Colors.teal.shade700;
      case '3':
      case 'Good':
        return Colors.blue.shade700;
      case '4':
      case 'Medium':
        return Colors.orange.shade800;
      case '5':
      case 'Rejected':
      case '6':
      case 'DidNotRecite':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade800;
    }
  }
}

// -------------------------------------------------------------
// Session Form Modal (Matching Web showSessionFormModal)
// -------------------------------------------------------------
class _SessionFormModal extends StatefulWidget {
  final Student student;
  final Map<String, dynamic>? existingSession;
  final VoidCallback onSaved;

  const _SessionFormModal({
    required this.student,
    this.existingSession,
    required this.onSaved,
  });

  @override
  State<_SessionFormModal> createState() => _SessionFormModalState();
}

class _SessionFormModalState extends State<_SessionFormModal> {
  final _formKey = GlobalKey<FormState>();
  int _recitationType = 1; // 1 = Memorization, 2 = Revision
  DateTime _sessionDate = DateTime.now();
  final _surahController = TextEditingController();
  final _fromVerseController = TextEditingController(text: '1');
  final _toVerseController = TextEditingController();
  final _notesController = TextEditingController();
  int _assessment = 1; // 1=Excellent, 2=VeryGood, 3=Good, 4=Medium, 5=Rejected, 6=DidNotRecite
  bool _viaLottery = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSession != null) {
      final s = widget.existingSession!;
      _recitationType = (s['recitationType'] == 2 || s['recitationType'] == '2' || s['recitationType'] == 'Revision') ? 2 : 1;
      if (s['sessionDate'] != null) {
        try {
          _sessionDate = DateTime.parse(s['sessionDate']);
        } catch (_) {}
      }
      _surahController.text = s['surahName'] ?? '';
      _fromVerseController.text = (s['fromVerse'] ?? 1).toString();
      _toVerseController.text = (s['toVerse'] ?? '').toString();
      _notesController.text = s['notes'] ?? '';
      _viaLottery = s['viaLottery'] == true;

      final a = s['assessment'];
      if (a == 'Excellent' || a == 1) _assessment = 1;
      else if (a == 'VeryGood' || a == 2) _assessment = 2;
      else if (a == 'Good' || a == 3) _assessment = 3;
      else if (a == 'Medium' || a == 4) _assessment = 4;
      else if (a == 'Rejected' || a == 5) _assessment = 5;
      else if (a == 'DidNotRecite' || a == 6) _assessment = 6;
    }
  }

  @override
  void dispose() {
    _surahController.dispose();
    _fromVerseController.dispose();
    _toVerseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final isDidNot = _assessment == 6;
    if (!isDidNot && !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_sessionDate);
      final fromV = isDidNot ? 0 : int.tryParse(_fromVerseController.text) ?? 1;
      final toV = isDidNot ? 0 : int.tryParse(_toVerseController.text) ?? 1;
      final surah = isDidNot ? 'لم يُسمّع' : _surahController.text.trim();

      bool success;
      if (widget.existingSession != null) {
        success = await ApiService.updateRecitationSession(
          id: widget.existingSession!['id'],
          sessionDate: dateStr,
          surahName: surah,
          fromVerse: fromV,
          toVerse: toV,
          assessment: _assessment,
          notes: _notesController.text.trim(),
          recitationType: _recitationType,
        );
      } else {
        success = await ApiService.saveRecitationSession(
          studentId: widget.student.id,
          sessionDate: dateStr,
          surahName: surah,
          fromVerse: fromV,
          toVerse: toV,
          assessment: _assessment,
          notes: _notesController.text.trim(),
          viaLottery: _viaLottery,
          recitationType: _recitationType,
        );
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ تم حفظ جلسة التسميع بنجاح!', style: AppTheme.cairoStyle()), backgroundColor: Colors.green.shade800),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حفظ الجلسة، تأكد من صحة البيانات', style: AppTheme.cairoStyle())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: AppTheme.cairoStyle())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDidNot = _assessment == 6;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingSession != null ? 'تعديل جلسة التسميع' : 'تسجيل جلسة تسميع جديدة',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Text('الطالب: ${widget.student.fullName}', style: AppTheme.cairoStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              const Divider(height: 20),

              // Recitation Type Switcher (حفظ جديد vs مراجعة وتثبيت)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _recitationType = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _recitationType == 1 ? Colors.green.shade50 : Colors.grey.shade100,
                          border: Border.all(color: _recitationType == 1 ? Colors.green : Colors.grey.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_add, size: 16, color: _recitationType == 1 ? Colors.green.shade800 : Colors.grey),
                            const SizedBox(width: 6),
                            Text('حفظ جديد', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _recitationType == 1 ? Colors.green.shade900 : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _recitationType = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _recitationType == 2 ? Colors.orange.shade50 : Colors.grey.shade100,
                          border: Border.all(color: _recitationType == 2 ? Colors.orange : Colors.grey.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.repeat, size: 16, color: _recitationType == 2 ? Colors.orange.shade800 : Colors.grey),
                            const SizedBox(width: 6),
                            Text('مراجعة وتثبيت', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _recitationType == 2 ? Colors.orange.shade900 : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _sessionDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 2)),
                  );
                  if (picked != null) setState(() => _sessionDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تاريخ التسميع: ${DateFormat('yyyy-MM-dd').format(_sessionDate)}', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Assessment dropdown
              DropdownButtonFormField<int>(
                value: _assessment,
                decoration: InputDecoration(
                  labelText: 'مستوى تقييم الحفظ والإتقان:',
                  labelStyle: AppTheme.cairoStyle(fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  DropdownMenuItem(value: 1, child: Text('ممتاز (Excellent)', style: AppTheme.cairoStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 2, child: Text('جيد جداً (Very Good)', style: AppTheme.cairoStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 3, child: Text('جيد (Good)', style: AppTheme.cairoStyle(color: Colors.blue.shade800))),
                  DropdownMenuItem(value: 4, child: Text('مقبول (Medium)', style: AppTheme.cairoStyle(color: Colors.orange.shade800))),
                  DropdownMenuItem(value: 5, child: Text('بحاجة لإعادة (Rejected)', style: AppTheme.cairoStyle(color: Colors.red.shade800))),
                  DropdownMenuItem(value: 6, child: Text('❌ لم يُسمّع (Did Not Recite)', style: AppTheme.cairoStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _assessment = val);
                },
              ),
              const SizedBox(height: 12),

              if (!isDidNot) ...[
                // Surah Name
                TextFormField(
                  controller: _surahController,
                  decoration: InputDecoration(
                    labelText: 'اسم السورة مسمَّعة:',
                    hintText: 'مثلاً: البقرة، يوسف، النبأ...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم السورة' : null,
                ),
                const SizedBox(height: 12),

                // From Verse & To Verse
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromVerseController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'من الآية:',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _toVerseController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'إلى الآية:',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظات وتوجيهات الشيخ:',
                  hintText: 'تنبيهات التجويد، الأخطاء، أو سبب عدم التسميع...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),

              // Via Lottery Checkbox
              CheckboxListTile(
                value: _viaLottery,
                title: Text('تسميع ناتج عن قرعة عشوائية', style: AppTheme.cairoStyle(fontSize: 12)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _viaLottery = val ?? false),
              ),
              const SizedBox(height: 14),

              // Submit Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ البيانات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: _isSaving ? null : _submitForm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
