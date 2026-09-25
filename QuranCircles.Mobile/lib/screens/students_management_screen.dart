import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/contact_helper.dart';
import 'student_360_screen.dart';

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  List<Circle> _circles = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  int? _selectedCircleFilter; // null = all
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'inactive', 'unassigned'

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
    try {
      final list = await ApiService.getStudents();
      final cList = await ApiService.getCircles();
      if (mounted) {
        setState(() {
          _students = list;
          _circles = cList;
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
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        // Query match
        bool queryMatch = true;
        if (q.isNotEmpty) {
          final nameMatch = s.fullName.toLowerCase().contains(q);
          final circleMatch = (s.circleName ?? '').toLowerCase().contains(q);
          final idMatch = (s.studentIdentityNumber ?? '').contains(q);
          final phoneMatch = (s.familyContact ?? '').contains(q) || (s.studentMobile ?? '').contains(q);
          queryMatch = nameMatch || circleMatch || idMatch || phoneMatch;
        }

        // Circle match
        bool circleMatch = true;
        if (_selectedCircleFilter != null) {
          circleMatch = s.circleId == _selectedCircleFilter;
        }

        // Status match
        bool statusMatch = true;
        if (_selectedStatusFilter == 'active') {
          statusMatch = s.isActive;
        } else if (_selectedStatusFilter == 'inactive') {
          statusMatch = !s.isActive;
        } else if (_selectedStatusFilter == 'unassigned') {
          statusMatch = s.circleId == null;
        }

        return queryMatch && circleMatch && statusMatch;
      }).toList();
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label: $text'),
        backgroundColor: const Color(0xFF0D5C3A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _launchWhatsApp(String phone) {
    ContactHelper.launchWhatsApp(context, phone);
  }

  void _launchPhone(String phone) {
    ContactHelper.launchDialer(context, phone);
  }

  void _showChangeCircleModal(Student s) {
    int? newCircleId = s.circleId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.sync_alt, color: Color(0xFF0D5C3A), size: 22),
              const SizedBox(width: 8),
              Text('نقل الطالب لحلقة أخرى', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الطالب: ${s.fullName}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0D5C3A))),
              Text('الحلقة الحالية: ${s.circleName ?? "غير مسند لحلقة"}', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: newCircleId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'اختر الحلقة الجديدة',
                  prefixIcon: const Icon(Icons.mosque_outlined, color: Color(0xFF0D5C3A)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('بدون حلقة (إلغاء التنسيب)', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  ..._circles.where((c) => c.isActive).map(
                    (c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(
                        '${c.name} (${c.teacherName})',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setDialogState(() => newCircleId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: AppTheme.cairoStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final ok = await ApiService.updateStudent(s.id, {'circleId': newCircleId});
                if (ok) {
                  _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نقل وتحديث حلقة الطالب بنجاح'), backgroundColor: Color(0xFF0D5C3A)),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر نقل الطالب، يرجى المحاولة مرة أخرى'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('حفظ النقل', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditStudentModal([Student? student]) {
    final nameController = TextEditingController(text: student?.fullName ?? '');
    final identityController = TextEditingController(text: student?.studentIdentityNumber ?? '');
    final dobController = TextEditingController(text: student?.dateOfBirth ?? '');
    final prevQuranController = TextEditingController(text: student?.previousQuranMemorization ?? '');
    final healthStatusController = TextEditingController(text: student?.healthStatus ?? 'سليم');

    final parentIdentityController = TextEditingController(text: student?.parentIdentityNumber ?? '');
    final kinshipController = TextEditingController(text: student?.kinship ?? 'أب');
    final contactController = TextEditingController(text: student?.familyContact ?? '');
    final studentMobileController = TextEditingController(text: student?.studentMobile ?? '');
    final studentWhatsappController = TextEditingController(text: student?.studentWhatsapp ?? student?.whatsappNumber ?? '');
    String fatherStatus = student?.fatherStatus ?? 'سليم';
    String motherStatus = student?.motherStatus ?? 'سليم';

    final addressController = TextEditingController(text: student?.address ?? student?.originalAddress ?? '');
    final currentAddressController = TextEditingController(text: student?.currentAddress ?? '');
    final notesController = TextEditingController(text: student?.notes ?? '');

    final usernameController = TextEditingController(text: student?.username ?? student?.studentIdentityNumber ?? '');
    final passwordController = TextEditingController(text: student == null ? '123456' : '');
    int? selectedCircleId = student?.circleId;
    int currentTab = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              child: Column(
                children: [
                  // Modal Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D5C3A), Color(0xFF134E48)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student == null ? 'إضافة طالب جديد وحساب دخول' : 'تعديل بيانات الطالب وحسابه',
                                style: AppTheme.cairoStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student == null
                                    ? 'تسجيل طالب جديد بالمنظومة وإسناد الحلقة وإنشاء حساب دخول'
                                    : 'تحديث بيانات الطالب، ولي الأمر، المسكن، وحساب الدخول',
                                style: AppTheme.cairoStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Segmented Tab Selector matching Web
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabBtn(0, '1. البيانات والحلقة', Icons.badge_outlined, currentTab, (i) => setModalState(() => currentTab = i)),
                          const SizedBox(width: 6),
                          _buildTabBtn(1, '2. العائلة والاتصال', Icons.people_outline, currentTab, (i) => setModalState(() => currentTab = i)),
                          const SizedBox(width: 6),
                          _buildTabBtn(2, '3. السكن والملاحظات', Icons.home_outlined, currentTab, (i) => setModalState(() => currentTab = i)),
                          const SizedBox(width: 6),
                          _buildTabBtn(3, '4. حساب الدخول', Icons.security_outlined, currentTab, (i) => setModalState(() => currentTab = i)),
                        ],
                      ),
                    ),
                  ),

                  // Modal Body Tab Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: IndexedStack(
                        index: currentTab,
                        children: [
                          // TAB 0: Personal & Circle
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('البيانات الشخصية والتعريفية للطالب'),
                              const SizedBox(height: 12),
                              TextField(
                                controller: nameController,
                                decoration: _inputDecoration('الاسم الرباعي الكامل للطالب *', Icons.person_outline),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: identityController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration('رقم هوية الطالب (9 أرقام)', Icons.credit_card),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: dobController,
                                      decoration: _inputDecoration('تاريخ الميلاد (YYYY-MM-DD)', Icons.calendar_today_outlined),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                value: selectedCircleId,
                                isExpanded: true,
                                decoration: _inputDecoration('الحلقة القرآنية المسندة', Icons.mosque_outlined),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('بدون حلقة (غير مسند لحلقة حالياً)', overflow: TextOverflow.ellipsis, maxLines: 1),
                                  ),
                                  ..._circles.map(
                                    (c) => DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(
                                        '${c.name} (${c.teacherName})',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) => setModalState(() => selectedCircleId = val),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: prevQuranController,
                                decoration: _inputDecoration('الحفظ السابق من القرآن (مثال: جزئين، 5 أجزاء)', Icons.menu_book_outlined),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: healthStatusController,
                                decoration: _inputDecoration('الحالة الصحية للطالب', Icons.favorite_border),
                              ),
                            ],
                          ),

                          // TAB 1: Family & Contacts
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('بيانات ولي الأمر والتواصل الأسري'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: parentIdentityController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration('رقم هوية ولي الأمر', Icons.badge_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: kinshipController,
                                      decoration: _inputDecoration('صلة القرابة (أب، أم، عم...)', Icons.family_restroom),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: contactController,
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration('هاتف العائلة الرئيسي *', Icons.phone_outlined),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: studentMobileController,
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration('جوال الطالب الشخصي', Icons.smartphone),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: studentWhatsappController,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration('رقم الواتساب للتواصل والتعاميم', Icons.chat_bubble_outline),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: ['سليم', 'شهيد', 'متوفي', 'أسير'].contains(fatherStatus) ? fatherStatus : 'سليم',
                                      isExpanded: true,
                                      decoration: _inputDecoration('حالة الأب', Icons.person_pin_outlined),
                                      items: const [
                                        DropdownMenuItem(value: 'سليم', child: Text('سليم (حي)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'شهيد', child: Text('شهيد', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'متوفي', child: Text('متوفي', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'أسير', child: Text('أسير', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setModalState(() => fatherStatus = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: ['سليم', 'شهيدة', 'متوفاة'].contains(motherStatus) ? motherStatus : 'سليم',
                                      isExpanded: true,
                                      decoration: _inputDecoration('حالة الأم', Icons.female),
                                      items: const [
                                        DropdownMenuItem(value: 'سليم', child: Text('سليمة (حية)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'شهيدة', child: Text('شهيدة', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'متوفاة', child: Text('متوفاة', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setModalState(() => motherStatus = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // TAB 2: Housing & Notes
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('بيانات السكن والنزوح والملاحظات'),
                              const SizedBox(height: 12),
                              TextField(
                                controller: addressController,
                                decoration: _inputDecoration('العنوان الأصلي', Icons.location_on_outlined),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: currentAddressController,
                                decoration: _inputDecoration('السكن الحالي / مركز الإيواء / النزوح', Icons.home_work_outlined),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: notesController,
                                maxLines: 3,
                                decoration: _inputDecoration('ملاحظات كفالة الأيتام والوضع العام', Icons.notes),
                              ),
                            ],
                          ),

                          // TAB 3: Account & Access
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('بيانات حساب دخول الطالب للمنظومة'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D5C3A).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0D5C3A).withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Color(0xFF0D5C3A), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'يتيح هذا الحساب للطالب أو ولي أمره الدخول ومتابعة درجات التسميع اليومي والخطط والشهادات.',
                                        style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF0D5C3A)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: usernameController,
                                decoration: _inputDecoration('اسم المستخدم للطالب (Username) *', Icons.alternate_email),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: passwordController,
                                decoration: _inputDecoration(
                                  student == null ? 'كلمة المرور للطالب * (الافتراضي 123456)' : 'كلمة مرور جديدة (اتركها فارغة لعدم التغيير)',
                                  Icons.lock_outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Modal Footer Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text('إلغاء', style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D5C3A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            student == null ? 'تسجيل وحفظ الطالب' : 'حفظ التعديلات الشاملة',
                            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يرجى إدخال اسم الطالب الرباعي'), backgroundColor: Colors.red),
                              );
                              setModalState(() => currentTab = 0);
                              return;
                            }

                            final payload = <String, dynamic>{
                              'fullName': nameController.text.trim(),
                              'studentIdentityNumber': identityController.text.trim().isNotEmpty ? identityController.text.trim() : null,
                              'parentIdentityNumber': parentIdentityController.text.trim().isNotEmpty ? parentIdentityController.text.trim() : null,
                              'address': addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                              'originalAddress': addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                              'currentAddress': currentAddressController.text.trim().isNotEmpty ? currentAddressController.text.trim() : null,
                              'familyContact': contactController.text.trim(),
                              'studentMobile': studentMobileController.text.trim().isNotEmpty ? studentMobileController.text.trim() : null,
                              'studentWhatsapp': studentWhatsappController.text.trim().isNotEmpty ? studentWhatsappController.text.trim() : null,
                              'healthStatus': healthStatusController.text.trim().isNotEmpty ? healthStatusController.text.trim() : 'سليم',
                              'previousQuranMemorization': prevQuranController.text.trim().isNotEmpty ? prevQuranController.text.trim() : null,
                              'kinship': kinshipController.text.trim().isNotEmpty ? kinshipController.text.trim() : null,
                              'fatherStatus': fatherStatus,
                              'motherStatus': motherStatus,
                              'circleId': selectedCircleId,
                              'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                              'username': usernameController.text.trim().isNotEmpty
                                  ? usernameController.text.trim()
                                  : (identityController.text.trim().isNotEmpty ? identityController.text.trim() : null),
                            };
                            if (dobController.text.trim().isNotEmpty) {
                              payload['dateOfBirth'] = dobController.text.trim();
                            }
                            if (passwordController.text.trim().isNotEmpty) {
                              payload['password'] = passwordController.text.trim();
                            }

                            if (student == null) {
                              final ok = await ApiService.createStudent(payload);
                              if (!dialogCtx.mounted) return;
                              Navigator.pop(dialogCtx);
                              if (ok) {
                                _loadData();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تسجيل وإضافة الطالب بنجاح'), backgroundColor: Color(0xFF0D5C3A)),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تعذر إضافة الطالب، يرجى التحقق من صحة البيانات'), backgroundColor: Colors.red),
                                );
                              }
                            } else {
                              final ok = await ApiService.updateStudent(student.id, payload);
                              if (!dialogCtx.mounted) return;
                              Navigator.pop(dialogCtx);
                              if (ok) {
                                _loadData();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تحديث كافة بيانات الطالب بنجاح'), backgroundColor: Color(0xFF0D5C3A)),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تعذر حفظ بيانات الطالب، يرجى مراجعة البيانات المدخلة'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildTabBtn(int index, String label, IconData icon, int currentTab, Function(int) onSelect) {
    final isSelected = currentTab == index;
    return InkWell(
      onTap: () => onSelect(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D5C3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0D5C3A) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.cairoStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF0D5C3A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C3A)),
        ),
      ],
    );
  }

  static InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700),
      prefixIcon: Icon(icon, color: const Color(0xFF0D5C3A), size: 18),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D5C3A), width: 1.8)),
    );
  }

  void _toggleStudentStatus(Student s) async {
    final actionText = s.isActive ? 'تعطيل' : 'تنشيط';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تأكيد $actionText حساب الطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من $actionText حساب الطالب (${s.fullName})؟', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: s.isActive ? Colors.red : const Color(0xFF0D5C3A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.toggleStudentActive(s.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $actionText حساب الطالب بنجاح'), backgroundColor: const Color(0xFF0D5C3A)),
        );
      }
    }
  }

  void _confirmHardDelete(Student s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تحذير: حذف نهائي للطالب', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد تماماً من رغبتك في حذف الطالب (${s.fullName}) نهائياً من قاعدة البيانات؟ لا يمكن التراجع عن هذا الإجراء.', style: AppTheme.cairoStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.hardDeleteStudent(s.id);
      if (ok) {
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الطالب نهائياً وتسجيل الإجراء في الرقابة الأمنية'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = _students.length;
    final activeStudents = _students.where((s) => s.isActive).length;
    final unassignedStudents = _students.where((s) => s.circleId == null).length;
    final orphanStudents = _students.where((s) => s.fatherStatus != null && s.fatherStatus != 'سليم').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة الطلاب والانتساب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث القائمة',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditStudentModal(),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text('تسجيل طالب جديد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: CustomScrollView(
                slivers: [
                  // Hero Header Banner
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF0F766E)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      'سجلات الطلاب والانتساب',
                                      style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'إدارة الطلاب المنتسبين للمركز',
                            style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'بيانات الطلاب، خطط الحفظ، بطاقة الطالب الشاملة 360°، الحلقات والتسميع اليومي.',
                            style: AppTheme.cairoStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                          const SizedBox(height: 16),
                          // 4 Mini-Counter Stats
                          Row(
                            children: [
                              _buildMiniStat('إجمالي الطلاب', '$totalStudents', Icons.groups, Colors.blue),
                              const SizedBox(width: 8),
                              _buildMiniStat('المنتظمون', '$activeStudents', Icons.verified, const Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              _buildMiniStat('بدون حلقة', '$unassignedStudents', Icons.pending_actions, Colors.amber.shade800),
                              const SizedBox(width: 8),
                              _buildMiniStat('أيتام/رعاية', '$orphanStudents', Icons.volunteer_activism, const Color(0xFFE11D48)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search & Quick Filter Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              // Search input
                              TextField(
                                controller: _searchController,
                                onChanged: (_) => _applyFilters(),
                                decoration: InputDecoration(
                                  hintText: 'ابحث باسم الطالب، رقم الهوية، أو الحلقة...',
                                  hintStyle: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0D5C3A)),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Circle Dropdown Filter + Status Chips
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int?>(
                                      value: _selectedCircleFilter,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.filter_list, size: 18, color: Color(0xFF0D5C3A)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                                      ),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('جميع الحلقات القرآنية', overflow: TextOverflow.ellipsis, maxLines: 1),
                                        ),
                                        ..._circles.map(
                                          (c) => DropdownMenuItem<int?>(
                                            value: c.id,
                                            child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        _selectedCircleFilter = val;
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Status Filter Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('الكل (${_students.length})', 'all'),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('النشطون ($activeStudents)', 'active'),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('بدون حلقة ($unassignedStudents)', 'unassigned'),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('المعطلون (${_students.length - activeStudents})', 'inactive'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Results header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'قائمة الطلاب (${_filteredStudents.length})',
                            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0D5C3A)),
                          ),
                          Text(
                            'طالب مسجل',
                            style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Student Cards List
                  _filteredStudents.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(32),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'لا يوجد طلاب مطابقون لمعايير البحث والفلترة',
                                  style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) {
                                final s = _filteredStudents[index];
                                return _buildStudentCard(s);
                              },
                              childCount: _filteredStudents.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedStatusFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: const Color(0xFF0D5C3A),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF0D5C3A) : Colors.grey.shade300),
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatusFilter = filterKey);
          _applyFilters();
        }
      },
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              label,
              style: AppTheme.cairoStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student s) {
    final hasFatherIssue = s.fatherStatus != null && s.fatherStatus != 'سليم';
    final hasCircle = s.circleId != null && s.circleName != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar + Name (SINGLE LINE) + Status Pill
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF0D5C3A),
                  child: Text(
                    s.fullName.isNotEmpty ? s.fullName[0] : 'ط',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SINGLE LINE STUDENT NAME
                      Text(
                        s.fullName,
                        style: AppTheme.cairoStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: const Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (s.studentIdentityNumber != null && s.studentIdentityNumber!.isNotEmpty) ...[
                            InkWell(
                              onTap: () => _copyToClipboard(s.studentIdentityNumber!, 'رقم هوية الطالب'),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.credit_card, size: 10, color: Color(0xFF0D5C3A)),
                                    const SizedBox(width: 3),
                                    Text(
                                      s.studentIdentityNumber!,
                                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.copy, size: 9, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (hasFatherIssue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                'ابن ${s.fatherStatus}',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.isActive ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: s.isActive ? const Color(0xFF10B981) : Colors.red),
                  ),
                  child: Text(
                    s.isActive ? 'نشط' : 'معطّل',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: s.isActive ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Circle Badge & Contacts
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasCircle ? const Color(0xFF0D5C3A).withValues(alpha: 0.05) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasCircle ? const Color(0xFF0D5C3A).withValues(alpha: 0.15) : Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(hasCircle ? Icons.mosque_outlined : Icons.warning_amber_rounded, size: 14, color: hasCircle ? const Color(0xFF0D5C3A) : Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasCircle ? 'الحلقة: ${s.circleName}' : '⚠️ غير مسند لحلقة قرآنية',
                      style: AppTheme.cairoStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: hasCircle ? const Color(0xFF0D5C3A) : Colors.amber.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (s.familyContact != null && s.familyContact!.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.phone, size: 16, color: Color(0xFF0D5C3A)),
                      tooltip: 'اتصال بولي الأمر (${s.familyContact})',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _launchPhone(s.familyContact!),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF10B981)),
                      tooltip: 'واتساب ولي الأمر',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _launchWhatsApp(s.studentWhatsapp ?? s.familyContact!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Row 3: Action Buttons
            Row(
              children: [
                // 360 View Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C3A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => Student360Screen(initialStudentId: s.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: Text('ملف 360°', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                // Reassign circle button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showChangeCircleModal(s),
                  icon: const Icon(Icons.sync_alt, size: 13, color: Color(0xFF0D5C3A)),
                  label: Text('نقل الحلقة', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF0D5C3A))),
                ),
                const Spacer(),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                  tooltip: 'تعديل البيانات الشاملة',
                  onPressed: () => _showAddEditStudentModal(s),
                ),
                // Toggle active/inactive
                IconButton(
                  icon: Icon(
                    s.isActive ? Icons.block : Icons.check_circle_outline,
                    color: s.isActive ? Colors.orange : const Color(0xFF10B981),
                    size: 18,
                  ),
                  tooltip: s.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                  onPressed: () => _toggleStudentStatus(s),
                ),
                // Hard delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: 'حذف نهائي من النظام',
                  onPressed: () => _confirmHardDelete(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
