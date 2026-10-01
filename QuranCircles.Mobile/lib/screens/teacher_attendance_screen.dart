import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final User currentUser;
  const TeacherAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Circle> _circles = [];
  Circle? _selectedCircle;
  DateTime _selectedDate = DateTime.now();
  List<Student> _circleStudents = [];
  Map<int, String> _attendanceStatus = {}; // studentId -> 'Present', 'Absent', 'Excused', 'Late'
  bool _allowTeacherEnroll = true;

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

      // Filter by teacher if teacher role
      List<Circle> myCircles = activeCircles;
      if (widget.currentUser.role == 'Teacher') {
        myCircles = activeCircles.where((c) {
          final tName = c.teacherName?.trim() ?? '';
          final uName = widget.currentUser.fullName.trim();
          return tName.isNotEmpty && (tName == uName || tName.contains(uName) || uName.contains(tName));
        }).toList();
        if (myCircles.isEmpty) myCircles = activeCircles;
      }

      // Check system settings for enrollment
      try {
        final settings = await ApiService.getSystemSettings();
        if (settings != null && settings.containsKey('allowTeacherSelfEnrollment')) {
          _allowTeacherEnroll = settings['allowTeacherSelfEnrollment'] == true;
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
          await _loadCircleStudentsAndAttendance();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الحلقات: $e', style: AppTheme.cairoStyle())),
        );
      }
    }
  }

  Future<void> _loadCircleStudentsAndAttendance() async {
    if (_selectedCircle == null) return;
    setState(() => _isLoading = true);

    try {
      final allStudents = await ApiService.getStudents();
      final students = allStudents.where((s) => s.circleId == _selectedCircle!.id).toList();

      final Map<int, String> statusMap = {};
      for (var s in students) {
        statusMap[s.id] = _attendanceStatus[s.id] ?? 'Present';
      }

      if (mounted) {
        setState(() {
          _circleStudents = students;
          _attendanceStatus = statusMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedCircle == null || _circleStudents.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final records = _circleStudents.map((s) {
        int statusInt = 1;
        final st = _attendanceStatus[s.id] ?? 'Present';
        if (st == 'Absent') {
          statusInt = 2;
        } else if (st == 'Excused') {
          statusInt = 3;
        } else if (st == 'Late') {
          statusInt = 4;
        }

        return {
          'studentId': s.id,
          'status': statusInt,
        };
      }).toList();

      final success = await ApiService.saveCircleAttendance(_selectedCircle!.id, dateStr, records);
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم حفظ وتحديث سجل الحضور بنجاح!', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل في حفظ الحضور، يرجى المحاولة مجدداً', style: AppTheme.cairoStyle())),
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

  void _showTeacherEnrollModal() async {
    if (!_allowTeacherEnroll) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تنسيب الطلاب بواسطة المعلم معطل حالياً من قبل الإدارة', style: AppTheme.cairoStyle())),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _EnrollStudentDialog(
        currentCircle: _selectedCircle!,
        myCircles: _circles,
        onEnrolled: () {
          _loadCircleStudentsAndAttendance();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('تسجيل الحضور اليومي للطلاب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _circles.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadCircleStudentsAndAttendance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Setup Bar Card (Matches Web #attendance-setup-bar)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.circle_notifications, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text('إعدادات كشف الحضور:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Circle dropdown
                            DropdownButtonFormField<Circle>(
                              value: _selectedCircle,
                              decoration: InputDecoration(
                                labelText: 'الحلقة:',
                                labelStyle: AppTheme.cairoStyle(),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _circles.map((c) {
                                return DropdownMenuItem<Circle>(
                                  value: c,
                                  child: Text(c.name, style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCircle = val);
                                  _loadCircleStudentsAndAttendance();
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            // Date Picker Row
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2024),
                                        lastDate: DateTime.now().add(const Duration(days: 3)),
                                      );
                                      if (picked != null) {
                                        setState(() => _selectedDate = picked);
                                        _loadCircleStudentsAndAttendance();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade400),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_month, color: AppTheme.primary, size: 18),
                                              const SizedBox(width: 8),
                                              Text(dateStr, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text('عرض', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: _loadCircleStudentsAndAttendance,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Attendance List Card (Matches Web #attendance-list-card)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header of list card
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'قائمة طلاب ${_selectedCircle?.name ?? ""}',
                                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'إجمالي الطلاب: ${_circleStudents.length}',
                                        style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_allowTeacherEnroll)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    icon: const Icon(Icons.person_add, size: 15),
                                    label: Text('تنسيب طالب', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: _showTeacherEnrollModal,
                                  ),
                              ],
                            ),
                            const Divider(height: 20),

                            if (_circleStudents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 30),
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    Text('لا يوجد طلاب مسندين في هذه الحلقة حالياً', style: AppTheme.cairoStyle(color: Colors.grey.shade600)),
                                    if (_allowTeacherEnroll) ...[
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.person_add),
                                        label: Text('تنسيب طالب للحلقة الآن', style: AppTheme.cairoStyle()),
                                        onPressed: _showTeacherEnrollModal,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _circleStudents.length,
                                separatorBuilder: (_, __) => const Divider(height: 12),
                                itemBuilder: (ctx, idx) {
                                  final s = _circleStudents[idx];
                                  final currentStatus = _attendanceStatus[s.id] ?? 'Present';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                s.fullName,
                                                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Choice chips matching web radio buttons
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _buildStatusChip(s.id, 'Present', 'حاضر', Colors.green, currentStatus == 'Present'),
                                            _buildStatusChip(s.id, 'Absent', 'غائب', Colors.red, currentStatus == 'Absent'),
                                            _buildStatusChip(s.id, 'Excused', 'معذور', Colors.amber.shade800, currentStatus == 'Excused'),
                                            _buildStatusChip(s.id, 'Late', 'متأخر', Colors.orange, currentStatus == 'Late'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 16),
                            // Save button
                            if (_circleStudents.isNotEmpty)
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade800,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 2,
                                  ),
                                  icon: _isSaving
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.cloud_upload),
                                  label: Text(
                                    _isSaving ? 'جاري الحفظ...' : 'حفظ وتحديث سجل الحضور',
                                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  onPressed: _isSaving ? null : _saveAttendance,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusChip(int studentId, String statusKey, String label, Color color, bool isSelected) {
    return ChoiceChip(
      label: Text(label, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color)),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onSelected: (val) {
        if (val) {
          setState(() {
            _attendanceStatus[studentId] = statusKey;
          });
        }
      },
    );
  }
}

// -------------------------------------------------------------
// Enrollment Modal Dialog (Matching Web showTeacherEnrollExistingModal)
// -------------------------------------------------------------
class _EnrollStudentDialog extends StatefulWidget {
  final Circle currentCircle;
  final List<Circle> myCircles;
  final VoidCallback onEnrolled;

  const _EnrollStudentDialog({
    required this.currentCircle,
    required this.myCircles,
    required this.onEnrolled,
  });

  @override
  State<_EnrollStudentDialog> createState() => _EnrollStudentDialogState();
}

class _EnrollStudentDialogState extends State<_EnrollStudentDialog> {
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
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          widget.onEnrolled();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم تنسيب الطالب $studentName لحلقة ${_targetCircle.name} بنجاح!', style: AppTheme.cairoStyle()),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التنسيب: $e', style: AppTheme.cairoStyle())),
        );
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

            // Target circle selector
            if (widget.myCircles.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<Circle>(
                  value: _targetCircle,
                  decoration: InputDecoration(
                    labelText: 'الحلقة المستهدفة:',
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
                hintText: 'ابحث بالاسم أو الهوية أو الهاتف...',
                hintStyle: AppTheme.cairoStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 8),

            // Filter status chips
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

            // Results list
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
