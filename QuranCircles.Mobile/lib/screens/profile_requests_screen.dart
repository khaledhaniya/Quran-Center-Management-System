import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileRequestsScreen extends StatefulWidget {
  const ProfileRequestsScreen({super.key});

  @override
  State<ProfileRequestsScreen> createState() => _ProfileRequestsScreenState();
}

class _ProfileRequestsScreenState extends State<ProfileRequestsScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _filteredRequests = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getProfileUpdateRequests();
      setState(() {
        _requests = list;
        _isLoading = false;
      });
      _applySearch();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      setState(() => _filteredRequests = _requests);
      return;
    }
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filteredRequests = _requests.where((r) {
        final name = (r['studentName'] ?? r['parentName'] ?? r['fullName'] ?? '').toString().toLowerCase();
        final status = (r['status'] ?? '').toString().toLowerCase();
        final id = (r['id'] ?? '').toString();
        return name.contains(q) || status.contains(q) || id.contains(q);
      }).toList();
    });
  }

  Future<void> _processRequest(int requestId, bool approve) async {
    try {
      final success = approve
          ? await ApiService.approveProfileRequest(requestId)
          : await ApiService.rejectProfileRequest(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'تمت الموافقة وتحديث البيانات بنجاح' : 'تم رفض الطلب',
              style: AppTheme.cairoStyle(),
            ),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: AppTheme.cairoStyle())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'طلبات تعديل البيانات والملفات',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Live Search Bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'بحث بالاسم أو الحالة...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applySearch();
                    },
                  ),
                ),

                Expanded(
                  child: _filteredRequests.isEmpty
                      ? Center(
                          child: Text(
                            'لا يوجد طلبات تعديل معلقة حالياً.',
                            style: AppTheme.cairoStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final req = _filteredRequests[index];
                            final int reqId = req['id'] ?? 0;
                            final String studentName = req['studentName'] ?? req['fullName'] ?? 'طالب';
                            final String status = req['status'] ?? 'Pending';
                            final String requestedAt = req['requestedAt'] ?? '-';
                            final bool isPending = status == 'Pending' || status == 'معلق';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'طلب #$reqId: $studentName',
                                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Chip(
                                          label: Text(
                                            isPending ? 'معلق' : status,
                                            style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          backgroundColor: isPending ? Colors.orange : (status == 'Approved' ? Colors.green : Colors.red),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'التاريخ: $requestedAt',
                                      style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),

                                    if (req['changes'] != null) ...[
                                      Text(
                                        'التغييرات المطلوبة:',
                                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          req['changes'].toString(),
                                          style: AppTheme.cairoStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],

                                    if (isPending) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                            label: Text('رفض الطلب', style: AppTheme.cairoStyle(color: Colors.red)),
                                            onPressed: () => _processRequest(reqId, false),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                            label: Text('موافقة وتحديث', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            onPressed: () => _processRequest(reqId, true),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
