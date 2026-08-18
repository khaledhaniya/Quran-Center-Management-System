import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class Student360Screen extends StatefulWidget {
  final int? initialStudentId;

  const Student360Screen({super.key, this.initialStudentId});

  @override
  State<Student360Screen> createState() => _Student360ScreenState();
}

class _Student360ScreenState extends State<Student360Screen> {
  List<Student> _studentsList = [];
  Student? _selectedStudent;
  Map<String, dynamic>? _profileData;
  bool _isLoadingStudents = true;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    try {
      final list = await ApiService.getStudents();
      if (mounted) {
        Student? matched;
        if (widget.initialStudentId != null) {
          matched = list.firstWhere(
            (s) => s.id == widget.initialStudentId,
            orElse: () => list.isNotEmpty ? list.first : Student(id: 0, fullName: '', isActive: true),
          );
        } else if (list.isNotEmpty) {
          matched = list.first;
        }

        setState(() {
          _studentsList = list;
          _selectedStudent = matched;
          _isLoadingStudents = false;
        });

        if (matched != null && matched.id > 0) {
          _loadProfile(matched.id);
        } else if (widget.initialStudentId != null && widget.initialStudentId! > 0) {
          _loadProfile(widget.initialStudentId!);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
        });
      }
    }
  }

  void _loadProfile(int studentId) async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final data = await ApiService.getStudent360(studentId);
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerAttendance = _profileData?['centerAttendance'] as List? ?? [];
    final courseAttendance = _profileData?['courseAttendance'] as List? ?? [];
    final completedExams = _profileData?['completedExams'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedStudent != null ? 'الملف الموحد 360°: ${_selectedStudent!.fullName}' : 'الملف الموحد الشامل 360° للطالب'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'اختر الطالب لمشاهدة الملف الموحد 360°:',
                          style: AppTheme.cairoStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        if (_studentsList.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${_studentsList.length} أبناء', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!_isLoadingStudents && _studentsList.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _studentsList.map((s) {
                            final isSel = _selectedStudent?.id == s.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                avatar: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isSel ? Colors.white : AppTheme.primary,
                                  child: Text(s.fullName.isNotEmpty ? s.fullName[0] : 'ط', style: TextStyle(fontSize: 10, color: isSel ? AppTheme.primary : Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                label: Text(s.fullName, style: AppTheme.cairoStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: AppTheme.primary,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedStudent = s;
                                  });
                                  _loadProfile(s.id);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _isLoadingStudents
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<Student>(
                            initialValue: _selectedStudent,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            items: _studentsList.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.fullName} (${s.circleName ?? "بدون حلقة"})',
                                  style: AppTheme.cairoStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStudent = val;
                                });
                                _loadProfile(val.id);
                              }
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoadingProfile)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (_profileData != null) ...[
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.person, size: 36, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profileData!['studentName'] ?? '',
                              style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الحلقة القرآنية: ${_profileData!['circleName'] ?? "غير مسند"}',
                              style: AppTheme.cairoStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'المعلم المحفظ: ${_profileData!['teacherName'] ?? "غير مسند"}',
                              style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.playlist_add_check, color: AppTheme.primary, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '${_profileData!['attendanceRate'] ?? 0}%',
                            style: AppTheme.cairoStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          Text('نسبة الالتزام والحضور', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.workspace_premium, color: AppTheme.accent, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '${_profileData!['certificatesCount'] ?? 0}',
                            style: AppTheme.cairoStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent),
                          ),
                          Text('الشهادات الرقمية الحاصل عليها', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'سجل حضور وغياب الحلقة القرآنية',
                            style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const Divider(),
                      centerAttendance.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد سجلات حضور مسجلة حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: centerAttendance.length > 5 ? 5 : centerAttendance.length,
                              itemBuilder: (ctx, i) {
                                final item = centerAttendance[i];
                                final statusText = item['statusText'] ?? (item['status'] == 1 ? 'حاضر' : (item['status'] == 2 ? 'غائب' : 'متأخر'));
                                final color = item['status'] == 1
                                    ? AppTheme.statusPresent
                                    : (item['status'] == 2 ? AppTheme.statusAbsent : AppTheme.statusLate);

                                return ListTile(
                                  dense: true,
                                  title: Text('التاريخ: ${item['sessionDate'] ?? ""}', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('الحلقة: ${item['circleName'] ?? ""}', style: AppTheme.cairoStyle(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: color),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: AppTheme.cairoStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school, color: AppTheme.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'سجل حضور وغياب المساقات والدورات العلمية',
                            style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const Divider(),
                      courseAttendance.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد سجلات حضور مساقات مسجلة حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: courseAttendance.length > 5 ? 5 : courseAttendance.length,
                              itemBuilder: (ctx, i) {
                                final item = courseAttendance[i];
                                final statusText = item['statusText'] ?? (item['status'] == 1 ? 'حاضر' : (item['status'] == 2 ? 'غائب' : 'متأخر'));
                                final color = item['status'] == 1
                                    ? AppTheme.statusPresent
                                    : (item['status'] == 2 ? AppTheme.statusAbsent : AppTheme.statusLate);

                                return ListTile(
                                  dense: true,
                                  title: Text('مساق: ${item['courseName'] ?? ""}', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('التاريخ: ${item['sessionDate'] ?? ""}', style: AppTheme.cairoStyle(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: color),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: AppTheme.cairoStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'سجل الاختبارات والشهادات المكتملة',
                            style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                      const Divider(),
                      completedExams.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد اختبارات معتمدة مسجلة للطالب حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: completedExams.length,
                              itemBuilder: (ctx, i) {
                                final item = completedExams[i];
                                return ListTile(
                                  dense: true,
                                  title: Text('الاختبار: ${item['nominationType'] == 'Quran' ? 'أجزاء قرآن كريم' : 'مساق ودورة'}', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('تاريخ التقييم: ${item['examDate'] ?? ""}', style: AppTheme.cairoStyle(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Text(
                                      '${item['grade'] ?? 100}%',
                                      style: AppTheme.cairoStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
