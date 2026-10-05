import 'dart:convert';
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
  String _activeTab = 'all'; // all, pending, approved, rejected

  static const Map<String, Map<String, dynamic>> _fieldMeta = {
    'fullName': {'label': 'اسم الطالب الكامل', 'icon': Icons.person_rounded, 'color': Colors.blue},
    'studentIdentityNumber': {'label': 'رقم هوية الطالب', 'icon': Icons.badge_rounded, 'color': Colors.teal},
    'dateOfBirth': {'label': 'تاريخ الميلاد', 'icon': Icons.calendar_today_rounded, 'color': Colors.indigo},
    'previousQuranMemorization': {'label': 'الحفظ السابق من القرآن', 'icon': Icons.menu_book_rounded, 'color': Colors.green},
    'healthStatus': {'label': 'الحالة الصحية', 'icon': Icons.favorite_rounded, 'color': Colors.red},
    'kinship': {'label': 'صلة القرابة', 'icon': Icons.family_restroom_rounded, 'color': Colors.deepOrange},
    'parentIdentityNumber': {'label': 'رقم هوية ولي الأمر', 'icon': Icons.fingerprint_rounded, 'color': Colors.teal},
    'fatherStatus': {'label': 'حالة الأب', 'icon': Icons.person_outline_rounded, 'color': Colors.purple},
    'motherStatus': {'label': 'حالة الأم', 'icon': Icons.person_outline_rounded, 'color': Colors.purple},
    'familyContact': {'label': 'رقم جوال التواصل', 'icon': Icons.phone_rounded, 'color': Colors.green},
    'studentMobile': {'label': 'جوال الطالب', 'icon': Icons.phone_android_rounded, 'color': Colors.blue},
    'whatsappNumber': {'label': 'واتساب العائلة', 'icon': Icons.chat_bubble_rounded, 'color': Colors.green},
    'studentWhatsapp': {'label': 'واتس الطالب', 'icon': Icons.chat_bubble_rounded, 'color': Colors.green},
    'address': {'label': 'العنوان العام', 'icon': Icons.location_on_rounded, 'color': Colors.red},
    'currentAddress': {'label': 'عنوان السكن الحالي', 'icon': Icons.home_rounded, 'color': Colors.blueGrey},
    'currentHousingType': {'label': 'نوع السكن الحالي', 'icon': Icons.holiday_village_rounded, 'color': Colors.brown},
    'originalAddress': {'label': 'العنوان الأصلي قبل النزوح', 'icon': Icons.location_city_rounded, 'color': Colors.blueGrey},
    'originalHousingType': {'label': 'نوع السكن الأصلي', 'icon': Icons.apartment_rounded, 'color': Colors.brown},
    'originalHousingStatus': {'label': 'حالة السكن الأصلي', 'icon': Icons.warning_amber_rounded, 'color': Colors.amber},
    'walletNumber': {'label': 'رقم المحفظة المالية', 'icon': Icons.account_balance_wallet_rounded, 'color': Colors.amber},
    'bankAccountNumber': {'label': 'رقم الحساب البنكي', 'icon': Icons.account_balance_rounded, 'color': Colors.blue},
    'bankName': {'label': 'اسم البنك', 'icon': Icons.account_balance_rounded, 'color': Colors.indigo},
    'notes': {'label': 'ملاحظات وتفاصيل طلب التعديل', 'icon': Icons.edit_note_rounded, 'color': Colors.blueGrey},
  };

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
      _applyFilter();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    List<dynamic> list = _requests;

    if (_activeTab == 'pending') {
      list = list.where((r) => r['status'] == 'Pending' || r['status'] == 'معلق').toList();
    } else if (_activeTab == 'approved') {
      list = list.where((r) => r['status'] == 'Approved' || r['status'] == 'مقبول').toList();
    } else if (_activeTab == 'rejected') {
      list = list.where((r) => r['status'] == 'Rejected' || r['status'] == 'مرفوض').toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final name = (r['studentName'] ?? r['fullName'] ?? '').toString().toLowerCase();
        final reqName = (r['requestedByName'] ?? '').toString().toLowerCase();
        final id = (r['id'] ?? '').toString();
        return name.contains(q) || reqName.contains(q) || id.contains(q);
      }).toList();
    }

    setState(() {
      _filteredRequests = list;
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
              approve ? '✅ تم اعتماد التعديلات وتحديث بيانات الطالب بنجاح' : '❌ تم رفض طلب التعديل',
              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: approve ? const Color(0xFF15803D) : const Color(0xFFDC2626),
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء المعالجة: $e', style: AppTheme.cairoStyle()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r['status'] == 'Pending' || r['status'] == 'معلق').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'طلبات تعديل بيانات وملفات الطلاب',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث القائمة',
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Top Search & Tabs Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Search Field
                      TextField(
                        onChanged: (val) {
                          _searchQuery = val.trim();
                          _applyFilter();
                        },
                        style: AppTheme.cairoStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث باسم الطالب، رقم الطلب، أو اسم مقدم الطلب...',
                          hintStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Segmented Buttons
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterTab('all', 'الكل (${_requests.length})', null),
                            const SizedBox(width: 8),
                            _buildFilterTab('pending', 'قيد الانتظار', pendingCount > 0 ? pendingCount : null),
                            const SizedBox(width: 8),
                            _buildFilterTab('approved', 'المعتمدة', null),
                            const SizedBox(width: 8),
                            _buildFilterTab('rejected', 'المرفوضة', null),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Requests List
                Expanded(
                  child: _filteredRequests.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'لا توجد طلبات تطابق كلمة البحث'
                                      : 'لا توجد طلبات تعديل بيانات في هذه الفئة حالياً',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.cairoStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final req = _filteredRequests[index];
                            return _buildRequestCard(req);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTab(String key, String label, int? count) {
    final isSelected = _activeTab == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = key;
        });
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.cairoStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.shade400 : Colors.red.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic req) {
    final int reqId = req['id'] ?? 0;
    final String studentName = req['studentName'] ?? req['fullName'] ?? 'طالب';
    final String status = req['status'] ?? 'Pending';
    final String requestedByName = req['requestedByName'] ?? 'مقدم الطلب';
    final String requestedAt = req['requestedAt']?.toString() ?? '-';
    final bool isPending = status == 'Pending' || status == 'معلق';
    final bool isApproved = status == 'Approved' || status == 'مقبول';

    Map<String, dynamic> changesMap = {};
    if (req['changes'] != null) {
      if (req['changes'] is Map) {
        changesMap = Map<String, dynamic>.from(req['changes']);
      } else if (req['changes'] is String) {
        try {
          changesMap = Map<String, dynamic>.from(jsonDecode(req['changes']));
        } catch (_) {}
      }
    }

    Map<String, dynamic> currentData = {};
    if (req['currentStudentData'] != null && req['currentStudentData'] is Map) {
      currentData = Map<String, dynamic>.from(req['currentStudentData']);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFDE68A) : Colors.grey.shade200,
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Request Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_outline_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              studentName,
                              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '#$reqId',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مقدم الطلب: $requestedByName • ${requestedAt.length >= 10 ? requestedAt.substring(0, 10) : requestedAt}',
                        style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 14),

            // Diff Cards (Old vs New)
            if (changesMap.isNotEmpty) ...[
              Text(
                'الحقول المطلوب تعديلها ومقارنتها:',
                style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F3E28)),
              ),
              const SizedBox(height: 8),
              ...changesMap.entries.map((entry) {
                final fieldKey = entry.key;
                final newVal = entry.value?.toString() ?? '—';
                final oldVal = currentData[fieldKey]?.toString() ?? '— (غير مسجل)';
                final meta = _fieldMeta[fieldKey] ?? {
                  'label': fieldKey,
                  'icon': Icons.edit_note_rounded,
                  'color': Colors.blueGrey,
                };

                return _buildDiffCard(
                  meta['label'] as String,
                  meta['icon'] as IconData,
                  meta['color'] as Color,
                  oldVal,
                  newVal,
                );
              }),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'تفاصيل التعديل: ${req['notes'] ?? 'تحديث عام لملف الطالب'}',
                  style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],

            // Action Buttons (Only for Pending requests)
            if (isPending) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text('رفض الطلب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _processRequest(reqId, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('اعتماد وتحديث', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _processRequest(reqId, true),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiffCard(String label, IconData icon, Color color, String oldVal, String newVal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF1E293B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'حقل معدّل',
                  style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Old value vs New value layout
          Row(
            children: [
              // Old Value Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 12, color: Color(0xFF991B1B)),
                          const SizedBox(width: 4),
                          Text(
                            'القيمة السابقة:',
                            style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        oldVal,
                        style: AppTheme.cairoStyle(fontSize: 11.5, color: const Color(0xFF7F1D1D)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.blueGrey),
              ),
              // New Value Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF166534)),
                          const SizedBox(width: 4),
                          Text(
                            'القيمة الجديدة المقترحة:',
                            style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        newVal,
                        style: AppTheme.cairoStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF14532D)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    if (status == 'Pending' || status == 'معلق') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = 'قيد الانتظار';
    } else if (status == 'Approved' || status == 'مقبول') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'تم الاعتماد';
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'مرفوض';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
