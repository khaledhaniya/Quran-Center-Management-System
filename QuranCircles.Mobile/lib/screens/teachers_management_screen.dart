import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<Teacher> _filteredTeachers = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'ALL';
  String _selectedStatus = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getTeachers(forceRefresh: true);
      if (mounted) {
        setState(() {
          _teachers = list;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredTeachers = _teachers.where((t) {
        // Query filter
        if (query.isNotEmpty) {
          final matches = t.fullName.toLowerCase().contains(query) ||
              (t.identityNumber != null && t.identityNumber!.contains(query)) ||
              (t.contact != null && t.contact!.contains(query)) ||
              (t.whatsappNumber != null && t.whatsappNumber!.contains(query)) ||
              (t.taskRole != null && t.taskRole!.toLowerCase().contains(query)) ||
              (t.qualification != null && t.qualification!.toLowerCase().contains(query));
          if (!matches) return false;
        }

        // Role filter
        if (_selectedRole != 'ALL') {
          final role = (t.taskRole ?? '').trim();
          if (_selectedRole == 'غير مكلف') {
            if (role.isNotEmpty && role != 'غير مكلف') return false;
          } else {
            if (!role.contains(_selectedRole)) return false;
          }
        }

        // Status filter
        if (_selectedStatus == 'ACTIVE' && !t.isActive) return false;
        if (_selectedStatus == 'INACTIVE' && t.isActive) return false;

        return true;
      }).toList();
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 تم نسخ $label: $text'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    if (role == null || role.isEmpty || role == 'غير مكلف') return Colors.blueGrey;
    if (role.contains('أمير المركز')) return Colors.amber.shade800;
    if (role.contains('مشرف اختبارات')) return Colors.orange.shade800;
    if (role.contains('معلم حلقة')) return const Color(0xFF0D5C3A);
    if (role.contains('مساعد حلقة')) return Colors.teal.shade700;
    if (role.contains('الجودة')) return Colors.indigo.shade600;
    if (role.contains('المالي')) return Colors.green.shade700;
    if (role.contains('التحفيظ')) return Colors.blue.shade700;
    if (role.contains('الفتى الواعظ')) return const Color(0xFFE11D48);
    if (role.contains('دورات')) return Colors.purple.shade700;
    return AppTheme.primary;
  }

  IconData _getRoleIcon(String? role) {
    if (role == null || role.isEmpty || role == 'غير مكلف') return Icons.person_outline;
    if (role.contains('أمير المركز')) return Icons.workspace_premium;
    if (role.contains('مشرف اختبارات')) return Icons.fact_check_outlined;
    if (role.contains('معلم حلقة')) return Icons.menu_book;
    if (role.contains('مساعد حلقة')) return Icons.handshake_outlined;
    if (role.contains('الجودة')) return Icons.analytics_outlined;
    if (role.contains('المالي')) return Icons.account_balance_wallet_outlined;
    if (role.contains('التحفيظ')) return Icons.auto_stories;
    if (role.contains('الفتى الواعظ')) return Icons.record_voice_over;
    if (role.contains('دورات')) return Icons.school_outlined;
    return Icons.badge_outlined;
  }

  Widget _buildHeroHeader() {
    final activeCount = _teachers.where((t) => t.isActive).length;
    final staffAssigned = _teachers.where((t) => t.taskRole != null && t.taskRole!.trim().isNotEmpty && t.taskRole != 'غير مكلف').length;

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
                    const Icon(Icons.school, size: 13, color: AppTheme.accent),
                    const SizedBox(width: 5),
                    Text(
                      'الكادر التعليمي لمنظومة المركز',
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
                onPressed: _loadTeachers,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: AppTheme.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إدارة المشايخ والمعلّمين والمحفّظين',
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
            'إدارة سجلات المعلمين، الصلاحيات، الحلقات المسندة، وأرقام التواصل والاعتماد.',
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
              _buildMiniCounter('إجمالي الكادر', '${_teachers.length}', Icons.people_alt, Colors.white),
              const SizedBox(width: 8),
              _buildMiniCounter('معلمون نشطون', '$activeCount', Icons.check_circle, Colors.greenAccent),
              const SizedBox(width: 8),
              _buildMiniCounter('مكلفون بمهام', '$staffAssigned', Icons.assignment_ind, AppTheme.accent),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditTeacherModal(),
              icon: const Icon(Icons.person_add_alt_1, size: 18, color: Color(0xFF0D3B26)),
              label: Text(
                'إضافة معلّم جديد للكادر',
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

  Widget _buildRoleFilterChip(String label, String roleKey) {
    final isSelected = _selectedRole == roleKey;
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
            _selectedRole = selected ? roleKey : 'ALL';
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

  void _showAddEditTeacherModal([Teacher? teacher]) {
    final nameCtrl = TextEditingController(text: teacher?.fullName ?? '');
    final idCtrl = TextEditingController(text: teacher?.identityNumber ?? '');
    final contactCtrl = TextEditingController(text: teacher?.contact ?? '');
    final whatsappCtrl = TextEditingController(text: teacher?.whatsappNumber ?? '');
    final addressCtrl = TextEditingController(text: teacher?.address ?? '');
    final qualificationCtrl = TextEditingController(text: teacher?.qualification ?? '');
    final ajzaaCtrl = TextEditingController(text: teacher?.memorizedAjzaa ?? '');
    final walletCtrl = TextEditingController(text: teacher?.walletNumber ?? '');
    final walletOwnerCtrl = TextEditingController(text: teacher?.walletOwner ?? '');
    final familyCountCtrl = TextEditingController(text: teacher?.familyMembersCount?.toString() ?? '');
    final targetStudentsCtrl = TextEditingController(text: teacher?.studentsCountTarget ?? '');
    final passwordCtrl = TextEditingController(text: '123456');

    String selectedRole = (teacher?.taskRole != null && teacher!.taskRole!.trim().isNotEmpty)
        ? teacher.taskRole!
        : 'معلم حلقة';
    String selectedSocialStatus = teacher?.socialStatus ?? 'أعزب';
    String selectedMosque = teacher?.mosqueName ?? 'علي بن أبي طالب';

    final rolesList = [
      'غير مكلف',
      'معلم حلقة',
      'مساعد حلقة',
      'مشرف اختبارات',
      'شؤون التحفيظ',
      'الجودة والرقابة',
      'الملف المالي',
      'معلم دورات',
      'الفتى الواعظ',
      'أمير المركز',
    ];

    if (!rolesList.contains(selectedRole)) {
      rolesList.insert(0, selectedRole);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                          child: const Icon(Icons.school, color: AppTheme.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacher == null ? 'تسجيل وإضافة معلم جديد بالكادر' : 'تعديل بيانات: ${teacher.fullName}',
                                style: AppTheme.cairoStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'إدارة الملف الإداري والتكليفات والصلاحيات لمنظومة مركز البيان',
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

                  // Form Content
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: البيانات الشخصية
                        _buildSectionHeader('البيانات الشخصية والتعريفية', Icons.badge_outlined),
                        const SizedBox(height: 10),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الرباعي الكامل للشيخ / المعلم *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: idCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهوية الوطنية',
                                  prefixIcon: Icon(Icons.perm_identity),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: contactCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الجوال *',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: whatsappCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الواتساب',
                                  prefixIcon: Icon(Icons.chat_outlined, color: Colors.green),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: addressCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'مكان الإقامة / السكن',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Section 2: التكليف والصلاحيات والمؤهلات
                        _buildSectionHeader('المهمة والتكليف والمؤهل العلمي', Icons.stars_outlined),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'المهمة والتكليف الإداري *',
                            prefixIcon: Icon(Icons.assignment_ind_outlined),
                          ),
                          items: rolesList.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedRole = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qualificationCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'المؤهل العلمي',
                                  hintText: 'بكالوريوس، إجازة بالسند...',
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: ajzaaCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'أجزاء الحفظ',
                                  hintText: 'القرآن كاملاً، 20 جزء...',
                                  prefixIcon: Icon(Icons.menu_book),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: targetStudentsCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'العدد المستهدف للحلقة',
                                  prefixIcon: Icon(Icons.groups_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedSocialStatus,
                                decoration: const InputDecoration(
                                  labelText: 'الحالة الاجتماعية',
                                  prefixIcon: Icon(Icons.family_restroom_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'أعزب', child: Text('أعزب')),
                                  DropdownMenuItem(value: 'متزوج', child: Text('متزوج')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedSocialStatus = val);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Section 3: البيانات المالية
                        _buildSectionHeader('البيانات المالية والمحفظة', Icons.account_balance_wallet_outlined),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: walletCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'رقم المحفظة المالية',
                                  prefixIcon: Icon(Icons.wallet),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: walletOwnerCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'اسم صاحب المحفظة',
                                  prefixIcon: Icon(Icons.person_pin_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (teacher == null) ...[
                          const SizedBox(height: 18),
                          _buildSectionHeader('بيانات الدخول للنظام (اختياري)', Icons.key_outlined),
                          const SizedBox(height: 10),
                          TextField(
                            controller: passwordCtrl,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور الابتدائية',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
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
              label: Text(teacher == null ? 'إضافة المعلم' : 'حفظ التعديلات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                final fullName = nameCtrl.text.trim();
                if (fullName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم المعلم الرباعي'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                if (teacher == null) {
                  final ok = await ApiService.createTeacher(
                    fullName: fullName,
                    contact: contactCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    identityNumber: idCtrl.text.trim(),
                    whatsappNumber: whatsappCtrl.text.trim(),
                    taskRole: selectedRole,
                    qualification: qualificationCtrl.text.trim(),
                    memorizedAjzaa: ajzaaCtrl.text.trim(),
                    socialStatus: selectedSocialStatus,
                    familyMembersCount: int.tryParse(familyCountCtrl.text.trim()),
                    mosqueName: selectedMosque,
                    walletNumber: walletCtrl.text.trim(),
                    walletOwner: walletOwnerCtrl.text.trim(),
                    studentsCountTarget: targetStudentsCtrl.text.trim(),
                    password: passwordCtrl.text.trim(),
                    username: idCtrl.text.trim().isNotEmpty ? idCtrl.text.trim() : null,
                  );
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadTeachers();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت إضافة المعلم بنجاح بالكادر'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  final ok = await ApiService.updateTeacher(
                    teacher.id,
                    fullName: fullName,
                    contact: contactCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    identityNumber: idCtrl.text.trim(),
                    whatsappNumber: whatsappCtrl.text.trim(),
                    taskRole: selectedRole,
                    qualification: qualificationCtrl.text.trim(),
                    memorizedAjzaa: ajzaaCtrl.text.trim(),
                    socialStatus: selectedSocialStatus,
                    familyMembersCount: int.tryParse(familyCountCtrl.text.trim()),
                    mosqueName: selectedMosque,
                    walletNumber: walletCtrl.text.trim(),
                    walletOwner: walletOwnerCtrl.text.trim(),
                    studentsCountTarget: targetStudentsCtrl.text.trim(),
                  );
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  if (ok) {
                    _loadTeachers();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث بيانات المعلم وصلاحياته بنجاح'), backgroundColor: Colors.green),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTheme.cairoStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  void _toggleTeacherStatus(Teacher t) async {
    final actionText = t.isActive ? 'تعطيل' : 'تنشيط';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(t.isActive ? Icons.block : Icons.check_circle_outline, color: t.isActive ? Colors.orange : Colors.green),
            const SizedBox(width: 8),
            Text('تأكيد $actionText حساب المعلم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('هل أنت متأكد من $actionText حساب المعلم (${t.fullName})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.isActive ? Colors.orange.shade800 : Colors.green,
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

  void _confirmHardDeleteTeacher(Teacher t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('تحذير: حذف نهائي للمعلم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Text(
          'هل أنت متأكد تماماً من حذف المعلم (${t.fullName}) نهائياً من المنظومة؟\nسيتم حذف الحساب وحلقاته المرتبطة ولا يمكن التراجع.',
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
      final ok = await ApiService.hardDeleteTeacher(t.id);
      if (ok) {
        _loadTeachers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المعلم نهائياً من النظام'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المشايخ والمعلمين'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditTeacherModal(),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text('إضافة معلم جديد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadTeachers(),
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
                        hintText: 'ابحث باسم المعلم، الهوية، الجوال، التكليف، أو المؤهل...',
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

                    // Role filter chips
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildRoleFilterChip('الكل (${_teachers.length})', 'ALL'),
                          _buildRoleFilterChip('معلمو الحلقات', 'معلم حلقة'),
                          _buildRoleFilterChip('مشرفو الاختبارات', 'مشرف اختبارات'),
                          _buildRoleFilterChip('شؤون التحفيظ', 'شؤون التحفيظ'),
                          _buildRoleFilterChip('الجودة والرقابة', 'الجودة'),
                          _buildRoleFilterChip('الملف المالي', 'المالي'),
                          _buildRoleFilterChip('الفتى الواعظ', 'الفتى الواعظ'),
                          _buildRoleFilterChip('أمير المركز', 'أمير المركز'),
                          _buildRoleFilterChip('غير مكلف', 'غير مكلف'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Status filter chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStatusFilterChip('كل الحالات', 'ALL', Icons.all_inclusive),
                          _buildStatusFilterChip('نشط (${_teachers.where((t) => t.isActive).length})', 'ACTIVE', Icons.check_circle_outline),
                          _buildStatusFilterChip('معطّل (${_teachers.where((t) => !t.isActive).length})', 'INACTIVE', Icons.block),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 1, thickness: 1)),

            // 3. Teachers List or Loading / Empty States
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_filteredTeachers.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(50),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'لا يوجد معلمون مطابقون للبحث أو الفلتر',
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
                      final t = _filteredTeachers[index];
                      final roleColor = _getRoleColor(t.taskRole);
                      final roleIcon = _getRoleIcon(t.taskRole);
                      final taskTitle = (t.taskRole != null && t.taskRole!.trim().isNotEmpty) ? t.taskRole! : 'غير مكلف';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: t.isActive ? Colors.grey.shade200 : Colors.red.shade100,
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
                              // Top Header: Avatar + Teacher Name (STRICTLY SINGLE LINE) + Status Pill
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: roleColor.withValues(alpha: 0.12),
                                    child: Text(
                                      t.fullName.isNotEmpty ? t.fullName.trim()[0] : 'م',
                                      style: AppTheme.cairoStyle(
                                        color: roleColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Teacher Name in ONE SINGLE LINE
                                  Expanded(
                                    child: Text(
                                      t.fullName,
                                      style: AppTheme.cairoStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
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
                                      color: t.isActive ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: t.isActive ? Colors.green.shade300 : Colors.red.shade300,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          t.isActive ? Icons.check_circle : Icons.block,
                                          size: 11,
                                          color: t.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          t.isActive ? 'نشط' : 'معطّل',
                                          style: AppTheme.cairoStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: t.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Badges Ribbon: Task Role + Qualification + Memorized Ajzaa
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  // Task Role Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(roleIcon, size: 13, color: roleColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          taskTitle,
                                          style: AppTheme.cairoStyle(
                                            fontSize: 11,
                                            color: roleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Qualification Badge
                                  if (t.qualification != null && t.qualification!.trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.school, size: 12, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            t.qualification!,
                                            style: AppTheme.cairoStyle(fontSize: 10.5, color: Colors.blue.shade800),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Memorized Ajzaa Badge
                                  if (t.memorizedAjzaa != null && t.memorizedAjzaa!.trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_stories, size: 12, color: Colors.amber.shade800),
                                          const SizedBox(width: 4),
                                          Text(
                                            t.memorizedAjzaa!,
                                            style: AppTheme.cairoStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Details Container: National ID + Phone + WhatsApp
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    // Row 1: National ID
                                    Row(
                                      children: [
                                        const Icon(Icons.badge_outlined, size: 14, color: AppTheme.primary),
                                        const SizedBox(width: 6),
                                        Text('رقم الهوية: ', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700)),
                                        Text(
                                          (t.identityNumber != null && t.identityNumber!.trim().isNotEmpty)
                                              ? t.identityNumber!
                                              : 'غير مسجل',
                                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        if (t.identityNumber != null && t.identityNumber!.trim().isNotEmpty) ...[
                                          const Spacer(),
                                          InkWell(
                                            onTap: () => _copyToClipboard(t.identityNumber!, 'رقم الهوية'),
                                            child: const Icon(Icons.copy, size: 14, color: Colors.grey),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Divider(height: 12, thickness: 0.5),

                                    // Row 2: Phone & WhatsApp
                                    Row(
                                      children: [
                                        // Phone
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 14, color: Colors.blue),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  (t.contact != null && t.contact!.trim().isNotEmpty)
                                                      ? t.contact!
                                                      : '-',
                                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (t.contact != null && t.contact!.trim().isNotEmpty)
                                                InkWell(
                                                  onTap: () => _copyToClipboard(t.contact!, 'رقم الجوال'),
                                                  child: const Icon(Icons.copy, size: 13, color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // WhatsApp
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.chat_outlined, size: 14, color: Colors.green),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  (t.whatsappNumber != null && t.whatsappNumber!.trim().isNotEmpty)
                                                      ? t.whatsappNumber!
                                                      : (t.contact ?? '-'),
                                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (t.whatsappNumber != null && t.whatsappNumber!.trim().isNotEmpty)
                                                InkWell(
                                                  onTap: () => _copyToClipboard(t.whatsappNumber!, 'رقم الواتساب'),
                                                  child: const Icon(Icons.copy, size: 13, color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Actions Row: Edit / Permissions, Toggle Active, Hard Delete
                              Row(
                                children: [
                                  // Edit Button
                                  Expanded(
                                    flex: 3,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_note, size: 16, color: AppTheme.primary),
                                      label: Text(
                                        'تعديل البيانات والصلاحيات',
                                        style: AppTheme.cairoStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _showAddEditTeacherModal(t),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Toggle Status
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton.icon(
                                      icon: Icon(
                                        t.isActive ? Icons.block : Icons.check_circle_outline,
                                        size: 14,
                                        color: t.isActive ? Colors.orange.shade800 : Colors.green.shade700,
                                      ),
                                      label: Text(
                                        t.isActive ? 'تعطيل' : 'تنشيط',
                                        style: AppTheme.cairoStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: t.isActive ? Colors.orange.shade800 : Colors.green.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                        side: BorderSide(
                                          color: t.isActive ? Colors.orange.shade200 : Colors.green.shade200,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _toggleTeacherStatus(t),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Hard Delete
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _confirmHardDeleteTeacher(t),
                                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _filteredTeachers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
