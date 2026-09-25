import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/contact_helper.dart';

class MemorizationForumScreen extends StatefulWidget {
  const MemorizationForumScreen({super.key});

  @override
  State<MemorizationForumScreen> createState() => _MemorizationForumScreenState();
}

class _MemorizationForumScreenState extends State<MemorizationForumScreen> {
  bool _isLoading = true;
  List<dynamic> _members = [];
  Map<String, dynamic> _stats = {};
  List<Teacher> _supervisors = [];
  List<Teacher> _allTeachers = [];
  List<Student> _allStudents = [];

  String _currentFilter = 'all'; // 'all', 'khatim', 'teachers', 'students', 'external'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getHuffaz(filter: _currentFilter);
      final supervisors = await ApiService.getHuffazSupervisors();
      final teachers = await ApiService.getTeachers();
      final students = await ApiService.getStudents();

      if (mounted) {
        setState(() {
          _members = res['members'] as List? ?? res['Members'] as List? ?? [];
          _stats = res['stats'] as Map<String, dynamic>? ?? res['Stats'] as Map<String, dynamic>? ?? {};
          _supervisors = supervisors;
          _allTeachers = teachers;
          _allStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات منتدى الحفاظ: $e')),
        );
      }
    }
  }

  List<dynamic> get _filteredMembers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _members;

    return _members.where((m) {
      final name = (m['fullName'] ?? m['FullName'] ?? '').toString().toLowerCase();
      final phone = (m['phoneNumber'] ?? m['PhoneNumber'] ?? '').toString();
      final circle = (m['circleName'] ?? m['CircleName'] ?? '').toString().toLowerCase();
      final idNum = (m['identityNumber'] ?? m['IdentityNumber'] ?? '').toString();
      return name.contains(q) || phone.contains(q) || circle.contains(q) || idNum.contains(q);
    }).toList();
  }

  void _showAddEditModal([Map<String, dynamic>? member]) {
    final isEdit = member != null;
    final id = isEdit ? (member['id'] ?? member['Id']) : null;

    String memberType = isEdit ? (member['memberType'] ?? member['MemberType'] ?? 'Student') : 'Student';
    int? selectedTeacherId = isEdit ? (member['teacherId'] ?? member['TeacherId']) : null;
    int? selectedStudentId = isEdit ? (member['studentId'] ?? member['StudentId']) : null;
    int? selectedSupervisorId = isEdit ? (member['supervisorTeacherId'] ?? member['SupervisorTeacherId']) : null;

    final nameCtrl = TextEditingController(text: isEdit ? (member['fullName'] ?? member['FullName'] ?? '') : '');
    final phoneCtrl = TextEditingController(text: isEdit ? (member['phoneNumber'] ?? member['PhoneNumber'] ?? '') : '');
    final idCtrl = TextEditingController(text: isEdit ? (member['identityNumber'] ?? member['IdentityNumber'] ?? '') : '');
    final ajzaaCtrl = TextEditingController(text: isEdit ? (member['memorizedAjzaaCount'] ?? member['MemorizedAjzaaCount'] ?? '30').toString() : '30');
    final riwayahCtrl = TextEditingController(text: isEdit ? (member['riwayah'] ?? member['Riwayah'] ?? 'حفص عن عاصم') : 'حفص عن عاصم');
    final planCtrl = TextEditingController(text: isEdit ? (member['revisionPlan'] ?? member['RevisionPlan'] ?? '') : '');
    final notesCtrl = TextEditingController(text: isEdit ? (member['notes'] ?? member['Notes'] ?? '') : '');

    bool isKhatim = isEdit ? (member['isKhatim'] ?? member['IsKhatim'] ?? true) : true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          title: Row(
            children: [
              Icon(isEdit ? Icons.edit_note : Icons.person_add_alt_1, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'تعديل بيانات الحافظ' : 'إضافة عضو لمنتدى الحفاظ',
                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Member Type Selector
                  Text('فئة العضو في المنتدى:', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: memberType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Student', child: Text('طالب بالمركز 🎓', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Teacher', child: Text('معلم / محفظ بالمركز 👨‍🏫', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'External', child: Text('حافظ من خارج المركز 🌐', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => memberType = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Link to Student
                  if (memberType == 'Student') ...[
                    Text('اختر الطالب من قاعدة البيانات:', style: AppTheme.cairoStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int?>(
                      value: selectedStudentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      hint: const Text('اختر الطالب...'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— إدخال يدوي بدون ربط —')),
                        ..._allStudents.map((s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text('${s.fullName} (${s.circleName ?? "بدون حلقة"})', maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedStudentId = val;
                          if (val != null) {
                            final s = _allStudents.firstWhere((x) => x.id == val);
                            nameCtrl.text = s.fullName;
                            if (s.studentMobile != null) phoneCtrl.text = s.studentMobile!;
                            if (s.studentIdentityNumber != null) idCtrl.text = s.studentIdentityNumber!;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Link to Teacher
                  if (memberType == 'Teacher') ...[
                    Text('اختر المعلم من الكادر:', style: AppTheme.cairoStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int?>(
                      value: selectedTeacherId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      hint: const Text('اختر المعلم...'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— إدخال يدوي بدون ربط —')),
                        ..._allTeachers.map((t) => DropdownMenuItem<int?>(
                              value: t.id,
                              child: Text(t.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedTeacherId = val;
                          if (val != null) {
                            final t = _allTeachers.firstWhere((x) => x.id == val);
                            nameCtrl.text = t.fullName;
                            if (t.contact != null) phoneCtrl.text = t.contact!;
                            if (t.identityNumber != null) idCtrl.text = t.identityNumber!;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Full Name & Identity Number
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم الرباعي الكامل *', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم الهاتف / الواتساب', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: idCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'رقم الهوية', prefixIcon: Icon(Icons.badge_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ajzaa Count & Khatim Toggle
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ajzaaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'عدد الأجزاء المحفوظة (1-30)', prefixIcon: Icon(Icons.menu_book)),
                          onChanged: (val) {
                            final count = int.tryParse(val) ?? 0;
                            if (count >= 30) {
                              setDialogState(() => isKhatim = true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('خاتم للقرآن 🏆', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          value: isKhatim,
                          onChanged: (val) => setDialogState(() => isKhatim = val ?? false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Riwayah & Supervisor Teacher
                  TextField(
                    controller: riwayahCtrl,
                    decoration: const InputDecoration(labelText: 'الرواية المقروء بها', prefixIcon: Icon(Icons.auto_stories)),
                  ),
                  const SizedBox(height: 10),

                  Text('المشرف المتابع من الكادر:', style: AppTheme.cairoStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    value: selectedSupervisorId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    hint: const Text('اختر المشرف المتابع...'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— غير معين —')),
                      ..._supervisors.map((s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) => setDialogState(() => selectedSupervisorId = val),
                  ),
                  const SizedBox(height: 10),

                  // Revision Plan & Notes
                  TextField(
                    controller: planCtrl,
                    decoration: const InputDecoration(
                      labelText: 'خطة المراجعة والتثبيت',
                      hintText: 'مثال: جزئين يومياً مع سرد شهري',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظات إضافية', prefixIcon: Icon(Icons.note_alt_outlined)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة الحافظ'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الحافظ الكامل')),
                  );
                  return;
                }

                final payload = {
                  'memberType': memberType,
                  'teacherId': memberType == 'Teacher' ? selectedTeacherId : null,
                  'studentId': memberType == 'Student' ? selectedStudentId : null,
                  'fullName': name,
                  'phoneNumber': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                  'identityNumber': idCtrl.text.trim().isNotEmpty ? idCtrl.text.trim() : null,
                  'memorizedAjzaaCount': int.tryParse(ajzaaCtrl.text.trim()) ?? 30,
                  'isKhatim': isKhatim,
                  'riwayah': riwayahCtrl.text.trim(),
                  'supervisorTeacherId': selectedSupervisorId,
                  'revisionPlan': planCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                };

                final ok = await ApiService.saveHuffazMember(payload, id: id);
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (!mounted) return;

                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'تم تحديث بيانات الحافظ بنجاح' : 'تمت إضافة الحافظ بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حدث خطأ أثناء حفظ البيانات'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMember(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text('حذف من المنتدى', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الحافظ "$name" من سجلات منتدى الحفاظ؟', style: AppTheme.cairoStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await ApiService.deleteHuffazMember(id);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الحافظ بنجاح'), backgroundColor: Colors.green),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في حذف الحافظ'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(val, style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppTheme.cairoStyle(fontSize: 10, color: Colors.grey.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, IconData icon) {
    final isSelected = _currentFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade700),
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
        ),
        labelStyle: AppTheme.cairoStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.black87,
        ),
        onSelected: (_) {
          setState(() => _currentFilter = key);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (_stats['totalMembers'] ?? _stats['TotalMembers'] ?? _members.length).toString();
    final khatims = (_stats['khatimsCount'] ?? _stats['KhatimsCount'] ?? 0).toString();
    final plus20 = (_stats['plus20Count'] ?? _stats['Plus20Count'] ?? 0).toString();
    final teachers = (_stats['teachersCount'] ?? _stats['TeachersCount'] ?? 0).toString();

    final filtered = _filteredMembers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'شؤون التحفيظ ومنتدى الحفاظ',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('إضافة حافظ', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditModal(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Stats Ribbon
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: Row(
                        children: [
                          _buildStatCard('إجمالي الحفاظ', total, Icons.auto_stories, AppTheme.primary),
                          const SizedBox(width: 8),
                          _buildStatCard('الخاتمون 🏆', khatims, Icons.workspace_premium, Colors.amber.shade800),
                          const SizedBox(width: 8),
                          _buildStatCard('+20 جزءاً', plus20, Icons.menu_book, Colors.teal),
                          const SizedBox(width: 8),
                          _buildStatCard('معلمون حفاظ', teachers, Icons.school, Colors.blue),
                        ],
                      ),
                    ),
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'بحث باسم الحافظ، الهاتف، الحلقة، الرواية...',
                          hintStyle: AppTheme.cairoStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                    ),
                  ),

                  // Filter Chips
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        children: [
                          _buildFilterChip('الكل', 'all', Icons.grid_view),
                          _buildFilterChip('الخاتمون 🏆', 'khatim', Icons.star),
                          _buildFilterChip('معلمون', 'teachers', Icons.school),
                          _buildFilterChip('طلاب المركز', 'students', Icons.person),
                          _buildFilterChip('خارجيون', 'external', Icons.public),
                        ],
                      ),
                    ),
                  ),

                  // Members List
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'لا يوجد حفاظ مطابقون لمعايير البحث والفلترة',
                          style: AppTheme.cairoStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final m = filtered[index];
                            final id = m['id'] ?? m['Id'] ?? 0;
                            final name = m['fullName'] ?? m['FullName'] ?? 'حافظ';
                            final type = m['memberType'] ?? m['MemberType'] ?? 'Student';
                            final ajzaa = m['memorizedAjzaaCount'] ?? m['MemorizedAjzaaCount'] ?? 0;
                            final isKhatim = (m['isKhatim'] ?? m['IsKhatim'] ?? false) || ajzaa >= 30;
                            final riwayah = m['riwayah'] ?? m['Riwayah'] ?? 'حفص عن عاصم';
                            final supervisor = m['supervisorTeacherName'] ?? m['SupervisorTeacherName'] ?? 'غير معين';
                            final phone = (m['phoneNumber'] ?? m['PhoneNumber'] ?? '').toString();
                            final circle = m['circleName'] ?? m['CircleName'] ?? (type == 'Teacher' ? 'كادر المشايخ' : 'خارج المركز');
                            final plan = m['revisionPlan'] ?? m['RevisionPlan'] ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isKhatim ? Colors.amber.shade300 : Colors.grey.shade200,
                                  width: isKhatim ? 1.5 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Avatar + Name + Khatim Crown
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isKhatim ? Colors.amber.shade50 : AppTheme.primaryLight.withValues(alpha: 0.4),
                                          child: Icon(
                                            isKhatim ? Icons.workspace_premium : Icons.auto_stories,
                                            color: isKhatim ? Colors.amber.shade800 : AppTheme.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isKhatim)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.shade100,
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: Colors.amber.shade400),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.star, size: 12, color: Colors.amber.shade900),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            'خاتم القرآن',
                                                            style: AppTheme.cairoStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.amber.shade900,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Text(
                                                'الحلقة / الفئة: $circle',
                                                style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16, thickness: 0.6),

                                    // Row 2: Badges
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        // Ajzaa Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.teal.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.menu_book, size: 13, color: Colors.teal.shade800),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$ajzaa / 30 جزءاً',
                                                style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Riwayah Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.indigo.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.auto_stories, size: 13, color: Colors.indigo.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                riwayah,
                                                style: AppTheme.cairoStyle(fontSize: 11, color: Colors.indigo.shade800),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Supervisor Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.purple.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.supervisor_account, size: 13, color: Colors.purple.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'المشرف: $supervisor',
                                                style: AppTheme.cairoStyle(fontSize: 11, color: Colors.purple.shade800),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Revision Plan text if exists
                                    if (plan.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 13, color: Colors.brown),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'خطة التثبيت: $plan',
                                                style: AppTheme.cairoStyle(fontSize: 11, color: Colors.brown.shade800),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 10),

                                    // Row 3: Action Buttons (Phone, WhatsApp, Edit, Delete)
                                    Row(
                                      children: [
                                        if (phone.isNotEmpty) ...[
                                          IconButton.filledTonal(
                                            icon: const Icon(Icons.phone_in_talk, size: 16),
                                            color: Colors.blue.shade700,
                                            onPressed: () => ContactHelper.launchDialer(context, phone),
                                            tooltip: 'اتصال',
                                            style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton.filledTonal(
                                            icon: const Icon(Icons.chat, size: 16),
                                            color: Colors.green.shade700,
                                            onPressed: () => ContactHelper.launchWhatsApp(context, phone),
                                            tooltip: 'مراسلة واتساب',
                                            style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
                                          ),
                                        ],
                                        const Spacer(),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.edit_note, size: 15),
                                          label: Text('تعديل', style: AppTheme.cairoStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () => _showAddEditModal(m),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          onPressed: () => _deleteMember(id, name),
                                          tooltip: 'حذف',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
