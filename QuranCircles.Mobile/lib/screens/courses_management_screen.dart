import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CoursesManagementScreen extends StatefulWidget {
  const CoursesManagementScreen({super.key});

  @override
  State<CoursesManagementScreen> createState() => _CoursesManagementScreenState();
}

class _CoursesManagementScreenState extends State<CoursesManagementScreen> {
  List<Course> _courses = [];
  List<Teacher> _teachers = [];
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final coursesList = await ApiService.getCourses();
      final teachersList = await ApiService.getTeachers();
      final usersList = await ApiService.getUsers();

      if (mounted) {
        setState(() {
          _courses = coursesList;
          _teachers = teachersList;
          _users = usersList;
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

  void _showAddEditCourseModal([Course? course]) {
    final nameController = TextEditingController(text: course?.name ?? '');
    final descController = TextEditingController(text: course?.description ?? '');

    Teacher? selectedTeacher = course?.teacherId != null
        ? _teachers.firstWhere((t) => t.id == course!.teacherId, orElse: () => _teachers.first)
        : (_teachers.isNotEmpty ? _teachers.first : null);

    final supervisors = _users.where((u) => u.role == 'ExamSupervisor' || u.role == 'Admin' || u.role == 'Developer').toList();
    User? selectedSupervisor = course?.examSupervisorId != null
        ? supervisors.firstWhere((u) => u.id == course!.examSupervisorId, orElse: () => supervisors.first)
        : (supervisors.isNotEmpty ? supervisors.first : null);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            course == null ? 'إضافة دورة/مساق علمي جديد' : 'تعديل بيانات المساق',
            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الدورة / المساق العلمي *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'وصف المساق ومحتواه'),
                ),
                const SizedBox(height: 12),
                if (_teachers.isNotEmpty)
                  DropdownButtonFormField<Teacher>(
                    initialValue: selectedTeacher,
                    decoration: const InputDecoration(labelText: 'معلم المساق المسند'),
                    items: _teachers.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.fullName, style: AppTheme.cairoStyle()),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedTeacher = val),
                  ),
                const SizedBox(height: 12),
                if (supervisors.isNotEmpty)
                  DropdownButtonFormField<User>(
                    initialValue: selectedSupervisor,
                    decoration: const InputDecoration(labelText: 'مشرف الاختبارات المسند'),
                    items: supervisors.map((u) {
                      return DropdownMenuItem(
                        value: u,
                        child: Text('${u.fullName} (${u.role})', style: AppTheme.cairoStyle()),
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
            ElevatedButton(
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
                      content: Text(course == null ? 'تمت إضافة المساق بنجاح' : 'تم تعديل بيانات المساق بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(course == null ? 'إضافة' : 'حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  void _deactivateCourse(Course c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد التعطيل', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت تأكد من تعطيل مساق (${c.name})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعطيل'),
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
          const SnackBar(content: Text('تم تعطيل المساق بنجاح'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المساقات والدورات'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditCourseModal(),
        icon: const Icon(Icons.menu_book, color: Colors.white),
        label: Text('إضافة مساق جديد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: _courses.length,
              itemBuilder: (ctx, index) {
                final c = _courses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.accent,
                      child: Icon(Icons.school, color: Colors.white),
                    ),
                    title: Text(c.name, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'المعلم: ${c.teacherName ?? "غير مسند"} | المشرف: ${c.examSupervisorName ?? "غير مسند"} | المضمونين: ${c.enrollmentCount}',
                      style: AppTheme.cairoStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddEditCourseModal(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.block, color: Colors.red),
                          onPressed: () => _deactivateCourse(c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
