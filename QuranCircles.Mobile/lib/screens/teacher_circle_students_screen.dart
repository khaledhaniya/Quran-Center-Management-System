import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'student_360_screen.dart';

class TeacherCircleStudentsScreen extends StatefulWidget {
  final User currentUser;
  const TeacherCircleStudentsScreen({super.key, required this.currentUser});

  @override
  State<TeacherCircleStudentsScreen> createState() => _TeacherCircleStudentsScreenState();
}

class _TeacherCircleStudentsScreenState extends State<TeacherCircleStudentsScreen> {
  bool _isLoading = true;
  List<Circle> _circles = [];
  Circle? _selectedCircle;
  List<Student> _students = [];

  // Permissions from system settings
  bool _allowTeacherEnroll = true;
  bool _allowTeacherEditPlan = true;
  bool _hideParentPhone = false;
  int _maxStudentsPerCircle = 25;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
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

      // Check system settings
      try {
        final settings = await ApiService.getSystemSettings();
        if (settings != null) {
          if (settings.containsKey('allowTeacherSelfEnrollment')) {
            _allowTeacherEnroll = settings['allowTeacherSelfEnrollment'] == true;
          }
          if (settings.containsKey('allowTeacherEditStudentPlan')) {
            _allowTeacherEditPlan = settings['allowTeacherEditStudentPlan'] == true;
          }
          if (settings.containsKey('hideParentPhoneFromTeacher')) {
            _hideParentPhone = settings['hideParentPhoneFromTeacher'] == true;
          }
          if (settings.containsKey('maxStudentsPerCircle')) {
            _maxStudentsPerCircle = settings['maxStudentsPerCircle'] ?? 25;
          }
        }
      } catch (_) {}

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
    setState(() => _isLoading = true);

    try {
      final circleDetails = await ApiService.getCircle(_selectedCircle!.id);
      final list = circleDetails?.students ?? [];
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unenrollStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد إلغاء التنسيب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من إلغاء تنسيب الطالب "${student.fullName}" من حلقة "${_selectedCircle?.name}"؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: AppTheme.cairoStyle())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تأكيد الإلغاء', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && _selectedCircle != null) {
      try {
        final ok = await ApiService.unenrollStudentFromCircle(_selectedCircle!.id, student.id);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إلغاء تنسيب الطالب من الحلقة بنجاح', style: AppTheme.cairoStyle()), backgroundColor: Colors.green.shade800),
          );
          _loadCircleStudents();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e', style: AppTheme.cairoStyle())));
        }
      }
    }
  }

  void _showTeacherEnrollModal() {
    if (!_allowTeacherEnroll) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تنسيب الطلاب بواسطة المعلم معطل حالياً من قبل الإدارة', style: AppTheme.cairoStyle())),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _EnrollStudentModalDialog(
        currentCircle: _selectedCircle!,
        myCircles: _circles,
        maxCapacity: _maxStudentsPerCircle,
        onEnrolled: () => _loadCircleStudents(),
      ),
    );
  }

  void _showAddNewStudentModal() {
    if (!_allowTeacherEnroll) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تسجيل الطلاب الجدد بواسطة المعلم معطل حالياً من لوحة التحكم', style: AppTheme.cairoStyle())),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AddNewStudentModalDialog(
        circle: _selectedCircle!,
        onAdded: () => _loadCircleStudents(),
      ),
    );
  }

  void _showEditPlanModal(Student student) {
    final controller = TextEditingController(text: student.previousQuranMemorization);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل خطة الحفظ للطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: ${student.fullName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'خطة / مستوى الحفظ الحالي:',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: AppTheme.cairoStyle())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.updateStudent(student.id, {'previousQuranMemorization': controller.text.trim()});
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تحديث خطة الحفظ بنجاح', style: AppTheme.cairoStyle()), backgroundColor: Colors.green.shade800),
                );
                _loadCircleStudents();
              }
            },
            child: Text('حفظ', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFull = _students.length >= _maxStudentsPerCircle;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('إدارة وتنسيب طلاب حلقاتي', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _circles.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadCircleStudents,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dashboard Header Card (Matching Web)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text('المنظومة القرآنية', style: AppTheme.cairoStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إدارة وتنسيب طلاب حلقاتي القرآنيّة',
                            style: AppTheme.cairoStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'استعراض طلاب حلقاتك، تنسيب طلاب جدد، وتحديث خطط الحفظ ومتابعة المستويات.',
                            style: AppTheme.cairoStyle(color: Colors.white70, fontSize: 11),
                          ),
                          const SizedBox(height: 14),

                          // Action Buttons (Only visible if allowed in CMS Settings!)
                          if (_allowTeacherEnroll)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.primary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                                    label: Text('تنسيب طالب موجود', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: _showTeacherEnrollModal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentLight,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text('تسجيل طالب جديد', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: _showAddNewStudentModal,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Circle Selector & Capacity Indicator (Matching Web)
                    Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<Circle>(
                                value: _selectedCircle,
                                decoration: InputDecoration(
                                  labelText: 'اختر الحلقة القرآنية:',
                                  labelStyle: AppTheme.cairoStyle(fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: _circles.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCircle = val);
                                    _loadCircleStudents();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isFull ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isFull ? Colors.red.shade300 : Colors.green.shade300),
                                ),
                                child: Text(
                                  'السعة: ${_students.length} / $_maxStudentsPerCircle${isFull ? " (ممتلئة)" : ""}',
                                  style: AppTheme.cairoStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isFull ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Students List in Teacher's Circle (Shows ONLY this circle's students!)
                    if (_students.isEmpty)
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text('لا يوجد طلاب منتسبين في هذه الحلقة حالياً', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              if (_allowTeacherEnroll) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.person_add),
                                  label: Text('تنسيب طالب موجود الآن', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                                  onPressed: _showTeacherEnrollModal,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final s = _students[idx];

                          String displayPhone = s.familyContact.isNotEmpty ? s.familyContact : (s.studentMobile.isNotEmpty ? s.studentMobile : '-');
                          if (_hideParentPhone && displayPhone != '-') {
                            displayPhone = displayPhone.length > 5 ? '${displayPhone.substring(0, 4)}****${displayPhone.substring(displayPhone.length - 2)}' : '****';
                          }

                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                        child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            if (s.parentName.isNotEmpty)
                                              Text('ولي الأمر: ${s.parentName}', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                                        child: Text(s.previousQuranMemorization.isNotEmpty ? s.previousQuranMemorization : 'مبتدئ', style: AppTheme.cairoStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Details Row
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.badge_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('الهوية: ${s.studentIdentityNumber.isNotEmpty ? s.studentIdentityNumber : s.id}', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(displayPhone, style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700)),
                                        ],
                                      ),
                                      if (s.address.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(s.address, style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700)),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.id_card, size: 14),
                                        label: Text('بطاقة الطالب', style: AppTheme.cairoStyle(fontSize: 11)),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const Student360Screen()));
                                        },
                                      ),
                                      if (_allowTeacherEditPlan) ...[
                                        const SizedBox(width: 6),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.edit_note, size: 14, color: Colors.orange),
                                          label: Text('الخطة', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.orange.shade900)),
                                          onPressed: () => _showEditPlanModal(s),
                                        ),
                                      ],
                                      if (_allowTeacherEnroll) ...[
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.person_remove_outlined, size: 18, color: Colors.red),
                                          tooltip: 'إلغاء التنسيب من الحلقة',
                                          onPressed: () => _unenrollStudent(s),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// -------------------------------------------------------------
// Enrollment Modal Dialog (Matching Web showTeacherEnrollExistingModal)
// -------------------------------------------------------------
class _EnrollStudentModalDialog extends StatefulWidget {
  final Circle currentCircle;
  final List<Circle> myCircles;
  final int maxCapacity;
  final VoidCallback onEnrolled;

  const _EnrollStudentModalDialog({
    required this.currentCircle,
    required this.myCircles,
    required this.maxCapacity,
    required this.onEnrolled,
  });

  @override
  State<_EnrollStudentModalDialog> createState() => _EnrollStudentModalDialogState();
}

class _EnrollStudentModalDialogState extends State<_EnrollStudentModalDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCandidates = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'unassigned', 'assigned'
  late Circle _targetCircle;

  @override
  void initState() {
    super.initState();
    _targetCircle = widget.currentCircle;
    _fetchCandidates();
  }

  Future<void> _fetchCandidates() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getStudentsForEnrollment();
      if (mounted) {
        setState(() {
          _allCandidates = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeEnroll(int studentId, String studentName) async {
    try {
      final success = await ApiService.enrollStudentInCircle(_targetCircle.id, studentId);
      if (success && mounted) {
        Navigator.pop(context);
        widget.onEnrolled();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم تنسيب الطالب $studentName لحلقة ${_targetCircle.name} بنجاح!', style: AppTheme.cairoStyle()), backgroundColor: Colors.green.shade800),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التنسيب: $e', style: AppTheme.cairoStyle())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allCandidates.where((s) {
      final name = (s['fullName'] ?? '').toString().toLowerCase();
      final idNum = (s['studentIdentityNumber'] ?? s['id'] ?? '').toString();
      final phone = (s['familyContact'] ?? s['studentMobile'] ?? '').toString();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || idNum.contains(q) || phone.contains(q);

      final hasCircle = s['circleId'] != null && s['circleId'] > 0 && s['circleName'] != null && s['circleName'] != 'غير مسند حلقة';
      if (_filterStatus == 'unassigned') return matchesSearch && !hasCircle;
      if (_filterStatus == 'assigned') return matchesSearch && hasCircle;
      return matchesSearch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('تنسيب طالب إلى حلقتي القرآنيّة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),

            if (widget.myCircles.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<Circle>(
                  value: _targetCircle,
                  decoration: InputDecoration(
                    labelText: 'الحلقة المستهدفة للتنسيب:',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: widget.myCircles.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: AppTheme.cairoStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _targetCircle = val);
                  },
                ),
              ),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'ابحث في كافة طلاب المركز بالاسم أو الهوية...',
                hintStyle: AppTheme.cairoStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 8),

            // Filter chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip('all', 'الجميع (${_allCandidates.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('unassigned', 'غير مسندين'),
                const SizedBox(width: 6),
                _buildFilterChip('assigned', 'مسندين'),
              ],
            ),
            const SizedBox(height: 8),

            // Candidates list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(child: Text('لا توجد نتائج مطابقة', style: AppTheme.cairoStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (ctx, idx) {
                            final s = filtered[idx];
                            final int sId = s['id'];
                            final String sName = s['fullName'] ?? '';
                            final circleId = s['circleId'];
                            final circleName = s['circleName'];
                            final isAlreadyInTarget = circleId == _targetCircle.id;
                            final isInOtherCircle = circleId != null && circleId > 0 && !isAlreadyInTarget;

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person, size: 18, color: AppTheme.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(
                                          isInOtherCircle ? 'مسند بحلقة: $circleName' : (isAlreadyInTarget ? 'مسند بحلقتك الحالية' : 'غير مسند لحلقة'),
                                          style: AppTheme.cairoStyle(
                                            fontSize: 11,
                                            color: isInOtherCircle ? Colors.orange.shade800 : (isAlreadyInTarget ? Colors.green.shade800 : Colors.blue.shade800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAlreadyInTarget)
                                    const Chip(
                                      label: Text('منسب هنا', style: TextStyle(fontSize: 10, color: Colors.green)),
                                      backgroundColor: Color(0xFFE8F5E9),
                                      padding: EdgeInsets.zero,
                                    )
                                  else if (isInOtherCircle)
                                    Chip(
                                      label: Text('بحلقة أخرى', style: TextStyle(fontSize: 10, color: Colors.orange.shade900)),
                                      backgroundColor: const Color(0xFFFFF3E0),
                                      padding: EdgeInsets.zero,
                                    )
                                  else
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _executeEnroll(sId, sName),
                                      child: Text('تنسيب', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filterStatus == key;
    return ChoiceChip(
      label: Text(label, style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      onSelected: (val) {
        if (val) setState(() => _filterStatus = key);
      },
    );
  }
}

// -------------------------------------------------------------
// Add New Student Modal Dialog (Gated by allowTeacherSelfEnrollment)
// -------------------------------------------------------------
class _AddNewStudentModalDialog extends StatefulWidget {
  final Circle circle;
  final VoidCallback onAdded;

  const _AddNewStudentModalDialog({
    required this.circle,
    required this.onAdded,
  });

  @override
  State<_AddNewStudentModalDialog> createState() => _AddNewStudentModalDialogState();
}

class _AddNewStudentModalDialogState extends State<_AddNewStudentModalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _memorizationController = TextEditingController(text: 'مبتدئ');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _memorizationController.dispose();
    super.dispose();
  }

  Future<void> _submitNewStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final success = await ApiService.createStudent({
        'fullName': _nameController.text.trim(),
        'studentIdentityNumber': _idNumberController.text.trim(),
        'studentMobile': _phoneController.text.trim(),
        'familyContact': _phoneController.text.trim(),
        'parentName': _parentNameController.text.trim(),
        'previousQuranMemorization': _memorizationController.text.trim(),
        'circleId': widget.circle.id,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context);
          widget.onAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ تم تسجيل الطالب وتنسيبه للحلقة بنجاح!', style: AppTheme.cairoStyle()), backgroundColor: Colors.green.shade800),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل تسجيل الطالب، تأكد من صحة البيانات ورقم الهوية', style: AppTheme.cairoStyle())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: AppTheme.cairoStyle())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تسجيل طالب جديد بالحلقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Text('الحلقة: ${widget.circle.name}', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                const Divider(),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم الطالب الرباعي:',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الطالب مطلوب' : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _idNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'رقم الهوية:',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'رقم الهوية مطلوب' : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _parentNameController,
                  decoration: InputDecoration(
                    labelText: 'اسم ولي الأمر:',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم هاتف التواصل:',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _memorizationController,
                  decoration: InputDecoration(
                    labelText: 'مستوى / خطة الحفظ:',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _isSaving ? null : _submitNewStudent,
                    child: Text(_isSaving ? 'جاري الحفظ...' : 'تسجيل وتنسيب الطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
