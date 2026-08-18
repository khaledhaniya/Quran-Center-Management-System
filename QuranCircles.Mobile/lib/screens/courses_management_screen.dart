import 'package:flutter/material.dart';
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

  bool get _isAdminOrDev =>
      ApiService.currentUser?.role == 'Admin' || ApiService.currentUser?.role == 'Developer';

  @override
  void initState() {
    super.initState();
    _loadData();
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
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: Text(course == null ? 'حفظ الدورة' : 'حفظ التعديلات', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

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
              height: 300,
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
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'Passed'
                              ? Colors.green.withOpacity(0.15)
                              : (status == 'Failed' ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          grade != null ? 'العلامة: $grade%' : (status == 'Passed' ? 'ناجح' : 'قيد الدراسة'),
                          style: AppTheme.cairoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: status == 'Passed' ? Colors.green : (status == 'Failed' ? Colors.red : Colors.blue),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
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

    return Scaffold(
      appBar: AppBar(
        title: Text('المساقات والدورات الأكاديمية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: _isAdminOrDev
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              onPressed: () => _showAddEditCourseModal(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('إضافة دورة أكاديمية', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('لا توجد دورات مسجلة حالياً', style: AppTheme.cairoStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
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
                                  child: Text('#${c.id}', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
                ),
    );
  }
}
