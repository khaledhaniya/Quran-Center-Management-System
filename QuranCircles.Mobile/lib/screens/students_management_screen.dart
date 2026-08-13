import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'student_360_screen.dart';

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  List<Circle> _circles = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final list = await ApiService.getStudents();
      final cList = await ApiService.getCircles();
      if (mounted) {
        setState(() {
          _students = list;
          _filteredStudents = list;
          _circles = cList;
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

  void _filter(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredStudents = _students);
    } else {
      final q = query.trim().toLowerCase();
      setState(() {
        _filteredStudents = _students.where((s) {
          final nameMatch = s.fullName.toLowerCase().contains(q);
          final circleMatch = (s.circleName ?? '').toLowerCase().contains(q);
          return nameMatch || circleMatch;
        }).toList();
      });
    }
  }

  void _showAddEditStudentModal([Student? student]) {
    final nameController = TextEditingController(text: student?.fullName ?? '');
    final identityController = TextEditingController(text: student?.studentIdentityNumber ?? '');
    final dobController = TextEditingController(text: student?.dateOfBirth ?? '');
    final parentIdentityController = TextEditingController(text: student?.parentIdentityNumber ?? '');
    final addressController = TextEditingController(text: student?.address ?? '');
    final currentAddressController = TextEditingController(text: student?.currentAddress ?? '');
    final contactController = TextEditingController(text: student?.familyContact ?? '');
    final studentMobileController = TextEditingController(text: student?.studentMobile ?? '');
    final studentWhatsappController = TextEditingController(text: student?.studentWhatsapp ?? '');
    final healthStatusController = TextEditingController(text: student?.healthStatus ?? '');
    final kinshipController = TextEditingController(text: student?.kinship ?? 'أب');
    final notesController = TextEditingController(text: student?.notes ?? '');
    String fatherStatus = student?.fatherStatus ?? 'سليم';
    String motherStatus = student?.motherStatus ?? 'سليم';
    int? selectedCircleId = student?.circleId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(student == null ? 'إضافة طالب جديد' : 'تعديل بيانات الطالب الفنية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الرباعي للطالب *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: identityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'رقم هوية الطالب'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: parentIdentityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'رقم هوية ولي الأمر'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dobController,
                        decoration: const InputDecoration(labelText: 'تاريخ الميلاد (YYYY-MM-DD)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: kinshipController,
                        decoration: const InputDecoration(labelText: 'صلة القرابة (أب/أم)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'العنوان الأصلي'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: currentAddressController,
                        decoration: const InputDecoration(labelText: 'السكن الحالي'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'هاتف العائلة الرئيسي *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: studentMobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'جوال الطالب الشخصي'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: studentWhatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الواتساب للتواصل والتعاميم'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: ['سليم', 'شهيد', 'متوفي', 'أسير'].contains(fatherStatus) ? fatherStatus : 'سليم',
                        decoration: const InputDecoration(labelText: 'حالة الأب'),
                        items: const [
                          DropdownMenuItem(value: 'سليم', child: Text('سليم (حي)')),
                          DropdownMenuItem(value: 'شهيد', child: Text('شهيد')),
                          DropdownMenuItem(value: 'متوفي', child: Text('متوفي')),
                          DropdownMenuItem(value: 'أسير', child: Text('أسير')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => fatherStatus = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: ['سليم', 'شهيدة', 'متوفاة'].contains(motherStatus) ? motherStatus : 'سليم',
                        decoration: const InputDecoration(labelText: 'حالة الأم'),
                        items: const [
                          DropdownMenuItem(value: 'سليم', child: Text('سليمة (حية)')),
                          DropdownMenuItem(value: 'شهيدة', child: Text('شهيدة')),
                          DropdownMenuItem(value: 'متوفاة', child: Text('متوفاة')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => motherStatus = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: selectedCircleId,
                  decoration: const InputDecoration(labelText: 'الحلقة القرآنية المسندة'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('بدون حلقة (غير مسند)')),
                    ..._circles.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setModalState(() => selectedCircleId = val),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: healthStatusController,
                  decoration: const InputDecoration(labelText: 'الحالة الصحية / الملاحظات الطبية'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظات كفالة الأيتام والوضع العام'),
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

                final payload = {
                  'fullName': nameController.text.trim(),
                  'studentIdentityNumber': identityController.text.trim(),
                  'parentIdentityNumber': parentIdentityController.text.trim(),
                  'dateOfBirth': dobController.text.trim(),
                  'address': addressController.text.trim(),
                  'currentAddress': currentAddressController.text.trim(),
                  'familyContact': contactController.text.trim(),
                  'studentMobile': studentMobileController.text.trim(),
                  'studentWhatsapp': studentWhatsappController.text.trim(),
                  'healthStatus': healthStatusController.text.trim(),
                  'kinship': kinshipController.text.trim(),
                  'fatherStatus': fatherStatus,
                  'motherStatus': motherStatus,
                  'circleId': selectedCircleId,
                  'notes': notesController.text.trim(),
                };

                if (student == null) {
                  final ok = await ApiService.createStudent(payload);
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadData();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة الطالب بنجاح'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  final ok = await ApiService.updateStudent(student.id, payload);
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadData();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث كافة بيانات الطالب بنجاح'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: Text(student == null ? 'إضافة' : 'حفظ التعديل الشامل'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStudentStatus(Student s) async {
    final actionText = s.isActive ? 'تعطيل' : 'تنشيط';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد $actionText حساب الطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت أؤكد من $actionText حساب الطالب (${s.fullName})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: s.isActive ? Colors.red : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.toggleStudentActive(s.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $actionText حساب الطالب بنجاح'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _confirmHardDelete(Student s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحذير: حذف نهائي للطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت أيد مؤكد من رغبتك في حذف الطالب (${s.fullName}) نهائياً وكلياً من الداتابيز؟ لا يمكن التراجع عن هذا الإجراء.', style: AppTheme.cairoStyle()),
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
      final ok = await ApiService.hardDeleteStudent(s.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الطالب نهائياً وتسجيل الإجراء في الرقابة الأمنية'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلاب والشعب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث القائمة',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditStudentModal(),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text('إضافة طالب جديد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _loadData();
              },
              child: Column(
                children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    decoration: const InputDecoration(
                      labelText: 'ابحث باسم الطالب أو الحلقة...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredStudents.isEmpty
                      ? Center(child: Text('لا يوجد طلاب مطبقون لشروط البحث', style: AppTheme.cairoStyle()))
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (ctx, index) {
                            final s = _filteredStudents[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AppTheme.primary,
                                          child: Text(
                                            s.fullName.isNotEmpty ? s.fullName[0] : 'ط',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.fullName,
                                                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'الحلقة: ${s.circleName ?? "غير مسند حلقة"} | هوية: ${s.studentIdentityNumber ?? "-"}',
                                                style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: s.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: s.isActive ? Colors.green : Colors.red),
                                          ),
                                          child: Text(
                                            s.isActive ? 'نشط' : 'معطّل',
                                            style: TextStyle(fontSize: 10, color: s.isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (ctx) => Student360Screen(initialStudentId: s.id),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility, color: AppTheme.primary, size: 16),
                                          label: Text('عرض 360°', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'تعديل البيانات',
                                          onPressed: () => _showAddEditStudentModal(s),
                                        ),
                                        IconButton(
                                          icon: Icon(s.isActive ? Icons.block : Icons.check_circle, color: s.isActive ? Colors.orange : Colors.green, size: 20),
                                          tooltip: s.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                                          onPressed: () => _toggleStudentStatus(s),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                          tooltip: 'حذف نهائي من النظام',
                                          onPressed: () => _confirmHardDelete(s),
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
          ),
    );
  }
}
