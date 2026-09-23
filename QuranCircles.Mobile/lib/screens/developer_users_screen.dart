import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DeveloperUsersScreen extends StatefulWidget {
  const DeveloperUsersScreen({super.key});

  @override
  State<DeveloperUsersScreen> createState() => _DeveloperUsersScreenState();
}

class _DeveloperUsersScreenState extends State<DeveloperUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<AuditLog> _auditLogs = [];
  
  final _searchController = TextEditingController();
  bool _isLoadingUsers = true;
  bool _isLoadingLogs = true;

  // Filter states
  String _selectedRole = 'ALL';
  String _selectedStatus = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final list = await ApiService.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _isLoadingUsers = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  void _loadAuditLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final logs = await ApiService.getAuditLogs();
      if (mounted) {
        setState(() {
          _auditLogs = logs;
          _isLoadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredUsers = _users.where((u) {
        // Query filter
        if (query.isNotEmpty) {
          final matches = u.fullName.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query) ||
              u.role.toLowerCase().contains(query) ||
              u.id.toString().contains(query);
          if (!matches) return false;
        }

        // Role filter
        if (_selectedRole != 'ALL') {
          if (u.role != _selectedRole) return false;
        }

        // Status filter
        if (_selectedStatus == 'ACTIVE') {
          if (!u.isActive) return false;
        } else if (_selectedStatus == 'INACTIVE') {
          if (u.isActive) return false;
        }

        return true;
      }).toList();
    });
  }

  void _copyPassword(String password, String userName) {
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 تم نسخ كلمة المرور للمستخدم ($userName): $password'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleUserStatus(User user) async {
    final newStatus = !user.isActive;
    final success = await ApiService.toggleUserStatus(user.id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'تم تفعيل الحساب بنجاح' : 'تم تعطيل الحساب بنجاح'),
            backgroundColor: newStatus ? Colors.green : Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر تغيير حالة الحساب'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showEditUserDialog(User user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final userCtrl = TextEditingController(text: user.username);
    final passCtrl = TextEditingController(text: user.plainPassword ?? '');
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_note, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('تعديل حساب: ${user.fullName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم (Username)', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الدور والصلاحيات', prefixIcon: Icon(Icons.shield_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'ExamSupervisor', child: Text('مشرف اختبارات (ExamSupervisor)')),
                    DropdownMenuItem(value: 'Developer', child: Text('مطور النظام (Developer)')),
                    DropdownMenuItem(value: 'Admin', child: Text('مدير المركز (Admin)')),
                    DropdownMenuItem(value: 'Teacher', child: Text('معلّم الحلقة (Teacher)')),
                    DropdownMenuItem(value: 'Student', child: Text('طالب حلقة (Student)')),
                    DropdownMenuItem(value: 'Parent', child: Text('ولي أمر (Parent)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyPassword(passCtrl.text, user.fullName),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('حفظ التعديل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final success = await ApiService.updateUser(user.id, {
                  'fullName': nameCtrl.text.trim(),
                  'username': userCtrl.text.trim(),
                  'role': selectedRole,
                  'password': passCtrl.text.trim(),
                  'teacherId': user.teacherId,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث بيانات الحساب بنجاح'), backgroundColor: Colors.green),
                    );
                    _loadUsers();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فشل تحديث الحساب'), backgroundColor: Colors.red),
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

  void _showCreateUserDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    String selectedRole = 'Student';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_add_alt_1, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 10),
              Text('إنشاء حساب مستخدم جديد', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم (Username)', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الدور والصلاحيات', prefixIcon: Icon(Icons.shield_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'ExamSupervisor', child: Text('مشرف اختبارات (ExamSupervisor)')),
                    DropdownMenuItem(value: 'Developer', child: Text('مطور النظام (Developer)')),
                    DropdownMenuItem(value: 'Admin', child: Text('مدير المركز (Admin)')),
                    DropdownMenuItem(value: 'Teacher', child: Text('معلّم الحلقة (Teacher)')),
                    DropdownMenuItem(value: 'Student', child: Text('طالب حلقة (Student)')),
                    DropdownMenuItem(value: 'Parent', child: Text('ولي أمر (Parent)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.key_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إنشاء الحساب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
                final success = await ApiService.createUser(
                  fullName: nameCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  role: selectedRole,
                  password: passCtrl.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إنشاء الحساب بنجاح'), backgroundColor: Colors.green),
                    );
                    _loadUsers();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فشل إنشاء الحساب'), backgroundColor: Colors.red),
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

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('تأكيد حذف الحساب'),
          ],
        ),
        content: Text('هل أنت متأكد تماماً من حذف حساب (${user.fullName})؟ لا يمكن التراجع عن هذه الخطوة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ApiService.deleteUser(user.id);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف الحساب بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل حذف الحساب'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Developer':
        return Colors.red.shade700;
      case 'Admin':
        return Colors.amber.shade800;
      case 'ExamSupervisor':
        return Colors.indigo.shade600;
      case 'Teacher':
        return AppTheme.primary;
      case 'Student':
        return Colors.teal.shade700;
      case 'Parent':
        return Colors.purple.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'Developer':
        return 'مطور النظام';
      case 'Admin':
        return 'مدير المركز';
      case 'ExamSupervisor':
        return 'مشرف اختبارات';
      case 'Teacher':
        return 'معلّم';
      case 'Student':
        return 'طالب';
      case 'Parent':
        return 'ولي أمر';
      default:
        return role;
    }
  }

  Widget _buildRoleFilterChip(String label, String roleKey) {
    final isSelected = _selectedRole == roleKey;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withOpacity(0.18),
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
        selectedColor: AppTheme.primary.withOpacity(0.18),
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

  @override
  Widget build(BuildContext context) {
    final activeCount = _users.where((u) => u.isActive).length;
    final inactiveCount = _users.where((u) => !u.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المطور وإدارة الحسابات'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.accentLight,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'حسابات النظام وكلمات المرور'),
            Tab(icon: Icon(Icons.security_outlined), text: 'سجل الرقابة الأمنية'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text('مستخدم جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCreateUserDialog,
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Enhanced Responsive System Users Management
          Column(
            children: [
              // Search & Filter Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم، المعرّف، اسم المستخدم، أو الدور...',
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

                    // Role Filter Chips (Horizontally Scrollable)
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildRoleFilterChip('الكل (${_users.length})', 'ALL'),
                          _buildRoleFilterChip('المعلمون', 'Teacher'),
                          _buildRoleFilterChip('مشرفو الاختبارات', 'ExamSupervisor'),
                          _buildRoleFilterChip('الطلاب', 'Student'),
                          _buildRoleFilterChip('أولياء الأمور', 'Parent'),
                          _buildRoleFilterChip('الإدارة', 'Admin'),
                          _buildRoleFilterChip('المطور', 'Developer'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Status Filter Chips & Stats
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStatusFilterChip('كل الحالات', 'ALL', Icons.all_inclusive),
                          _buildStatusFilterChip('نشط ($activeCount)', 'ACTIVE', Icons.check_circle_outline),
                          _buildStatusFilterChip('معطل ($inactiveCount)', 'INACTIVE', Icons.block),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // Users List (Responsive Cards)
              Expanded(
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد حسابات مطابقة للبحث أو الفلتر',
                                  style: AppTheme.cairoStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (ctx, index) {
                              final u = _filteredUsers[index];
                              final pw = u.plainPassword ?? '123456';
                              final roleColor = _getRoleColor(u.role);
                              final roleTitle = _getRoleDisplayName(u.role);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: u.isActive ? Colors.grey.shade200 : Colors.red.shade100,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
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
                                      // Card Top Header: Avatar, Name, Username, Role Chip & Status
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: roleColor.withOpacity(0.12),
                                            child: Text(
                                              u.fullName.isNotEmpty ? u.fullName.trim()[0] : 'U',
                                              style: AppTheme.cairoStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        u.fullName,
                                                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    // Status indicator pill
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: u.isActive ? Colors.green.shade50 : Colors.red.shade50,
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: u.isActive ? Colors.green.shade300 : Colors.red.shade300,
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            u.isActive ? Icons.check_circle : Icons.block,
                                                            size: 11,
                                                            color: u.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            u.isActive ? 'نشط' : 'معطل',
                                                            style: AppTheme.cairoStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: u.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '@${u.username}',
                                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blueGrey),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: roleColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        roleTitle,
                                                        style: AppTheme.cairoStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Middle: Password box + Account ID info
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.key, size: 15, color: AppTheme.accent),
                                                const SizedBox(width: 6),
                                                Text(
                                                  pw,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy, size: 15, color: Colors.grey),
                                                  tooltip: 'نسخ كلمة المرور',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  onPressed: () => _copyPassword(pw, u.fullName),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '#${u.id}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // Actions Row (Toggle Status, Edit, Delete)
                                      Row(
                                        children: [
                                          // Toggle Status Button
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: Icon(
                                                u.isActive ? Icons.block : Icons.check_circle_outline,
                                                size: 15,
                                                color: u.isActive ? Colors.orange.shade800 : Colors.green.shade700,
                                              ),
                                              label: Text(
                                                u.isActive ? 'تعطيل' : 'تفعيل',
                                                style: AppTheme.cairoStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: u.isActive ? Colors.orange.shade800 : Colors.green.shade700,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                side: BorderSide(
                                                  color: u.isActive ? Colors.orange.shade200 : Colors.green.shade200,
                                                ),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => _toggleUserStatus(u),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Edit Button
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.primary),
                                            label: Text('تعديل', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.primary)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _showEditUserDialog(u),
                                          ),
                                          const SizedBox(width: 8),

                                          // Delete Button
                                          OutlinedButton(
                                            child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              side: BorderSide(color: Colors.red.withOpacity(0.3)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _confirmDeleteUser(u),
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

          // Tab 2: Security Audit Logs
          _isLoadingLogs
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد سجلات رقابة أمنية مسجلة',
                        style: AppTheme.cairoStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _auditLogs.length,
                      itemBuilder: (ctx, index) {
                        final log = _auditLogs[index];
                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accentLight.withOpacity(0.2),
                              child: const Icon(Icons.shield_outlined, color: AppTheme.primary),
                            ),
                            title: Text(log.action, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('${log.details}\nالمستخدم: ${log.username} | IP: ${log.ipAddress}', style: AppTheme.cairoStyle(fontSize: 12)),
                            trailing: Text(
                              log.timestamp.length >= 10 ? log.timestamp.substring(0, 10) : log.timestamp,
                              style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
