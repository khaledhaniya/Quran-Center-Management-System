import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeachersManagementScreen extends StatefulWidget {
  const TeachersManagementScreen({super.key});

  @override
  State<TeachersManagementScreen> createState() => _TeachersManagementScreenState();
}

class _TeachersManagementScreenState extends State<TeachersManagementScreen> {
  List<Teacher> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  void _loadTeachers() async {
    try {
      final list = await ApiService.getTeachers();
      if (mounted) {
        setState(() {
          _teachers = list;
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

  void _showAddEditTeacherModal([Teacher? teacher]) {
    final nameController = TextEditingController(text: teacher?.fullName ?? '');
    final addressController = TextEditingController(text: teacher?.address ?? '');
    final contactController = TextEditingController(text: teacher?.contact ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(teacher == null ? 'إضافة معلم جديد' : 'تعديل بيانات المعلم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم الرباعي للمعلم *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان ومكان الإقامة'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف والتواصل *'),
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

              if (teacher == null) {
                final ok = await ApiService.createTeacher(
                  fullName: nameController.text.trim(),
                  address: addressController.text.trim(),
                  contact: contactController.text.trim(),
                );
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (ok) {
                  _loadTeachers();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة المعلم بنجاح'), backgroundColor: Colors.green),
                  );
                }
              } else {
                final ok = await ApiService.updateTeacher(
                  teacher.id,
                  fullName: nameController.text.trim(),
                  address: addressController.text.trim(),
                  contact: contactController.text.trim(),
                );
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (ok) {
                  _loadTeachers();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث بيانات المعلم بنجاح'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: Text(teacher == null ? 'إضافة' : 'حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  void _toggleTeacherStatus(Teacher t) async {
    final actionText = t.isActive ? 'تعطيل' : 'تنشيط';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد $actionText حساب المعلم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت أؤكد من $actionText حساب المعلم (${t.fullName})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.isActive ? Colors.red : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.toggleTeacherActive(t.id);
      if (ok) {
        _loadTeachers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $actionText حساب المعلم بنجاح'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المعلمين والمحفظين'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditTeacherModal(),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text('إضافة معلم جديد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: _teachers.length,
              itemBuilder: (ctx, index) {
                final t = _teachers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: Icon(Icons.record_voice_over, color: Colors.white),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(t.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: t.isActive ? Colors.green : Colors.red),
                          ),
                          child: Text(
                            t.isActive ? 'نشط' : 'معطّل',
                            style: TextStyle(fontSize: 10, color: t.isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('الهاتف: ${t.contact ?? "-"} | العنوان: ${t.address ?? "-"}', style: AppTheme.cairoStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddEditTeacherModal(t),
                        ),
                        IconButton(
                          icon: Icon(t.isActive ? Icons.block : Icons.check_circle, color: t.isActive ? Colors.orange : Colors.green),
                          tooltip: t.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                          onPressed: () => _toggleTeacherStatus(t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          tooltip: 'حذف نهائي من النظام',
                          onPressed: () => _confirmHardDeleteTeacher(t),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmHardDeleteTeacher(Teacher t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحذير: حذف نهائي للمعلم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت مؤكد من رغبتك في حذف المعلم (${t.fullName}) نهائياً وكلياً من المنظومة؟ لا يمكن التراجع عن هذا الإجراء.', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.hardDeleteTeacher(t.id);
      if (ok) {
        _loadTeachers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المعلم نهائياً وتسجيل الإجراء في الرقابة الأمنية'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
