import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CourseAttendanceScreen extends StatefulWidget {
  final User currentUser;
  final int? initialCourseId;

  const CourseAttendanceScreen({
    super.key,
    required this.currentUser,
    this.initialCourseId,
  });

  @override
  State<CourseAttendanceScreen> createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  List<Course> _courses = [];
  Course? _selectedCourse;
  List<CourseAttendanceRecord> _records = [];
  final Map<int, int> _attendanceStatus = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() async {
    try {
      var list = await ApiService.getCourses();
      final isTeacher = widget.currentUser.role == 'Teacher';
      if (isTeacher && widget.currentUser.teacherId != null) {
        list = list.where((c) => c.teacherId == widget.currentUser.teacherId).toList();
      }

      if (mounted) {
        setState(() {
          _courses = list;
          if (widget.initialCourseId != null) {
            _selectedCourse = list.firstWhere(
              (c) => c.id == widget.initialCourseId,
              orElse: () => list.isNotEmpty ? list.first : Course(id: 0, name: '', isActive: true),
            );
          } else if (list.isNotEmpty) {
            _selectedCourse = list.first;
          }
          _isLoading = false;
        });

        if (_selectedCourse != null && _selectedCourse!.id > 0) {
          _fetchCourseAttendance();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _fetchCourseAttendance() async {
    if (_selectedCourse == null) return;

    final dateStr = _formatDate(_selectedDate);
    try {
      final list = await ApiService.getCourseAttendance(_selectedCourse!.id, dateStr);
      if (mounted) {
        setState(() {
          _records = list;
          _attendanceStatus.clear();
          for (var r in list) {
            _attendanceStatus[r.studentId] = r.status;
          }
        });
      }
    } catch (_) {}
  }

  void _saveAttendance() async {
    if (_selectedCourse == null || _records.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final dateStr = _formatDate(_selectedDate);
    final recordsData = _records.map((r) {
      return {
        'studentId': r.studentId,
        'status': _attendanceStatus[r.studentId] ?? 1,
      };
    }).toList();

    try {
      final ok = await ApiService.saveCourseAttendance(_selectedCourse!.id, dateStr, recordsData);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ كشف حضور المساق والدورة بنجاح!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحضير وحضور طلاب المساقات والدورات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(child: Text('لا يوجد مساق مسند لك حالياً', style: AppTheme.cairoStyle()))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.surfaceCard,
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Course>(
                              value: _selectedCourse,
                              decoration: const InputDecoration(labelText: 'اختر المساق/الدورة'),
                              items: _courses.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCourse = val;
                                  });
                                  _fetchCourseAttendance();
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
                                _fetchCourseAttendance();
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_formatDate(_selectedDate)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _records.isEmpty
                          ? Center(child: Text('لا يوجد طلاب مسجلون في هذا المساق حالياً', style: AppTheme.cairoStyle()))
                          : ListView.builder(
                              padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 88),
                              itemCount: _records.length,
                              itemBuilder: (ctx, index) {
                                final r = _records[index];
                                final currentStatus = _attendanceStatus[r.studentId] ?? 1;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(r.studentName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('المساق: ${r.courseName}', style: AppTheme.cairoStyle(fontSize: 12)),
                                    trailing: ToggleButtons(
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
                                          _attendanceStatus[r.studentId] = btnIndex + 1;
                                        });
                                      },
                                      children: const [
                                        Text('حاضر', style: TextStyle(fontSize: 11)),
                                        Text('غائب', style: TextStyle(fontSize: 11)),
                                        Text('متأخر', style: TextStyle(fontSize: 11)),
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
                        label: Text('حفظ كشف حضور المساق والدورة', style: AppTheme.cairoStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
    );
  }
}
