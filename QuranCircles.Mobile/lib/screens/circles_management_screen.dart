import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CirclesManagementScreen extends StatefulWidget {
  const CirclesManagementScreen({super.key});

  @override
  State<CirclesManagementScreen> createState() => _CirclesManagementScreenState();
}

class _CirclesManagementScreenState extends State<CirclesManagementScreen> {
  List<Circle> _circles = [];
  List<Teacher> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final list = await ApiService.getCircles();
      final tList = await ApiService.getTeachers();
      if (mounted) {
        setState(() {
          _circles = list;
          _teachers = tList;
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

  void _showAddEditCircleModal([Circle? circle]) {
    final nameController = TextEditingController(text: circle?.name ?? '');
    String timing = circle?.timing ?? 'Fajr';
    int? selectedTeacherId = circle?.teacherId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(circle == null ? 'إضافة حلقة جديدة' : 'تعديل بيانات الحلقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الحلقة القرآنية *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: timing,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'موعد ووقت انعقاد الحلقة'),
                  items: const [
                    DropdownMenuItem(value: 'Fajr', child: Text('بعد الفجر', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'Aser', child: Text('بعد العصر', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'Maghrib', child: Text('بعد المغرب', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'Isha', child: Text('بعد العشاء', overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => timing = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedTeacherId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المعلم المحفظ المشرف'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('بدون معلم (غير مسند)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ..._teachers.map((t) => DropdownMenuItem<int>(value: t.id, child: Text(t.fullName, overflow: TextOverflow.ellipsis, maxLines: 1))),
                  ],
                  onChanged: (val) => setModalState(() => selectedTeacherId = val),
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

                if (circle == null) {
                  final ok = await ApiService.createCircle(
                    name: nameController.text.trim(),
                    timing: timing,
                    teacherId: selectedTeacherId,
                  );
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadData();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إنشاء الحلقة بنجاح'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  final ok = await ApiService.updateCircle(
                    circle.id,
                    name: nameController.text.trim(),
                    timing: timing,
                    teacherId: selectedTeacherId,
                  );
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadData();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث بيانات الحلقة بنجاح'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: Text(circle == null ? 'إضافة' : 'حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCircleStatus(Circle c) async {
    final actionText = c.isActive ? 'تعطيل' : 'تنشيط';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد $actionText الحلقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت أؤكد من $actionText الحلقة (${c.name})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: c.isActive ? Colors.red : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.toggleCircleActive(c.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $actionText الحلقة بنجاح'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحلقات القرآنية'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditCircleModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('إضافة حلقة جديدة', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: _circles.length,
              itemBuilder: (ctx, index) {
                final c = _circles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              child: Icon(Icons.groups, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text('المعلم المسؤول: ${c.teacherName ?? "غير مسند"}', style: AppTheme.cairoStyle(fontSize: 13, color: AppTheme.primaryDark)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.isActive ? Colors.green : Colors.red),
                              ),
                              child: Text(
                                c.isActive ? 'نشط' : 'معطّل',
                                style: TextStyle(fontSize: 11, color: c.isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'عدد الطلاب المسجلين بالحلقة: ${c.studentCount}',
                              style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                              onPressed: () => _showCircleStudentsModal(c),
                              icon: const Icon(Icons.people, size: 18),
                              label: Text('عرض وإدارة الطلاب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                              onPressed: () => _showAddEditCircleModal(c),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('تعديل'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: c.isActive ? Colors.orange : Colors.green),
                              onPressed: () => _toggleCircleStatus(c),
                              icon: Icon(c.isActive ? Icons.block : Icons.check_circle, size: 16),
                              label: Text(c.isActive ? 'تعطيل' : 'تفعيل'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () => _confirmHardDeleteCircle(c),
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: const Text('حذف'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showCircleStudentsModal(Circle circle) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CircleStudentsModal(circle: circle, onUpdated: _loadData),
    );
  }

  void _confirmHardDeleteCircle(Circle c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحذير: حذف نهائي للحلقة القرآنية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت مؤكد من رغبتك في حذف الحلقة (${c.name}) نهائياً وكلياً؟ لا يمكن التراجع عن هذا الإجراء.', style: AppTheme.cairoStyle()),
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
      final ok = await ApiService.hardDeleteCircle(c.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحلقة القرآنية نهائياً وتسجيل الإجراء في الرقابة الأمنية'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _CircleStudentsModal extends StatefulWidget {
  final Circle circle;
  final VoidCallback onUpdated;

  const _CircleStudentsModal({required this.circle, required this.onUpdated});

  @override
  State<_CircleStudentsModal> createState() => _CircleStudentsModalState();
}

class _CircleStudentsModalState extends State<_CircleStudentsModal> {
  List<Student> _allStudents = [];
  List<Student> _assignedStudents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _onlyUnassigned = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getStudents();
      setState(() {
        _allStudents = list;
        _assignedStudents = list.where((s) => s.circleId == widget.circle.id).toList();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _assignStudent(Student student) async {
    final ok = await ApiService.updateStudent(student.id, {
      'fullName': student.fullName,
      'address': student.address,
      'familyContact': student.familyContact,
      'circleId': widget.circle.id,
    });
    if (ok) {
      _loadStudents();
      widget.onUpdated();
    }
  }

  void _removeStudent(Student student) async {
    final ok = await ApiService.updateStudent(student.id, {
      'fullName': student.fullName,
      'address': student.address,
      'familyContact': student.familyContact,
      'circleId': null,
    });
    if (ok) {
      _loadStudents();
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    List<Student> available = _allStudents.where((s) => s.circleId != widget.circle.id).toList();
    if (_onlyUnassigned) {
      available = available.where((s) => s.circleId == null).toList();
    }
    if (query.isNotEmpty) {
      available = available.where((s) => 
        s.fullName.toLowerCase().contains(query) ||
        (s.studentIdentityNumber != null && s.studentIdentityNumber!.contains(query)) ||
        (s.circleName != null && s.circleName!.toLowerCase().contains(query))
      ).toList();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: AppTheme.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إدارة وتعيين طلاب: ${widget.circle.name}',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Search & Filter Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add_alt_1, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text('إضافة وتنسيب طلاب جدد (بحث فوري ذكي):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '🔍 ابحث بالاسم الرباعي أو رقم الهوية...',
                      hintStyle: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.green.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text('غير مسندين فقط', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: _onlyUnassigned,
                        selectedColor: Colors.green.shade200,
                        onSelected: (sel) => setState(() => _onlyUnassigned = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('جميع طلاب المركز', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: !_onlyUnassigned,
                        selectedColor: Colors.green.shade200,
                        onSelected: (sel) => setState(() => _onlyUnassigned = false),
                      ),
                    ],
                  ),
                  if (query.isNotEmpty || available.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: available.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('لا يوجد طلاب مطابقين للبحث', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: available.length > 10 ? 10 : available.length,
                              itemBuilder: (ctx, i) {
                                final st = available[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(st.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  subtitle: Text(st.circleName != null ? 'حلقة: ${st.circleName}' : 'غير مسند لحلقة', style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  trailing: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: Text('تنسيب', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      _assignStudent(st);
                                      _searchController.clear();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'الطلاب المسجلون حالياً بالحلقة (${_assignedStudents.length}):',
              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryDark),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _assignedStudents.isEmpty
                      ? Center(
                          child: Text('لا يوجد طلاب مسجلون بالحلقة حالياً', style: AppTheme.cairoStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: _assignedStudents.length,
                          itemBuilder: (ctx, index) {
                            final s = _assignedStudents[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primaryLight,
                                  child: Icon(Icons.person, size: 18, color: AppTheme.primary),
                                ),
                                title: Text(s.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('التواصل: ${s.familyContact ?? "-"} | الهوية: ${s.studentIdentityNumber ?? "-"}', style: AppTheme.cairoStyle(fontSize: 11)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  tooltip: 'إزالة من الحلقة',
                                  onPressed: () => _removeStudent(s),
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
