import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({Key? key}) : super(key: key);

  @override
  State<FinancialManagementScreen> createState() => _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _transactions = [];
  List<dynamic> _filteredTransactions = [];

  String _searchQuery = '';
  int? _selectedType; // null: all, 1: income, 2: expense
  int? _selectedPaymentMethod; // null: all, 1: cash, 2: app, 3: bank

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summaryFuture = ApiService.getFinancialSummary();
      final transFuture = ApiService.getFinancialTransactions(
        type: _selectedType,
        paymentMethod: _selectedPaymentMethod,
      );

      final results = await Future.wait([summaryFuture, transFuture]);
      _summary = results[0] as Map<String, dynamic>;
      _transactions = results[1] as List<dynamic>;
      _applyFilter();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء تحميل البيانات المالية: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      if (_searchQuery.trim().isEmpty) {
        _filteredTransactions = List.from(_transactions);
      } else {
        final q = _searchQuery.trim().toLowerCase();
        _filteredTransactions = _transactions.where((t) {
          final title = (t['title'] ?? '').toString().toLowerCase();
          final donor = (t['donorName'] ?? '').toString().toLowerCase();
          final source = (t['donorSource'] ?? '').toString().toLowerCase();
          final recipient = (t['recipientName'] ?? '').toString().toLowerCase();
          final notes = (t['notes'] ?? '').toString().toLowerCase();
          return title.contains(q) || donor.contains(q) || source.contains(q) || recipient.contains(q) || notes.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'سجل الصندوق والمالية',
            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF0D5C3A),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D5C3A)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF0D5C3A),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // KPI Summary Cards
                    _buildKpiSummaryGrid(),

                    const SizedBox(height: 16),

                    // Quick Action Buttons
                    _buildActionButtons(),

                    const SizedBox(height: 16),

                    // Search & Filters
                    _buildFilterToolbar(),

                    const SizedBox(height: 12),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'كشف الحركات المالية (${_filteredTransactions.length})',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Transactions List
                    if (_filteredTransactions.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildTransactionCard(_filteredTransactions[i]),
                      ),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddTransactionModal(defaultIsIncome: true),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_circle_outline),
          label: Text('سند جديد', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildKpiSummaryGrid() {
    final income = (_summary['totalIncome'] ?? 0).toDouble();
    final expense = (_summary['totalExpense'] ?? 0).toDouble();
    final balance = (_summary['netBalance'] ?? 0).toDouble();
    final cash = (_summary['cashBalance'] ?? 0).toDouble();
    final app = (_summary['appBalance'] ?? 0).toDouble();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'الواردات والتبرعات',
                amount: '$income ₪',
                icon: Icons.arrow_downward_rounded,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
                amountColor: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'المصروفات والنفقات',
                amount: '$expense ₪',
                icon: Icons.arrow_upward_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                amountColor: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'صافي رصيد الصندوق',
                amount: '$balance ₪',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFDBEAFE),
                amountColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('توزيع الرصيد', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text('💵 كاش: $cash ₪', style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    Text('📱 تطبيق: $app ₪', style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(amount, style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.w800, color: amountColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showAddTransactionModal(defaultIsIncome: true),
            icon: const Icon(Icons.add_circle, size: 18),
            label: Text('تسجيل وارد / تبرع', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showAddTransactionModal(defaultIsIncome: false),
            icon: const Icon(Icons.remove_circle, size: 18),
            label: Text('تسجيل مصروف', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applyFilter();
            },
            decoration: InputDecoration(
              hintText: 'بحث بالمتبرع، طرف التبرع، المستلم، أو البيان...',
              hintStyle: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D5C3A), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedType,
                      isExpanded: true,
                      style: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF1E293B)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('كل الحركات')),
                        DropdownMenuItem(value: 1, child: Text('🟢 وارد وتبرع')),
                        DropdownMenuItem(value: 2, child: Text('🔴 مصروف فقط')),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedType = val);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedPaymentMethod,
                      isExpanded: true,
                      style: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF1E293B)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('طريقة الدفع: الكل')),
                        DropdownMenuItem(value: 1, child: Text('💵 كاش (نقداً)')),
                        DropdownMenuItem(value: 2, child: Text('📱 تطبيق إلكتروني')),
                        DropdownMenuItem(value: 3, child: Text('🏦 تحويل بنكي')),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedPaymentMethod = val);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'لا توجد معاملات مسجلة',
            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكنك تسجيل وارد أو مصروف جديد باستخدام الأزرار أعلاه.',
            style: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(dynamic item) {
    final isIncome = item['type'] == 1 || item['type'] == 'Income';
    final amount = (item['amount'] ?? 0).toDouble();
    final title = item['title'] ?? 'بدون عنوان';
    final date = (item['transactionDate'] ?? '').toString().split('T').first;
    final method = item['paymentMethod'];

    String methodText = 'كاش';
    if (method == 2 || method == 'AppWallet') {
      methodText = 'تطبيق إلكتروني';
    } else if (method == 3 || method == 'Bank') {
      methodText = 'تحويل بنكي';
    }

    final donorName = item['donorName'];
    final donorSource = item['donorSource'];
    final recipient = item['recipientName'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isIncome ? '🟢 سند قبض (وارد/تبرع)' : '🔴 سند صرف (مصروف)',
                  style: AppTheme.cairoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'} $amount ₪',
                style: AppTheme.cairoStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('📅 $date', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF64748B))),
              Text('💳 $methodText', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF64748B))),
              if (isIncome && donorName != null && donorName.toString().isNotEmpty)
                Text('👤 المتبرع: $donorName', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
              if (isIncome && donorSource != null && donorSource.toString().isNotEmpty)
                Text('🤝 طرف: $donorSource', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF0D5C3A), fontWeight: FontWeight.w600)),
              if (!isIncome && recipient != null && recipient.toString().isNotEmpty)
                Text('📍 المستلم: $recipient', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                tooltip: 'حذف السند',
                onPressed: () => _confirmDeleteTransaction(item['id']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تأكيد الحذف', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من رغبتك في حذف هذا السند المالي؟ سيتم تعديل أرصدة الصندوق تلقائياً.', style: AppTheme.cairoStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              child: const Text('حذف السند'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteFinancialTransaction(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف السند المالي بنجاح')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حذف السند المالي')),
        );
      }
    }
  }

  void _showAddTransactionModal({required bool defaultIsIncome}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTransactionBottomSheet(
        isIncome: defaultIsIncome,
        onSuccess: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }
}

class _AddTransactionBottomSheet extends StatefulWidget {
  final bool isIncome;
  final VoidCallback onSuccess;

  const _AddTransactionBottomSheet({
    Key? key,
    required this.isIncome,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<_AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends State<_AddTransactionBottomSheet> {
  late bool _isIncome;
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _donorNameController = TextEditingController();
  final _donorSourceController = TextEditingController();
  final _recipientController = TextEditingController();
  final _notesController = TextEditingController();
  final _refController = TextEditingController();

  int _paymentMethod = 1; // 1: Cash, 2: App, 3: Bank
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.isIncome;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح أكبر من صفر')),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة البيان / الشرح')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'type': _isIncome ? 1 : 2,
      'amount': amount,
      'currency': 'ILS',
      'title': title,
      'paymentMethod': _paymentMethod,
      'transactionDate': _selectedDate.toIso8601String(),
      'category': _isIncome ? 'تبرعات عامة للمركز' : 'مصروفات تشغيلية',
      'donorName': _isIncome ? _donorNameController.text.trim() : null,
      'donorSource': _isIncome ? _donorSourceController.text.trim() : null,
      'recipientName': !_isIncome ? _recipientController.text.trim() : null,
      'referenceNumber': _refController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    final success = await ApiService.createFinancialTransaction(payload);
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل السند المالي في الصندوق بنجاح 💰')),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تسجيل السند')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text(
                _isIncome ? '🟢 تسجيل وارد مالي / تبرع' : '🔴 تسجيل مصروف / صادر مالي',
                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
              ),
              const SizedBox(height: 14),

              // Type Switcher
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text('وارد / تبرع', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold))),
                      selected: _isIncome,
                      selectedColor: const Color(0xFFDCFCE7),
                      onSelected: (val) => setState(() => _isIncome = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text('مصروف ونفقة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold))),
                      selected: !_isIncome,
                      selectedColor: const Color(0xFFFEE2E2),
                      onSelected: (val) => setState(() => _isIncome = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Amount & Date
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C3A)),
                      decoration: InputDecoration(
                        labelText: 'المبلغ (شيكل ₪) *',
                        labelStyle: AppTheme.cairoStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
                        child: Text('📅 ${_selectedDate.toIso8601String().split('T').first}', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'البيان / الشرح *',
                  labelStyle: AppTheme.cairoStyle(fontSize: 12),
                  hintText: 'مثال: تبرع كفالة حلقة / شراء قرطاسية...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Payment Method
              DropdownButtonFormField<int>(
                value: _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'طريقة الدفع *',
                  labelStyle: AppTheme.cairoStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('💵 كاش (نقداً)')),
                  DropdownMenuItem(value: 2, child: Text('📱 تطبيق ومحفظة إلكترونية (Jawwal Pay / PalPay)')),
                  DropdownMenuItem(value: 3, child: Text('🏦 تحويل / حساب بنكي')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: 12),

              // Income Fields
              if (_isIncome) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _donorNameController,
                        decoration: InputDecoration(
                          labelText: 'اسم المتبرع (اختياري)',
                          hintText: 'فاعل خير',
                          labelStyle: AppTheme.cairoStyle(fontSize: 11),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _donorSourceController,
                        decoration: InputDecoration(
                          labelText: 'طرف مين التبرع؟',
                          hintText: 'طرف فلان',
                          labelStyle: AppTheme.cairoStyle(fontSize: 11),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Expense Fields
                TextField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: 'المستلم / لمن صُرفت المصاري؟',
                    hintText: 'اسم المستلم أو المحل أو الجهة...',
                    labelStyle: AppTheme.cairoStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('حفظ وتسجيل السند', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
