import 'package:flutter/material.dart';
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
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  void _loadAuditLogs() async {
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
        setState(() {
          _isLoadingLogs = false;
        });
      }
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _users;
      });
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredUsers = _users.where((u) {
          return u.fullName.toLowerCase().contains(q) || u.username.toLowerCase().contains(q);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المطور وسجل الرقابة الأمنية'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.accentLight,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'حسابات النظام والبحث'),
            Tab(icon: Icon(Icons.shield), text: 'سجل الرقابة الأمنية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: System Users with Dynamic Search
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterUsers,
                  decoration: const InputDecoration(
                    labelText: 'ابحث باسم المستخدم أو الاسم الكامل...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (ctx, index) {
                          final u = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary,
                                child: Text(u.username[0].toUpperCase(), style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(u.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('اسم المستخدم: ${u.username} | الدور: ${u.role}', style: AppTheme.cairoStyle(fontSize: 12)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    u.plainPassword != null ? 'كلمة المرور: ${u.plainPassword}' : 'مشفرة',
                                    style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                  ),
                                  Text(u.isActive ? 'نشط' : 'معطل', style: AppTheme.cairoStyle(fontSize: 10, color: u.isActive ? Colors.green : Colors.red)),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _auditLogs.length,
                  itemBuilder: (ctx, index) {
                    final log = _auditLogs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.security, color: AppTheme.primary),
                        title: Text(log.action, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${log.details}\nالمستخدم: ${log.username} | IP: ${log.ipAddress}', style: AppTheme.cairoStyle(fontSize: 12)),
                        trailing: Text(log.timestamp.length >= 10 ? log.timestamp.substring(0, 10) : log.timestamp, style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
