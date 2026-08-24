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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadAuditLogs();
  }

  void _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final list = await ApiService.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _filteredUsers = list;
          _isLoadingUsers = false;
        });
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

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() => _filteredUsers = _users);
    } else {
      final q = query.toLowerCase().trim();
      setState(() {
        _filteredUsers = _users.where((u) {
          return u.fullName.toLowerCase().contains(q) ||
                 u.username.toLowerCase().contains(q) ||
                 u.role.toLowerCase().contains(q) ||
                 u.id.toString().contains(q);
        }).toList();
      });
    }
  }

  void _copyPassword(String password, String userName) {
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 تم نسخ كلمة المرور للمستخدم ($userName): $password'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('تعديل الحساب: ${user.fullName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.badge)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم (Username)', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الدور والصلاحيات', prefixIcon: Icon(Icons.shield)),
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
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 20),
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
              icon: const Icon(Icons.save),
              label: const Text('حفظ التغييرات'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
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
                      const SnackBar(content: Text('تم تحديث الحساب وكلمة المرور بنجاح'), backgroundColor: Colors.green),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('إنشاء حساب جديد', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.badge)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم (Username)', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الدور والصلاحيات', prefixIcon: Icon(Icons.shield)),
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
                  decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.key)),
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
              icon: const Icon(Icons.add),
              label: const Text('إنشاء الحساب'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
                final success = await ApiService.createUser({
                  'fullName': nameCtrl.text.trim(),
                  'username': userCtrl.text.trim(),
                  'role': selectedRole,
                  'password': passCtrl.text.trim(),
                });
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
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد تماماً من حذف حساب (${user.fullName})؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المطور وإدارة الحسابات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.accentLight,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'حسابات النظام وكلمات المرور'),
            Tab(icon: Icon(Icons.shield), text: 'سجل الرقابة الأمنية'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('مستخدم جديد', style: TextStyle(color: Colors.white)),
              onPressed: _showCreateUserDialog,
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: System Users with Dynamic Search & Full Management
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterUsers,
                  decoration: InputDecoration(
                    labelText: 'ابحث باسم المستخدم أو الاسم الكامل أو الدور...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterUsers('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                        ? const Center(child: Text('لا توجد حسابات مطابقة للبحث'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (ctx, index) {
                              final u = _filteredUsers[index];
                              final pw = u.plainPassword ?? '123456';
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppTheme.primary,
                                            child: Text(
                                              u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
                                              style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(u.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                Text('اسم المستخدم: ${u.username}', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              u.role,
                                              style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Password Badge & Copy
                                          InkWell(
                                            onTap: () => _copyPassword(pw, u.fullName),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.key, size: 16, color: AppTheme.accent),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    pw,
                                                    style: AppTheme.cairoStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      fontFamily: 'monospace',
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.copy, size: 14, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Actions
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                                                tooltip: 'تعديل الحساب',
                                                onPressed: () => _showEditUserDialog(u),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                tooltip: 'حذف الحساب',
                                                onPressed: () => _confirmDeleteUser(u),
                                              ),
                                            ],
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
                  ? const Center(child: Text('لا توجد سجلات رقابة أمنية مسجلة'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _auditLogs.length,
                      itemBuilder: (ctx, index) {
                        final log = _auditLogs[index];
                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.accentLight,
                              child: Icon(Icons.shield, color: AppTheme.primary),
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
