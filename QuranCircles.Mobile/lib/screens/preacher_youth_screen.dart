import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PreacherYouthScreen extends StatefulWidget {
  const PreacherYouthScreen({super.key});

  @override
  State<PreacherYouthScreen> createState() => _PreacherYouthScreenState();
}

class _PreacherYouthScreenState extends State<PreacherYouthScreen> {
  bool _isLoading = true;
  List<TalentRecord> _talents = [];
  List<Student> _allStudents = [];
  List<Teacher> _allTeachers = [];

  String _currentFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final talents = await ApiService.getTalents(
        talentType: _currentFilter == 'ALL' ? null : _currentFilter,
      );
      final students = await ApiService.getStudents();
      final teachers = await ApiService.getTeachers();

      if (mounted) {
        setState(() {
          _talents = talents;
          _allStudents = students;
          _allTeachers = teachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل سجلات برنامج الفتى الواعظ: $e')),
        );
      }
    }
  }

  List<TalentRecord> get _filteredTalents {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _talents;

    return _talents.where((t) {
      final name = t.studentName.toLowerCase();
      final title = t.title.toLowerCase();
      final occasion = (t.occasion ?? '').toLowerCase();
      final teacher = (t.supervisorTeacherName ?? '').toLowerCase();
      final circle = (t.circleName ?? '').toLowerCase();
      return name.contains(q) || title.contains(q) || occasion.contains(q) || teacher.contains(q) || circle.contains(q);
    }).toList();
  }

  Color _getTalentColor(String type) {
    if (type.contains('خطابة') || type.contains('واعظ')) return const Color(0xFFD97706);
    if (type.contains('أصوات') || type.contains('تلاوة')) return const Color(0xFF0D9488);
    if (type.contains('أذان') || type.contains('ابتهال')) return const Color(0xFF4F46E5);
    if (type.contains('شعر') || type.contains('إلقاء')) return const Color(0xFFE11D48);
    return AppTheme.primary;
  }

  IconData _getTalentIcon(String type) {
    if (type.contains('خطابة') || type.contains('واعظ')) return Icons.record_voice_over;
    if (type.contains('أصوات') || type.contains('تلاوة')) return Icons.auto_stories;
    if (type.contains('أذان') || type.contains('ابتهال')) return Icons.volume_up;
    if (type.contains('شعر') || type.contains('إلقاء')) return Icons.history_edu;
    return Icons.star_border;
  }

  void _showAddEditModal([TalentRecord? record]) {
    final isEdit = record != null;
    int selectedStudentId = record?.studentId ?? (_allStudents.isNotEmpty ? _allStudents.first.id : 0);
    String selectedType = record?.talentType ?? 'الخطابة والوعظ (الفتى الواعظ)';
    int? selectedTeacherId = record?.supervisorTeacherId;

    final titleCtrl = TextEditingController(text: record?.title ?? '');
    final prepCtrl = TextEditingController(text: record?.preparationMethod ?? 'حفظ وتدريب مع المحفظ');
    final contentCtrl = TextEditingController(text: record?.speechContent ?? '');
    final occasionCtrl = TextEditingController(text: record?.occasion ?? 'خطبة الجمعة في المسجد');
    final dateCtrl = TextEditingController(text: record?.eventDate ?? DateTime.now().toString().split(' ')[0]);
    final scoreCtrl = TextEditingController(text: record?.evaluationScore ?? 'ممتاز (95%)');
    final notesCtrl = TextEditingController(text: record?.performanceNotes ?? '');
    final mediaCtrl = TextEditingController(text: record?.mediaUrl ?? '');

    final talentTypes = [
      'الخطابة والوعظ (الفتى الواعظ)',
      'الأصوات الندية والتلاوة القرآنية',
      'الأذان والابتهالات الدينية',
      'الشعر والإلقاء الأدبي',
      'مهارات دعوية أخرى',
    ];

    if (!talentTypes.contains(selectedType)) {
      talentTypes.insert(0, selectedType);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          title: Row(
            children: [
              Icon(isEdit ? Icons.edit_note : Icons.add_circle_outline, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'تعديل مشاركة موهبة' : 'تسجيل مشاركة موهبة جديدة',
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
                  // Student Selector
                  Text('اختر الطالب المشارك *:', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: selectedStudentId > 0 ? selectedStudentId : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    hint: const Text('اختر الطالب...'),
                    items: _allStudents.map((s) {
                      return DropdownMenuItem<int>(
                        value: s.id,
                        child: Text('${s.fullName} (${s.circleName ?? "بدون حلقة"})', maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedStudentId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Talent Type Selector
                  Text('مسار الموهبة *:', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: talentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Title of Speech or Recitation
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان المشاركة / موضوع الخطبة / السورة *',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Occasion & Date
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: occasionCtrl,
                          decoration: const InputDecoration(labelText: 'المناسبة / المسجد', prefixIcon: Icon(Icons.place_outlined)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: dateCtrl,
                          decoration: const InputDecoration(labelText: 'تاريخ الإلقاء (YYYY-MM-DD)', prefixIcon: Icon(Icons.calendar_today)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Supervisor Teacher
                  Text('المشرف المتابع / المدرب:', style: AppTheme.cairoStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    value: selectedTeacherId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    hint: const Text('اختر المشرف المدرب...'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— بدون مشرف محدد —')),
                      ..._allTeachers.map((t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.fullName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setDialogState(() => selectedTeacherId = val),
                  ),
                  const SizedBox(height: 10),

                  // Score & Prep Method
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: scoreCtrl,
                          decoration: const InputDecoration(labelText: 'التقييم والدرجة', prefixIcon: Icon(Icons.star_outline)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: prepCtrl,
                          decoration: const InputDecoration(labelText: 'طريقة الإعداد والتدريب', prefixIcon: Icon(Icons.psychology_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Media URL / Audio link
                  TextField(
                    controller: mediaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط تسجيل صوتي أو مرئي (اختياري)',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظات وتوصيات لجنة التحكيم', prefixIcon: Icon(Icons.note_alt_outlined)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(isEdit ? 'حفظ التعديلات' : 'تسجيل المشاركة'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedStudentId <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الطالب المشارك')),
                  );
                  return;
                }
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال عنوان المشاركة أو الخطبة')),
                  );
                  return;
                }

                final payload = {
                  'studentId': selectedStudentId,
                  'talentType': selectedType,
                  'title': titleCtrl.text.trim(),
                  'preparationMethod': prepCtrl.text.trim(),
                  'speechContent': contentCtrl.text.trim(),
                  'occasion': occasionCtrl.text.trim(),
                  'eventDate': dateCtrl.text.trim(),
                  'supervisorTeacherId': selectedTeacherId,
                  'evaluationScore': scoreCtrl.text.trim(),
                  'performanceNotes': notesCtrl.text.trim(),
                  'mediaUrl': mediaCtrl.text.trim().isNotEmpty ? mediaCtrl.text.trim() : null,
                };

                final ok = await ApiService.saveTalent(payload, id: record?.id);
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (!mounted) return;

                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'تم تحديث المشاركة بنجاح' : 'تم تسجيل مشاركة الطالب بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حدث خطأ أثناء حفظ المشاركة'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTalent(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text('حذف المشاركة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('هل أنت متأكد من حذف مشاركة "$title"؟', style: AppTheme.cairoStyle(fontSize: 13)),
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

    final ok = await ApiService.deleteTalent(id);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المشاركة بنجاح'), backgroundColor: Colors.green),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في حذف المشاركة'), backgroundColor: Colors.red),
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
              style: AppTheme.cairoStyle(fontSize: 9.5, color: Colors.grey.shade700),
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
    final totalCount = _talents.length;
    final preacherCount = _talents.where((t) => t.talentType.contains('خطابة') || t.talentType.contains('واعظ')).length;
    final recitationCount = _talents.where((t) => t.talentType.contains('أصوات') || t.talentType.contains('تلاوة')).length;
    final azanCount = _talents.where((t) => t.talentType.contains('أذان') || t.talentType.contains('ابتهال')).length;

    final filtered = _filteredTalents;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'برنامج الفتى الواعظ والأصوات الندية',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('تسجيل مشاركة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
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
                          _buildStatCard('إجمالي المشاركات', totalCount.toString(), Icons.campaign, AppTheme.primary),
                          const SizedBox(width: 8),
                          _buildStatCard('الفتى الواعظ 🎙️', preacherCount.toString(), Icons.record_voice_over, const Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          _buildStatCard('أصوات ندية 📖', recitationCount.toString(), Icons.auto_stories, const Color(0xFF0D9488)),
                          const SizedBox(width: 8),
                          _buildStatCard('الأذان والابتهال 🕌', azanCount.toString(), Icons.volume_up, const Color(0xFF4F46E5)),
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
                          hintText: 'بحث باسم الطالب، موضوع الخطبة، المناسبة، المشرف...',
                          hintStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade500),
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

                  // Filters
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        children: [
                          _buildFilterChip('الكل', 'ALL', Icons.grid_view),
                          _buildFilterChip('الخطابة والوعظ 🎙️', 'الخطابة', Icons.record_voice_over),
                          _buildFilterChip('الأصوات الندية 📖', 'الأصوات', Icons.auto_stories),
                          _buildFilterChip('الأذان والابتهال 🕌', 'الأذان', Icons.volume_up),
                          _buildFilterChip('الشعر والإلقاء 📜', 'الشعر', Icons.history_edu),
                        ],
                      ),
                    ),
                  ),

                  // Talents List
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'لا توجد مشاركات مسجلة مطابقة للبحث أو الفلتر',
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
                            final t = filtered[index];
                            final color = _getTalentColor(t.talentType);
                            final icon = _getTalentIcon(t.talentType);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Student Name + Type Badge
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: color.withValues(alpha: 0.12),
                                          child: Icon(icon, color: color, size: 20),
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
                                                      t.studentName,
                                                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (t.evaluationScore != null && t.evaluationScore!.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.shade50,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.amber.shade300),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.star, size: 12, color: Colors.amber),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            t.evaluationScore!,
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
                                                'الحلقة: ${t.circleName ?? "غير مسند"} | المناسبة: ${t.occasion ?? "محفل قرآني"}',
                                                style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16, thickness: 0.6),

                                    // Title Box
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: color.withValues(alpha: 0.15)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.record_voice_over_outlined, size: 16, color: color),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              t.title,
                                              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Tags & Details
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        // Talent Type Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            t.talentType,
                                            style: AppTheme.cairoStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold),
                                          ),
                                        ),

                                        // Date Tag
                                        if (t.eventDate != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.event, size: 12, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  t.eventDate!,
                                                  style: AppTheme.cairoStyle(fontSize: 10.5, color: Colors.grey.shade800),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Supervisor Teacher Tag
                                        if (t.supervisorTeacherName != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.school, size: 12, color: Colors.purple),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'المشرف: ${t.supervisorTeacherName}',
                                                  style: AppTheme.cairoStyle(fontSize: 10.5, color: Colors.purple.shade800),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Performance Notes if any
                                    if (t.performanceNotes != null && t.performanceNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'ملاحظات الأداء: ${t.performanceNotes}',
                                        style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                      ),
                                    ],

                                    const SizedBox(height: 10),

                                    // Actions Row (Media Link, Edit, Delete)
                                    Row(
                                      children: [
                                        if (t.mediaUrl != null && t.mediaUrl!.isNotEmpty)
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.play_circle_fill, size: 15),
                                            label: Text('فتح التسجيل', style: AppTheme.cairoStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal.shade700,
                                              foregroundColor: Colors.white,
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            ),
                                            onPressed: () async {
                                              final uri = Uri.parse(t.mediaUrl!);
                                              try {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              } catch (_) {}
                                            },
                                          ),
                                        const Spacer(),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.edit_note, size: 15),
                                          label: Text('تعديل', style: AppTheme.cairoStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () => _showAddEditModal(t),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          onPressed: () => _deleteTalent(t.id, t.title),
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
