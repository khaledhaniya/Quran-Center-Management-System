import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/contact_helper.dart';

class ParentAuditScreen extends StatefulWidget {
  const ParentAuditScreen({super.key});

  @override
  State<ParentAuditScreen> createState() => _ParentAuditScreenState();
}

class _ParentAuditScreenState extends State<ParentAuditScreen> {
  bool _isLoading = true;
  List<dynamic> _parentsData = [];
  List<dynamic> _filteredData = [];
  List<Student> _allStudents = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  Future<void> _loadAudit() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getParentAuditData();
      final students = await ApiService.getStudents();
      setState(() {
        _parentsData = list;
        _allStudents = students;
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات الحوكمة: $e')),
        );
      }
    }
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredData = List.from(_parentsData);
      return;
    }

    _filteredData = _parentsData.where((p) {
      final pName = (p['parentName'] ?? '').toString().toLowerCase();
      final pId = (p['parentIdentityNumber'] ?? p['username'] ?? '').toString().toLowerCase();
      final children = p['children'] as List? ?? [];
      final matchesChild = children.any((c) {
        final cName = (c['fullName'] ?? '').toString().toLowerCase();
        final cId = (c['studentIdentityNumber'] ?? c['identityNumber'] ?? '').toString().toLowerCase();
        return cName.contains(q) || cId.contains(q);
      });
      return pName.contains(q) || pId.contains(q) || matchesChild;
    }).toList();
  }

  Future<void> _unlinkStudent(int studentId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.link_off, color: Colors.red),
            const SizedBox(width: 8),
            Text('فك ربط الطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من فك ربط الطالب "$studentName" من حساب ولي الأمر الحالي؟\nسيبقى الطالب في النظام ويمكن إعادة ربطه بأي ولي أمر آخر لاحقاً.',
          style: AppTheme.cairoStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد فك الربط'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ApiService.unlinkChildFromParent(studentId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم فك ربط الطالب بنجاح'), backgroundColor: Colors.green),
      );
      _loadAudit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في فك الربط، يرجى المحاولة لاحقاً'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reassignStudent(int studentId, String studentName, int currentParentId) async {
    int? selectedParentId;

    final otherParents = _parentsData.where((p) {
      final id = p['parentId'] ?? p['parentUserId'];
      return id != currentParentId;
    }).toList();

    if (otherParents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد أولياء أمور آخرون لإعادة الإسناد إليهم')),
      );
      return;
    }

    selectedParentId = otherParents.first['parentId'] ?? otherParents.first['parentUserId'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.swap_horiz, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('نقل الطالب لولي أمر آخر', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطالب: $studentName', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 12),
              Text('اختر ولي الأمر الجديد:', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: selectedParentId,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: otherParents.map<DropdownMenuItem<int>>((p) {
                  final pId = p['parentId'] ?? p['parentUserId'];
                  final pName = p['parentName'] ?? 'ولي أمر';
                  final pIdNum = p['parentIdentityNumber'] ?? p['username'] ?? '';
                  return DropdownMenuItem<int>(
                    value: pId,
                    child: Text(
                      '$pName ($pIdNum)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.cairoStyle(fontSize: 12.5),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedParentId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || selectedParentId == null) return;

    final success = await ApiService.reassignChildToParent(studentId, selectedParentId!);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة إسناد الطالب بنجاح'), backgroundColor: Colors.green),
      );
      _loadAudit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في إعادة الإسناد'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _linkNewStudentToParent(int parentId, String parentName) async {
    // Find unassigned or all students
    if (_allStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات طلاب متاحة حالياً')),
      );
      return;
    }

    int selectedStudentId = _allStudents.first.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person_add_alt_1, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('ربط طالب بولي الأمر', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ولي الأمر: $parentName', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 12),
              Text('اختر الطالب المراد ربطه بحسابه:', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: selectedStudentId,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: _allStudents.map<DropdownMenuItem<int>>((s) {
                  return DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(
                      '${s.fullName} - ${s.circleName ?? "بدون حلقة"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.cairoStyle(fontSize: 12.5),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStudentId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الربط'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final success = await ApiService.reassignChildToParent(selectedStudentId, parentId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم ربط الطالب بولي الأمر بنجاح'), backgroundColor: Colors.green),
      );
      _loadAudit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في ربط الطالب'), backgroundColor: Colors.red),
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              val,
              style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
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

  @override
  Widget build(BuildContext context) {
    final totalParents = _parentsData.length;
    int multiChildCount = 0;
    int totalChildren = 0;
    int orphanCount = 0;

    for (var p in _parentsData) {
      final children = p['children'] as List? ?? [];
      totalChildren += children.length;
      if (children.length > 1) multiChildCount++;
      for (var c in children) {
        if (c['fatherStatus'] == 'شهيد' || c['fatherStatus'] == 'متوفي' || c['isOrphan'] == true) {
          orphanCount++;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'تدقيق وحوكمة أبناء أولياء الأمور',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAudit,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAudit,
              child: CustomScrollView(
                slivers: [
                  // KPI Stats Ribbon
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: Row(
                        children: [
                          _buildStatCard('أولياء الأمور', totalParents.toString(), Icons.family_restroom, AppTheme.primary),
                          const SizedBox(width: 8),
                          _buildStatCard('متعدد الأبناء', multiChildCount.toString(), Icons.groups, Colors.blue),
                          const SizedBox(width: 8),
                          _buildStatCard('إجمالي الأبناء', totalChildren.toString(), Icons.school, Colors.teal),
                          const SizedBox(width: 8),
                          _buildStatCard('الأيتام', orphanCount.toString(), Icons.volunteer_activism, Colors.amber.shade800),
                        ],
                      ),
                    ),
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(_applySearch),
                        decoration: InputDecoration(
                          hintText: 'بحث باسم ولي الأمر أو الابن أو رقم الهوية...',
                          hintStyle: AppTheme.cairoStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(_applySearch);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Parent List
                  if (_filteredData.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'لا توجد بيانات مطابقة لعملية البحث',
                          style: AppTheme.cairoStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = _filteredData[index];
                            final parentName = p['parentName'] ?? 'ولي أمر';
                            final parentId = p['parentId'] ?? p['parentUserId'];
                            final parentIdNumber = p['parentIdentityNumber'] ?? p['username'] ?? '-';
                            final phone = (p['contact'] ?? p['phone'] ?? '').toString();
                            final children = p['children'] as List? ?? [];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.4),
                                  child: const Icon(Icons.family_restroom, color: AppTheme.primary),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        parentName,
                                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${children.length} أبناء',
                                        style: AppTheme.cairoStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'هوية: $parentIdNumber',
                                        style: AppTheme.cairoStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                      ),
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => ContactHelper.launchDialer(context, phone),
                                          child: const Icon(Icons.phone_in_talk, size: 14, color: Colors.blue),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => ContactHelper.launchWhatsApp(context, phone),
                                          child: const Icon(Icons.chat, size: 14, color: Colors.green),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.grey.shade50,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'الأبناء المكفولون تحت حسابه (${children.length}):',
                                              style: AppTheme.cairoStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.primaryDark,
                                              ),
                                            ),
                                            TextButton.icon(
                                              icon: const Icon(Icons.add, size: 14),
                                              label: Text('ربط طالب', style: AppTheme.cairoStyle(fontSize: 11)),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: () => _linkNewStudentToParent(parentId, parentName),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (children.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                                            child: Text(
                                              'لا يوجد أبناء مربوطون حالياً بهذا الولي.',
                                              style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          )
                                        else
                                          ...children.map((c) {
                                            final studentId = c['id'] ?? c['Id'] ?? 0;
                                            final studentName = c['fullName'] ?? 'طالب';
                                            final isOrphan = (c['fatherStatus'] == 'شهيد' || c['fatherStatus'] == 'متوفي' || c['isOrphan'] == true);
                                            final circleName = c['circleName'] ?? "غير مسند حلقة";

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.grey.shade200),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.school, size: 16, color: Colors.teal),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          studentName,
                                                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (isOrphan)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          margin: const EdgeInsets.only(left: 6),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.shade100,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'يتيم',
                                                            style: AppTheme.cairoStyle(
                                                              color: Colors.red.shade900,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'الحلقة: $circleName | هوية: ${c['studentIdentityNumber'] ?? c['identityNumber'] ?? "-"}',
                                                        style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700),
                                                      ),
                                                    ],
                                                  ),
                                                  const Divider(height: 10, thickness: 0.5),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      // Reassign Button
                                                      OutlinedButton.icon(
                                                        icon: const Icon(Icons.swap_horiz, size: 14),
                                                        label: Text('نقل / إعادة إسناد', style: AppTheme.cairoStyle(fontSize: 11)),
                                                        style: OutlinedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        onPressed: () => _reassignStudent(studentId, studentName, parentId),
                                                      ),
                                                      const SizedBox(width: 8),

                                                      // Unlink Button
                                                      OutlinedButton.icon(
                                                        icon: const Icon(Icons.link_off, size: 14, color: Colors.red),
                                                        label: Text(
                                                          'فك الربط',
                                                          style: AppTheme.cairoStyle(fontSize: 11, color: Colors.red),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          side: BorderSide(color: Colors.red.shade200),
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        onPressed: () => _unlinkStudent(studentId, studentName),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: _filteredData.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
