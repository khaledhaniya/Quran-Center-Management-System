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
  List<Circle> _filteredCircles = [];
  List<Teacher> _teachers = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedTiming = 'ALL'; // 'ALL', 'Fajr', 'Aser', 'Maghrib', 'Isha'
  String _selectedStatus = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getCircles(forceRefresh: true);
      final tList = await ApiService.getTeachers(forceRefresh: true);
      if (mounted) {
        setState(() {
          _circles = list;
          _teachers = tList;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredCircles = _circles.where((c) {
        // Search query
        if (query.isNotEmpty) {
          final matches = c.name.toLowerCase().contains(query) ||
              (c.teacherName != null && c.teacherName!.toLowerCase().contains(query)) ||
              (c.assistantTeacherName != null && c.assistantTeacherName!.toLowerCase().contains(query));
          if (!matches) return false;
        }

        // Timing filter
        if (_selectedTiming != 'ALL') {
          if (c.timing != _selectedTiming) return false;
        }

        // Status filter
        if (_selectedStatus == 'ACTIVE' && !c.isActive) return false;
        if (_selectedStatus == 'INACTIVE' && c.isActive) return false;

        return true;
      }).toList();
    });
  }

  String _getTimingDisplayName(String? timing) {
    switch (timing) {
      case 'Fajr':
        return 'بعد الفجر';
      case 'Aser':
        return 'بعد العصر';
      case 'Maghrib':
        return 'بعد المغرب';
      case 'Isha':
        return 'بعد العشاء';
      default:
        return timing ?? 'غير محدد';
    }
  }

  Color _getTimingColor(String? timing) {
    switch (timing) {
      case 'Fajr':
        return Colors.amber.shade800;
      case 'Aser':
        return Colors.orange.shade700;
      case 'Maghrib':
        return Colors.purple.shade700;
      case 'Isha':
        return Colors.indigo.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getTimingIcon(String? timing) {
    switch (timing) {
      case 'Fajr':
        return Icons.wb_twilight;
      case 'Aser':
        return Icons.wb_sunny_outlined;
      case 'Maghrib':
        return Icons.nights_stay_outlined;
      case 'Isha':
        return Icons.bedtime_outlined;
      default:
        return Icons.access_time;
    }
  }

  Widget _buildHeroHeader() {
    final activeCount = _circles.where((c) => c.isActive).length;
    final totalStudents = _circles.fold<int>(0, (sum, c) => sum + c.studentCount);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B26), Color(0xFF134E32), Color(0xFF1E6B45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B26).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle_notifications, size: 13, color: AppTheme.accent),
                    const SizedBox(width: 5),
                    Text(
                      'المنظومة التعليمية',
                      style: AppTheme.cairoStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                tooltip: 'تحديث القائمة',
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.diversity_3, color: AppTheme.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إدارة الحلقات القرآنيّة والمجموعات',
                  style: AppTheme.cairoStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'تنظيم وتوزيع الحلقات، تعيين المشايخ والمعلمين، ومتابعة الطاقة الاستيعابية والجدول الزمني.',
            style: AppTheme.cairoStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Mini Stat Counters
          Row(
            children: [
              _buildMiniCounter('إجمالي الحلقات', '${_circles.length}', Icons.circle_outlined, Colors.white),
              const SizedBox(width: 8),
              _buildMiniCounter('حلقات نشطة', '$activeCount', Icons.check_circle, Colors.greenAccent),
              const SizedBox(width: 8),
              _buildMiniCounter('طلاب الحلقات', '$totalStudents', Icons.groups, AppTheme.accent),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditCircleModal(),
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF0D3B26)),
              label: Text(
                'إضافة حلقة قرآنية جديدة',
                style: AppTheme.cairoStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: const Color(0xFF0D3B26),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF0D3B26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCounter(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(val, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.cairoStyle(fontSize: 9.5, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingFilterChip(String label, String timingKey) {
    final isSelected = _selectedTiming == timingKey;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withValues(alpha: 0.18),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        labelStyle: AppTheme.cairoStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primary : Colors.black87,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedTiming = selected ? timingKey : 'ALL';
          });
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String statusKey, IconData icon) {
    final isSelected = _selectedStatus == statusKey;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        avatar: Icon(icon, size: 14, color: isSelected ? AppTheme.primary : Colors.grey.shade600),
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withValues(alpha: 0.18),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        labelStyle: AppTheme.cairoStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primary : Colors.black87,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? statusKey : 'ALL';
          });
          _applyFilters();
        },
      ),
    );
  }

  void _showAddEditCircleModal([Circle? circle]) {
    final nameController = TextEditingController(text: circle?.name ?? '');
    String timing = circle?.timing ?? 'Fajr';
    int? selectedTeacherId = circle?.teacherId;
    int? selectedAssistantId = circle?.assistantTeacherId;

    final activeTeachers = _teachers.where((t) => t.isActive).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Hero Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D3B26), Color(0xFF134E32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.hub_outlined, color: AppTheme.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                circle == null ? 'إضافة حلقة قرآنية جديدة' : 'تعديل بيانات: ${circle.name}',
                                style: AppTheme.cairoStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'تنظيم الجدول الزمني وتعيين المشايخ والمحفظين للحلقة',
                                style: AppTheme.cairoStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Fields
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circle Name
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الحلقة القرآنية *',
                            hintText: 'مثال: حلقة الفجر النموذجية / حلقة التميز',
                            prefixIcon: Icon(Icons.mosque_outlined, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Timing Dropdown
                        DropdownButtonFormField<String>(
                          value: timing,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'موعد ووقت الانعقاد *',
                            prefixIcon: Icon(Icons.access_time, color: Colors.blue),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Fajr', child: Text('بعد الفجر')),
                            DropdownMenuItem(value: 'Aser', child: Text('بعد العصر')),
                            DropdownMenuItem(value: 'Maghrib', child: Text('بعد المغرب')),
                            DropdownMenuItem(value: 'Isha', child: Text('بعد العشاء')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => timing = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Lead Teacher Dropdown
                        DropdownButtonFormField<int?>(
                          value: selectedTeacherId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'المعلم والمحفّظ المشرف الرئيسي *',
                            prefixIcon: Icon(Icons.person_pin, color: AppTheme.primary),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('-- بدون معلم مشرف --', style: TextStyle(color: Colors.grey)),
                            ),
                            ...activeTeachers.map((t) {
                              final roleStr = (t.taskRole != null && t.taskRole!.trim().isNotEmpty) ? ' (${t.taskRole})' : '';
                              return DropdownMenuItem<int?>(
                                value: t.id,
                                child: Text('${t.fullName}$roleStr', overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }),
                          ],
                          onChanged: (val) => setModalState(() => selectedTeacherId = val),
                        ),
                        const SizedBox(height: 14),

                        // Assistant Teacher Dropdown
                        DropdownButtonFormField<int?>(
                          value: selectedAssistantId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'مساعد الحلقة (المعلم المساعد - اختياري)',
                            prefixIcon: Icon(Icons.handshake_outlined, color: Colors.teal),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('-- بدون معلم مساعد (اختياري) --', style: TextStyle(color: Colors.grey)),
                            ),
                            ...activeTeachers.map((t) {
                              final roleStr = (t.taskRole != null && t.taskRole!.trim().isNotEmpty) ? ' (${t.taskRole})' : '';
                              return DropdownMenuItem<int?>(
                                value: t.id,
                                child: Text('${t.fullName}$roleStr', overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }),
                          ],
                          onChanged: (val) => setModalState(() => selectedAssistantId = val),
                        ),
                      ],
                    ),
                  ),
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
              icon: const Icon(Icons.check, size: 18),
              label: Text(circle == null ? 'إضافة الحلقة' : 'حفظ التعديل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الحلقة القرآنية'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                if (circle == null) {
                  final ok = await ApiService.createCircle(
                    name: name,
                    timing: timing,
                    teacherId: selectedTeacherId,
                    assistantTeacherId: selectedAssistantId,
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
                    name: name,
                    timing: timing,
                    teacherId: selectedTeacherId,
                    assistantTeacherId: selectedAssistantId,
                    isActive: circle.isActive,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(c.isActive ? Icons.block : Icons.check_circle_outline, color: c.isActive ? Colors.orange : Colors.green),
            const SizedBox(width: 8),
            Text('تأكيد $actionText الحلقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('هل أنت متأكد من $actionText الحلقة (${c.name})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.isActive ? Colors.orange.shade800 : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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

  void _confirmHardDeleteCircle(Circle c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('تحذير: حذف نهائي للحلقة القرآنية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Text(
          'هل أنت متأكد تماماً من حذف الحلقة (${c.name}) نهائياً وكلياً؟\nسيتم فك ارتباط طلابها تلقائياً ولا يمكن التراجع.',
          style: AppTheme.cairoStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(fontWeight: FontWeight.bold)),
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
          const SnackBar(content: Text('تم حذف الحلقة القرآنية نهائياً من النظام'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCircleStudentsModal(Circle circle) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CircleStudentsModal(circle: circle, onUpdated: _loadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحلقات القرآنية'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditCircleModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('إضافة حلقة جديدة', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: CustomScrollView(
          slivers: [
            // 1. Hero Header Banner
            SliverToBoxAdapter(child: _buildHeroHeader()),

            // 2. Search & Filter Bar
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الحلقة أو اسم المعلم أو المساعد...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Timing Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildTimingFilterChip('كل الأوقات (${_circles.length})', 'ALL'),
                          _buildTimingFilterChip('بعد الفجر', 'Fajr'),
                          _buildTimingFilterChip('بعد العصر', 'Aser'),
                          _buildTimingFilterChip('بعد المغرب', 'Maghrib'),
                          _buildTimingFilterChip('بعد العشاء', 'Isha'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Status Filter Chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStatusFilterChip('كل الحالات', 'ALL', Icons.all_inclusive),
                          _buildStatusFilterChip('نشطة (${_circles.where((c) => c.isActive).length})', 'ACTIVE', Icons.check_circle_outline),
                          _buildStatusFilterChip('معطّلة (${_circles.where((c) => !c.isActive).length})', 'INACTIVE', Icons.block),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1, thickness: 1)),

            // 3. Circles List or Loading / Empty States
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_filteredCircles.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(50),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد حلقات قرآنية مطابقة للبحث أو الفلتر',
                          style: AppTheme.cairoStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final c = _filteredCircles[index];
                      final timingName = _getTimingDisplayName(c.timing);
                      final timingColor = _getTimingColor(c.timing);
                      final timingIcon = _getTimingIcon(c.timing);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.isActive ? Colors.grey.shade200 : Colors.red.shade100,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Circle Avatar + Name (SINGLE LINE) + Status Pill
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                                    child: Text(
                                      '${index + 1}',
                                      style: AppTheme.cairoStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Circle Name strictly in ONE LINE
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: AppTheme.cairoStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Status Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: c.isActive ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: c.isActive ? Colors.green.shade300 : Colors.red.shade300,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          c.isActive ? Icons.check_circle : Icons.block,
                                          size: 11,
                                          color: c.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          c.isActive ? 'نشطة' : 'معطّلة',
                                          style: AppTheme.cairoStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: c.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Badges Ribbon: Timing + Student Count
                              Row(
                                children: [
                                  // Timing Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: timingColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: timingColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(timingIcon, size: 13, color: timingColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          timingName,
                                          style: AppTheme.cairoStyle(
                                            fontSize: 11,
                                            color: timingColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Student Count Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.groups, size: 13, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${c.studentCount} طلاب مسجلين',
                                          style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Teachers Strip (Lead + Assistant)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    // Lead Teacher
                                    Row(
                                      children: [
                                        const Icon(Icons.person_pin, size: 15, color: AppTheme.primary),
                                        const SizedBox(width: 6),
                                        Text('المعلم المشرف: ', style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                                        Expanded(
                                          child: Text(
                                            c.teacherName ?? "غير مسند",
                                            style: AppTheme.cairoStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: c.teacherName != null ? AppTheme.primaryDark : Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Assistant Teacher
                                    if (c.assistantTeacherName != null && c.assistantTeacherName!.trim().isNotEmpty) ...[
                                      const Divider(height: 10, thickness: 0.5),
                                      Row(
                                        children: [
                                          const Icon(Icons.handshake_outlined, size: 14, color: Colors.teal),
                                          const SizedBox(width: 6),
                                          Text('مساعد الحلقة: ', style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                                          Expanded(
                                            child: Text(
                                              c.assistantTeacherName!,
                                              style: AppTheme.cairoStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Action Buttons
                              Row(
                                children: [
                                  // Manage Students
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.groups, size: 15),
                                      label: Text(
                                        'إدارة طلاب الحلقة',
                                        style: AppTheme.cairoStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _showCircleStudentsModal(c),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Edit Circle
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.blue),
                                    label: Text('تعديل', style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.blue)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _showAddEditCircleModal(c),
                                  ),
                                  const SizedBox(width: 6),

                                  // Toggle Status
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      side: BorderSide(
                                        color: c.isActive ? Colors.orange.shade300 : Colors.green.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _toggleCircleStatus(c),
                                    child: Icon(
                                      c.isActive ? Icons.block : Icons.check_circle_outline,
                                      size: 15,
                                      color: c.isActive ? Colors.orange.shade800 : Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Delete Circle
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _confirmHardDeleteCircle(c),
                                    child: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _filteredCircles.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
      final list = await ApiService.getAllStudentsForEnrollment();
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
          (s.circleName != null && s.circleName!.toLowerCase().contains(query))).toList();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
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
                      Text('إضافة وتنسيب طلاب جدد (بحث فوري ذكي):',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary)),
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
                              child: Text('لا يوجد طلاب مطابقين للبحث',
                                  style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: available.length > 10 ? 10 : available.length,
                              itemBuilder: (ctx, i) {
                                final st = available[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(st.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  subtitle: Text(st.circleName != null ? 'حلقة: ${st.circleName}' : 'غير مسند لحلقة',
                                      style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
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
                                subtitle: Text('التواصل: ${s.familyContact ?? "-"} | الهوية: ${s.studentIdentityNumber ?? "-"}',
                                    style: AppTheme.cairoStyle(fontSize: 11)),
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
