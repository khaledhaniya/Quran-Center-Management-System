import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'course_attendance_screen.dart';

class CoursesManagementScreen extends StatefulWidget {
  const CoursesManagementScreen({super.key});

  @override
  State<CoursesManagementScreen> createState() => _CoursesManagementScreenState();
}

class _CoursesManagementScreenState extends State<CoursesManagementScreen> {
  List<Course> _courses = [];
  List<Teacher> _teachers = [];
  List<User> _users = [];
  List<Student> _allStudents = [];
  List<Circle> _allCircles = [];
  bool _isLoading = true;

  // Digital Portfolio & Certificates State
  List<Map<String, dynamic>> _portfolioItems = [];
  bool _isLoadingPortfolio = false;
  String _portfolioCategory = 'all'; // 'all', 'courses', 'quran'
  String _portfolioSearchQuery = '';

  bool get _isAdminOrDev =>
      ApiService.currentUser?.role == 'Admin' || ApiService.currentUser?.role == 'Developer';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPortfolioData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    try {
      final coursesList = await ApiService.getCourses();
      final teachersList = await ApiService.getTeachers();
      final usersList = await ApiService.getUsers();
      final studentsList = await ApiService.getStudents();
      final circlesList = await ApiService.getCircles();

      if (mounted) {
        setState(() {
          _courses = coursesList;
          _teachers = teachersList;
          _users = usersList;
          _allStudents = studentsList;
          _allCircles = circlesList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPortfolioData() async {
    setState(() => _isLoadingPortfolio = true);
    try {
      final nominations = await ApiService.getNominations();
      final myCourses = await ApiService.getMyCourses();

      final List<Map<String, dynamic>> items = [];

      for (var n in nominations) {
        if (n.status == 'Completed' && n.result != null && n.result!.grade >= 60) {
          final isQuran = n.nominationType == 'Quran';
          final title = isQuran
              ? (n.juzStart == n.juzEnd ? 'حفظ الجزء ${n.juzStart}' : 'حفظ الأجزاء (${n.juzStart} - ${n.juzEnd})')
              : (n.courseName?.isNotEmpty == true ? n.courseName! : 'دورة تخصصية');
          final code = isQuran ? 'CERT-Q-100${n.id}' : 'CERT-CRS-200${n.id}';
          final examDateStr = n.result!.examDate ?? n.examDate;
          final dateVal = (examDateStr != null && examDateStr.length >= 10) ? examDateStr.substring(0, 10) : (examDateStr ?? '2026-09-20');
          items.add({
            'id': n.id,
            'isQuran': isQuran,
            'studentName': n.studentName,
            'title': title,
            'grade': n.result!.grade,
            'date': dateVal,
            'teacherName': n.teacherName.isNotEmpty ? n.teacherName : (isQuran ? 'محفظ ومربي الحلقة' : 'معلم ومحاضر الدورة'),
            'code': code,
            'pdfUrl': '${ApiService.baseUrl}/exams/certificate/${n.id}/printable?download=pdf',
          });
        }
      }

      for (var c in myCourses) {
        final code = c['certificateCode']?.toString() ?? 'CERT-CRS-${c['id']}';
        final studentName = c['studentName']?.toString() ?? '';
        if (studentName.isNotEmpty && (c['status'] == 'Passed' || c['status'] == 'Certified')) {
          final exists = items.any((it) => it['code'] == code || (it['studentName'] == studentName && it['title'] == c['courseName']));
          if (!exists) {
            items.add({
              'id': c['id'],
              'isQuran': false,
              'studentName': studentName,
              'title': c['courseName']?.toString() ?? 'دورة علمية',
              'grade': (c['grade'] as num?)?.toDouble() ?? 90.0,
              'date': c['certificateDate']?.toString().substring(0, 10) ?? c['enrollmentDate']?.toString().substring(0, 10) ?? '2026-09-20',
              'teacherName': c['teacherName']?.toString() ?? 'معلم ومحاضر الدورة',
              'code': code,
              'pdfUrl': '${ApiService.baseUrl}/certificates/course/${c['id']}/printable?download=pdf',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _portfolioItems = items;
          _isLoadingPortfolio = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPortfolio = false);
      }
    }
  }

  void _showAddEditCourseModal([Course? course]) {
    final nameController = TextEditingController(text: course?.name ?? '');
    final descController = TextEditingController(text: course?.description ?? '');

    Teacher? selectedTeacher;
    if (course?.teacherId != null && _teachers.isNotEmpty) {
      try {
        selectedTeacher = _teachers.firstWhere((t) => t.id == course!.teacherId);
      } catch (_) {
        selectedTeacher = _teachers.first;
      }
    } else if (_teachers.isNotEmpty) {
      selectedTeacher = _teachers.first;
    }

    final supervisors = _users.where((u) => u.role == 'ExamSupervisor' || u.role == 'Admin' || u.role == 'Developer').toList();
    
    for (var t in _teachers) {
      if (!supervisors.any((u) => u.id == t.id || u.fullName == t.fullName)) {
        supervisors.add(User(id: t.id, username: 'teacher_${t.id}', role: 'Teacher', fullName: '${t.fullName} (معلم)', isActive: true));
      }
    }

    User? selectedSupervisor;
    if (course?.examSupervisorId != null && supervisors.isNotEmpty) {
      try {
        selectedSupervisor = supervisors.firstWhere((u) => u.id == course!.examSupervisorId);
      } catch (_) {
        selectedSupervisor = supervisors.first;
      }
    } else if (supervisors.isNotEmpty) {
      selectedSupervisor = supervisors.first;
    }

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.school, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course == null ? 'إضافة دورة أكاديمية جديدة' : 'تعديل وتحديد مشرف الدورة',
                  style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدورة / المساق العلمي *',
                    prefixIcon: Icon(Icons.book, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'وصف المقرر ومحاوره التعليمية',
                    prefixIcon: Icon(Icons.description, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 14),
                if (_teachers.isNotEmpty) ...[
                  Text('الشيخ المعلم المحفّظ:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Teacher>(
                    isExpanded: true,
                    initialValue: selectedTeacher,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person, color: AppTheme.primary)),
                    items: _teachers.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.fullName, style: AppTheme.cairoStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedTeacher = val),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('مشرف التقييم والاختبارات:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        if (selectedTeacher != null) {
                          try {
                            final match = supervisors.firstWhere((u) => u.id == selectedTeacher!.id || u.fullName.contains(selectedTeacher!.fullName));
                            setModalState(() => selectedSupervisor = match);
                          } catch (_) {
                            final tUser = User(id: selectedTeacher!.id, username: 't_${selectedTeacher!.id}', role: 'Teacher', fullName: '${selectedTeacher!.fullName} (معلم)', isActive: true);
                            setModalState(() {
                              supervisors.add(tUser);
                              selectedSupervisor = tUser;
                            });
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تعيين المعلم كمشرف للتقييم ذاته بنجاح ⚡'),
                              backgroundColor: Colors.amber,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text('اجعل المعلم هو المشرف', style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (supervisors.isNotEmpty)
                  DropdownButtonFormField<User>(
                    isExpanded: true,
                    initialValue: selectedSupervisor,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.security, color: Colors.amber)),
                    items: supervisors.map((u) {
                      return DropdownMenuItem(
                        value: u,
                        child: Text(u.fullName, style: AppTheme.cairoStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedSupervisor = val),
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
              icon: isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white, size: 18),
              label: Text(
                isSaving ? 'جاري الحفظ...' : (course == null ? 'حفظ الدورة' : 'حفظ التعديلات'),
                style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: isSaving ? null : () async {
                if (nameController.text.trim().isEmpty) return;
                setModalState(() => isSaving = true);

                bool ok = false;
                if (course == null) {
                  ok = await ApiService.createCourse(
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    teacherId: selectedTeacher?.id,
                    examSupervisorId: selectedSupervisor?.id,
                  );
                } else {
                  ok = await ApiService.updateCourse(
                    course.id,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    teacherId: selectedTeacher?.id,
                    examSupervisorId: selectedSupervisor?.id,
                  );
                }

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (ok) {
                  _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(course == null ? 'تمت إضافة الدورة التعليمية بنجاح' : 'تم تعديل بيانات الدورة والمشرف بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseEnrollmentsModal(Course course) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('طلاب دورة: ${course.name}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiService.getCourseEnrollments(course.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return Text('لا يوجد طلاب مسجلين في هذه الدورة حالياً.', style: AppTheme.cairoStyle(color: Colors.grey));
            }
            return SizedBox(
              width: double.maxFinite,
              height: 320,
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  final name = item['studentName'] ?? 'طالب';
                  final grade = item['grade'];
                  final status = item['status'] ?? 'Enrolled';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(name, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الحلقة: ${item['halaqahName'] ?? "بدون حلقة"}', style: AppTheme.cairoStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'Passed'
                                  ? Colors.green.withOpacity(0.15)
                                  : (status == 'Failed' ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              grade != null ? '$grade%' : (status == 'Passed' ? 'ناجح' : 'قيد الدراسة'),
                              style: AppTheme.cairoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status == 'Passed' ? Colors.green : (status == 'Failed' ? Colors.red : Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: AppTheme.primary, size: 22),
                            tooltip: 'رصد درجة الطالب مباشرة',
                            onPressed: () => _promptRecordStudentGrade(item, course),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _promptRecordStudentGrade(Map<String, dynamic> enrollmentItem, Course course) {
    final gradeCtrl = TextEditingController(text: enrollmentItem['grade']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.grade, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'رصد درجة: ${enrollmentItem['studentName']}',
                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دورة: ${course.name}', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            TextField(
              controller: gradeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'العلامة المستحقة (من 100) *',
                prefixIcon: Icon(Icons.percent, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: const Icon(Icons.save, color: Colors.white, size: 16),
            label: Text('حفظ واعتتماد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final val = double.tryParse(gradeCtrl.text.trim());
              if (val == null || val < 0 || val > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال علامة صحيحة بين 0 و 100'), backgroundColor: Colors.orange),
                );
                return;
              }
              try {
                final enrollmentId = enrollmentItem['id'] ?? enrollmentItem['enrollmentId'];
                await ApiService.recordCourseGrade(enrollmentId: enrollmentId, grade: val);
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                Navigator.pop(context); // close enrollments dialog
                _showCourseEnrollmentsModal(course); // re-open updated
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم رصد العلامة واعتتماد النتيجة بنجاح ✨'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEnrollStudentModal(Course course) {
    String enrollType = 'student';
    Student? selectedStudent;
    Circle? selectedCircle;
    String searchQuery = '';
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredStudents = _allStudents.where((s) {
            if (!s.isActive) return false;
            if (searchQuery.isEmpty) return true;
            return s.fullName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (s.circleName != null && s.circleName!.toLowerCase().contains(searchQuery.toLowerCase()));
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.person_add, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تسجيل طلاب في: ${course.name}',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person, size: 16),
                                const SizedBox(width: 4),
                                Text('طالب محدد', style: AppTheme.cairoStyle(fontSize: 12)),
                              ],
                            ),
                            selected: enrollType == 'student',
                            onSelected: (val) {
                              if (val) setModalState(() => enrollType = 'student');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.groups, size: 16),
                                const SizedBox(width: 4),
                                Text('حلقة كاملة', style: AppTheme.cairoStyle(fontSize: 12)),
                              ],
                            ),
                            selected: enrollType == 'circle',
                            onSelected: (val) {
                              if (val) setModalState(() => enrollType = 'circle');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (enrollType == 'student') ...[
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: '🔍 ابحث عن اسم الطالب أو الحلقة...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: filteredStudents.isEmpty
                            ? Center(
                                child: Text('لا يوجد طلاب مطابقين للبحث', style: AppTheme.cairoStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, idx) {
                                  final st = filteredStudents[idx];
                                  final isSelected = selectedStudent?.id == st.id;
                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    selectedTileColor: AppTheme.primary.withOpacity(0.12),
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSelected ? AppTheme.primary : Colors.grey.shade300,
                                      child: Icon(
                                        isSelected ? Icons.check : Icons.person,
                                        size: 14,
                                        color: isSelected ? Colors.white : Colors.grey.shade700,
                                      ),
                                    ),
                                    title: Text(st.fullName, style: AppTheme.cairoStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                    subtitle: Text('الحلقة: ${st.circleName ?? "بدون حلقة"}', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    onTap: () => setModalState(() => selectedStudent = st),
                                  );
                                },
                              ),
                      ),
                    ] else ...[
                      Text('اختر الحلقة المراد إدراج جميع طلابها:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<Circle>(
                        isExpanded: true,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.groups, color: AppTheme.primary)),
                        items: _allCircles.where((c) => c.isActive).map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c.name, style: AppTheme.cairoStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedCircle = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                label: Text('تسجيل بالدورة', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  if (enrollType == 'student' && selectedStudent == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار طالب من القائمة أولاً'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (enrollType == 'circle' && selectedCircle == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار حلقة أولاً'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  try {
                    final ok = await ApiService.enrollInCourse(
                      courseId: course.id,
                      studentId: enrollType == 'student' ? selectedStudent!.id : null,
                      circleId: enrollType == 'circle' ? selectedCircle!.id : null,
                    );

                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);

                    if (ok) {
                      _loadData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تسجيل الطلاب في الدورة التعليمية بنجاح 🎓'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (!dialogCtx.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteCourse(Course c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('تأكيد حذف الدورة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Text(
          'هل أنت تأكد من حذف الدورة الأكاديمية (${c.name}) نهائياً؟\nسيتم إزالة كافة سجلات التحضير والدرجات التابعة لها.',
          style: AppTheme.cairoStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
            label: Text('حذف الدورة', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.deleteCourse(c.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف الدورة (${c.name}) بنجاح'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ApiService.currentUser ?? User(id: 0, username: 'guest', fullName: 'زائر', role: 'Student', isActive: true);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('المساقات وملف الإنجاز الرقمي', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: AppTheme.cairoStyle(fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.school), text: 'مسارات الدورات'),
              Tab(icon: Icon(Icons.workspace_premium), text: 'ملف الإنجاز والشهادات'),
            ],
          ),
        ),
        floatingActionButton: _isAdminOrDev
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primary,
                onPressed: () => _showAddEditCourseModal(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text('إضافة دورة أكاديمية', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
        body: TabBarView(
          children: [
            _buildCoursesList(currentUser),
            _buildPortfolioTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesList(User currentUser) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text('لا توجد دورات مسجلة حالياً', style: AppTheme.cairoStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
                  padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 90),
                  itemCount: _courses.length,
                  itemBuilder: (ctx, index) {
                    final c = _courses[index];
                    final isSameSupervisor = c.teacherId != null && c.examSupervisorId != null && c.teacherId == c.examSupervisorId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.06),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('#${index + 1}', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: c.isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.isActive ? Colors.green : Colors.red),
                                  ),
                                  child: Text(
                                    c.isActive ? 'نشطة ومتاحة' : 'غير نشطة',
                                    style: AppTheme.cairoStyle(
                                      color: c.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Body Content
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bookmark, color: AppTheme.accent, size: 20),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                if (c.description != null && c.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(right: BorderSide(color: AppTheme.accent, width: 3)),
                                    ),
                                    child: Text(
                                      c.description!,
                                      style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Info Pills
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.person, size: 16, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Text('المعلم المحفّظ: ', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
                                          Expanded(
                                            child: Text(
                                              c.teacherName ?? "غير مسند",
                                              style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.security, size: 16, color: Colors.amber),
                                          const SizedBox(width: 6),
                                          Text('مشرف التقييم: ', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
                                          Expanded(
                                            child: Text(
                                              '${c.examSupervisorName ?? "غير مسند"}${isSameSupervisor ? " (نفس المعلم)" : ""}',
                                              style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.groups, size: 16, color: Colors.blue),
                                          const SizedBox(width: 6),
                                          Text('الطلاب المسجلين: ', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
                                          Text(
                                            '${c.enrollmentCount} طالب ملتحق',
                                            style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Actions Footer Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              border: Border(top: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                // Enroll Student Button (HIDDEN for Teachers, shown ONLY to Admin/Dev)
                                if (_isAdminOrDev)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                      side: const BorderSide(color: AppTheme.primary),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.person_add, size: 15),
                                    label: Text('تسجيل طلاب', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showEnrollStudentModal(c),
                                  ),

                                // Attendance Button (Available to Admin/Dev/Teacher)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade800,
                                    side: BorderSide(color: Colors.green.shade600),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.fact_check, size: 15),
                                  label: Text('التحضير', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CourseAttendanceScreen(currentUser: currentUser, initialCourseId: c.id),
                                      ),
                                    );
                                  },
                                ),

                                // Grades / Enrollments List Button
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber.shade900,
                                    side: BorderSide(color: Colors.amber.shade700),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.verified, size: 15),
                                  label: Text('الدرجات', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showCourseEnrollmentsModal(c),
                                ),

                                // Edit Supervisor & Instructor (Admin/Dev ONLY)
                                if (_isAdminOrDev)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue.shade800,
                                      side: BorderSide(color: Colors.blue.shade600),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.manage_accounts, size: 15),
                                    label: Text('المشرف والمعلم', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showAddEditCourseModal(c),
                                  ),

                                // Delete Course Button (Admin/Dev ONLY)
                                if (_isAdminOrDev)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade800,
                                      side: BorderSide(color: Colors.red.shade600),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.delete_outline, size: 15),
                                    label: Text('حذف الدورة', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _deleteCourse(c),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
  }

  Widget _buildPortfolioTab() {
    if (_isLoadingPortfolio) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _portfolioSearchQuery.trim().toLowerCase();
    final filtered = _portfolioItems.where((item) {
      if (_portfolioCategory == 'courses' && item['isQuran'] == true) return false;
      if (_portfolioCategory == 'quran' && item['isQuran'] == false) return false;
      if (query.isNotEmpty) {
        final name = (item['studentName'] ?? '').toString().toLowerCase();
        final title = (item['title'] ?? '').toString().toLowerCase();
        final code = (item['code'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !title.contains(query) && !code.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadPortfolioData,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.primary.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'السجل الرقمي المعتمد للمركز',
                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_portfolioItems.length} شهادة معتمدة',
                        style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الطالب، الدورة، أو رمز الاعتماد...',
                    hintStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primary),
                    suffixIcon: _portfolioSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _portfolioSearchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  onChanged: (val) => setState(() => _portfolioSearchQuery = val),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPortfolioFilterChip('all', 'الكل (${_portfolioItems.length})'),
                      const SizedBox(width: 6),
                      _buildPortfolioFilterChip('courses', 'الدورات التخصصية (${_portfolioItems.where((i) => !i['isQuran']).length})'),
                      const SizedBox(width: 6),
                      _buildPortfolioFilterChip('quran', 'القرآن الكريم (${_portfolioItems.where((i) => i['isQuran']).length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium_outlined, size: 64, color: AppTheme.accent),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد شهادات رقمية مسجلة حالياً',
                            style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'فور اجتياز الطلاب للمساقات أو امتحانات الأجزاء بنجاح، ستظهر شهاداتهم هنا.',
                            style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      final isQuran = item['isQuran'] == true;
                      final grade = (item['grade'] as num?)?.toDouble() ?? 0.0;
                      final gradeText = grade >= 95 ? 'ممتاز مرتفع' : (grade >= 90 ? 'ممتاز' : (grade >= 80 ? 'جيد جداً' : 'ناجح'));
                      final code = item['code']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppTheme.accent.withOpacity(0.5), width: 1.2),
                        ),
                        elevation: 2,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFFFFDF5)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isQuran ? AppTheme.primary : Colors.teal.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isQuran ? Icons.menu_book : Icons.school, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          isQuran ? 'شهادة إتقان قرآن' : 'شهادة مساق معتمد',
                                          style: AppTheme.cairoStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.shade400),
                                    ),
                                    child: Text(
                                      code,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              Text(
                                item['studentName']?.toString() ?? '',
                                style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['title']?.toString() ?? '',
                                style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(
                                      'التقدير: $gradeText ($grade%)',
                                      style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'التاريخ: ${item['date'] ?? ""}',
                                    style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'المعلم / المشرف: ${item['teacherName'] ?? ""}',
                                style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),

                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.copy, size: 14, color: AppTheme.accent),
                                    label: Text('نسخ الرمز', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textDark)),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: code));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('تم نسخ الرمز: $code'), duration: const Duration(seconds: 1)),
                                      );
                                    },
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf, size: 15),
                                    label: Text('تحميل PDF 📥', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      final url = Uri.parse(item['pdfUrl']?.toString() ?? '');
                                      try {
                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('تعذر فتح الشهادة: $e')),
                                          );
                                        }
                                      }
                                    },
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

  Widget _buildPortfolioFilterChip(String cat, String label) {
    final isSelected = _portfolioCategory == cat;
    return ChoiceChip(
      label: Text(label, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.white,
      onSelected: (val) {
        if (val) setState(() => _portfolioCategory = cat);
      },
    );
  }
}
