import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ParentAuditScreen extends StatefulWidget {
  const ParentAuditScreen({super.key});

  @override
  State<ParentAuditScreen> createState() => _ParentAuditScreenState();
}

class _ParentAuditScreenState extends State<ParentAuditScreen> {
  bool _isLoading = true;
  List<dynamic> _parentsData = [];

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  Future<void> _loadAudit() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getParentAuditData();
      setState(() {
        _parentsData = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تدقيق وحوكمة أبناء أولياء الأمور',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parentsData.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد بيانات أولياء أمور مسجلة حالياً.',
                    style: AppTheme.cairoStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _parentsData.length,
                  itemBuilder: (context, index) {
                    final p = _parentsData[index];
                    final parentName = p['parentName'] ?? 'ولي أمر';
                    final parentId = p['parentId'] ?? p['parentIdentityNumber'] ?? '-';
                    final contact = p['contact'] ?? p['phone'] ?? '-';
                    final children = p['children'] as List? ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Icon(Icons.family_restroom, color: AppTheme.primary),
                        ),
                        title: Text(
                          parentName,
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          'رقم هوية ولي الأمر: $parentId | التواصل: $contact',
                          style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: Colors.grey.shade50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الأبناء المكفولون والمسجلون تحت حسابه (${children.length}):',
                                  style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryDark),
                                ),
                                const SizedBox(height: 8),
                                ...children.map((c) {
                                  final isOrphan = (c['fatherStatus'] == 'شهيد' || c['fatherStatus'] == 'متوفي' || c['isOrphan'] == true);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.child_care, size: 18, color: Colors.teal),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                c['fullName'] ?? 'طالب',
                                                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                            if (isOrphan)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'يتيم',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(right: 24, top: 2),
                                          child: Text(
                                            'هوية الطالب: ${c['studentIdentityNumber'] ?? c['identityNumber'] ?? "-"} | الحلقة: ${c['circleName'] ?? "غير مسند"}',
                                            style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
