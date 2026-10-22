import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;
  bool _isExporting = false;

  // Controllers
  final _centerNameCtrl = TextEditingController();
  final _mosqueNameCtrl = TextEditingController();
  final _centerAddressCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _welcomeMsgCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  final _passingScoreCtrl = TextEditingController(text: '70');
  final _minAttendanceExamCtrl = TextEditingController(text: '75');
  final _maxStudentsCircleCtrl = TextEditingController(text: '20');
  final _maxAbsenceWarningCtrl = TextEditingController(text: '3');

  final _signatoryNameCtrl = TextEditingController();
  final _signatoryTitleCtrl = TextEditingController();
  final _absenceTemplateCtrl = TextEditingController();
  final _recitationTemplateCtrl = TextEditingController();

  // Booleans
  bool _allowTeacherEditPlan = true;
  bool _allowTeacherEnrollment = true;
  bool _hideParentPhone = false;
  bool _allowProfileRequests = true;
  bool _enforceAttendance = true;
  bool _enableCertificates = true;
  bool _allowAnnouncements = true;
  bool _enableAbsenceAlert = true;
  bool _enableRecitationAlert = true;
  String _themeStyle = 'Classic';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _centerNameCtrl.dispose();
    _mosqueNameCtrl.dispose();
    _centerAddressCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _supportEmailCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _logoUrlCtrl.dispose();
    _passingScoreCtrl.dispose();
    _minAttendanceExamCtrl.dispose();
    _maxStudentsCircleCtrl.dispose();
    _maxAbsenceWarningCtrl.dispose();
    _signatoryNameCtrl.dispose();
    _signatoryTitleCtrl.dispose();
    _absenceTemplateCtrl.dispose();
    _recitationTemplateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() { _isLoading = true; _loadFailed = false; });
    try {
      final s = await ApiService.getSystemSettings();
      if (s == null) throw StateError('تعذر الاتصال بالخادم');
        _centerNameCtrl.text = (s['centerName'] ?? s['CenterName'] ?? '').toString();
        _mosqueNameCtrl.text = (s['mosqueName'] ?? s['MosqueName'] ?? '').toString();
        _centerAddressCtrl.text = (s['centerAddress'] ?? s['CenterAddress'] ?? '').toString();
        _supportPhoneCtrl.text = (s['supportPhone'] ?? s['SupportPhone'] ?? '').toString();
        _supportEmailCtrl.text = (s['supportEmail'] ?? s['SupportEmail'] ?? '').toString();
        _welcomeMsgCtrl.text = (s['welcomeMessage'] ?? s['WelcomeMessage'] ?? '').toString();
        _logoUrlCtrl.text = (s['logoUrl'] ?? s['LogoUrl'] ?? '').toString();

        _passingScoreCtrl.text = (s['passingScoreThreshold'] ?? s['PassingScoreThreshold'] ?? 70).toString();
        _minAttendanceExamCtrl.text = (s['minAttendancePercentForExam'] ?? s['MinAttendancePercentForExam'] ?? 75).toString();
        _maxStudentsCircleCtrl.text = (s['maxStudentsPerCircle'] ?? s['MaxStudentsPerCircle'] ?? 20).toString();
        _maxAbsenceWarningCtrl.text = (s['maxAbsenceDaysWarning'] ?? s['MaxAbsenceDaysWarning'] ?? 3).toString();

        _signatoryNameCtrl.text = (s['signatoryName'] ?? s['SignatoryName'] ?? '').toString();
        _signatoryTitleCtrl.text = (s['signatoryTitle'] ?? s['SignatoryTitle'] ?? '').toString();
        _absenceTemplateCtrl.text = (s['absenceAlertTemplate'] ?? s['AbsenceAlertTemplate'] ?? '').toString();
        _recitationTemplateCtrl.text = (s['recitationAlertTemplate'] ?? s['RecitationAlertTemplate'] ?? '').toString();

        _allowTeacherEditPlan = s['allowTeacherEditStudentPlan'] ?? s['AllowTeacherEditStudentPlan'] ?? true;
        _allowTeacherEnrollment = s['allowTeacherSelfEnrollment'] ?? s['AllowTeacherSelfEnrollment'] ?? true;
        _hideParentPhone = s['hideParentPhoneFromTeacher'] ?? s['HideParentPhoneFromTeacher'] ?? false;
        _allowProfileRequests = s['allowStudentProfileEditRequests'] ?? s['AllowStudentProfileEditRequests'] ?? true;
        _enforceAttendance = s['enforceDailyAttendanceRecording'] ?? s['EnforceDailyAttendanceRecording'] ?? true;
        _enableCertificates = s['enableCertificates'] ?? s['EnableCertificates'] ?? true;
        _allowAnnouncements = s['allowPublicAnnouncements'] ?? s['AllowPublicAnnouncements'] ?? true;
        _enableAbsenceAlert = s['enableAbsenceAutoAlert'] ?? s['EnableAbsenceAutoAlert'] ?? true;
        _enableRecitationAlert = s['enableRecitationIncompleteAlert'] ?? s['EnableRecitationIncompleteAlert'] ?? true;
        _themeStyle = s['themeStyle'] ?? s['ThemeStyle'] ?? 'Classic';
    } catch (e) {
      if (mounted) {
        setState(() => _loadFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الإعدادات: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    int? numeric(TextEditingController controller, int min, int max) {
      final value = int.tryParse(controller.text.trim());
      return value != null && value >= min && value <= max ? value : null;
    }
    final passing = numeric(_passingScoreCtrl, 50, 100);
    final attendance = numeric(_minAttendanceExamCtrl, 0, 100);
    final maxStudents = numeric(_maxStudentsCircleCtrl, 5, 50);
    final absenceDays = numeric(_maxAbsenceWarningCtrl, 1, 15);
    if (passing == null || attendance == null || maxStudents == null || absenceDays == null ||
        _centerNameCtrl.text.trim().isEmpty || _mosqueNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('راجع الحقول المطلوبة: النجاح 50–100، الحضور 0–100، الطلاب 5–50، الغياب 1–15.')));
      return;
    }
    setState(() => _isSaving = true);
    final data = {
      'centerName': _centerNameCtrl.text.trim(),
      'mosqueName': _mosqueNameCtrl.text.trim(),
      'centerAddress': _centerAddressCtrl.text.trim(),
      'supportPhone': _supportPhoneCtrl.text.trim(),
      'supportEmail': _supportEmailCtrl.text.trim(),
      'welcomeMessage': _welcomeMsgCtrl.text.trim(),
      'logoUrl': _logoUrlCtrl.text.trim(),
      'themeStyle': _themeStyle,
      'passingScoreThreshold': passing,
      'minAttendancePercentForExam': attendance,
      'maxStudentsPerCircle': maxStudents,
      'maxAbsenceDaysWarning': absenceDays,
      'allowTeacherEditStudentPlan': _allowTeacherEditPlan,
      'allowTeacherSelfEnrollment': _allowTeacherEnrollment,
      'hideParentPhoneFromTeacher': _hideParentPhone,
      'allowStudentProfileEditRequests': _allowProfileRequests,
      'enforceDailyAttendanceRecording': _enforceAttendance,
      'signatoryName': _signatoryNameCtrl.text.trim(),
      'signatoryTitle': _signatoryTitleCtrl.text.trim(),
      'enableCertificates': _enableCertificates,
      'allowPublicAnnouncements': _allowAnnouncements,
      'enableAbsenceAutoAlert': _enableAbsenceAlert,
      'absenceAlertTemplate': _absenceTemplateCtrl.text.trim(),
      'enableRecitationIncompleteAlert': _enableRecitationAlert,
      'recitationAlertTemplate': _recitationTemplateCtrl.text.trim(),
    };

    final ok = await ApiService.updateSystemSettings(data);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      AppTheme.setStyle(_themeStyle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ وتطبيق إعدادات المنظومة الشاملة بنجاح! 🎉'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل حفظ الإعدادات، يرجى التحقق من الاتصال بالخادم'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    final bytes = await ApiService.downloadSystemDataExport();
    if (!mounted) return;
    setState(() => _isExporting = false);
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنزيل ملف البيانات. تحقق من الاتصال والصلاحية.')));
      return;
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: 'application/json')],
        fileNameOverrides: ['quran_center_data_$date.json'],
        text: 'تصدير بيانات المركز الأساسية',
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح خيارات حفظ الملف.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات المنظومة (CMS)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.mosque), text: 'الهوية'),
            Tab(icon: Icon(Icons.school), text: 'المعايير'),
            Tab(icon: Icon(Icons.security), text: 'الصلاحيات'),
            Tab(icon: Icon(Icons.card_membership), text: 'الشهادات'),
            Tab(icon: Icon(Icons.notifications), text: 'التنبيهات'),
            Tab(icon: Icon(Icons.palette), text: 'المظهر'),
            Tab(icon: Icon(Icons.backup), text: 'البيانات'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('تعذر تحميل إعدادات المركز من الخادم.'),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _loadSettings, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            ]))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildIdentityTab(),
                _buildAcademicTab(),
                _buildPermissionsTab(),
                _buildCertificatesTab(),
                _buildAlertsTab(),
                _buildAppearanceTab(),
                _buildBackupTab(),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving || _isLoading || _loadFailed ? null : _saveSettings,
          icon: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(
            _isSaving ? 'جاري الحفظ...' : 'حفظ وتطبيق الإعدادات للمنظومة',
            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('1. هوية المركز وبيانات الاتصال', Icons.apartment),
        _buildTextField(_centerNameCtrl, 'اسم مركز التحفيظ الرسمي', Icons.menu_book),
        _buildTextField(_mosqueNameCtrl, 'اسم المسجد التابع له', Icons.mosque),
        _buildTextField(_centerAddressCtrl, 'عنوان ومقر المركز', Icons.location_on),
        _buildTextField(_supportPhoneCtrl, 'رقم هاتف الدعم والتواصل', Icons.phone, keyboardType: TextInputType.phone),
        _buildTextField(_supportEmailCtrl, 'البريد الإلكتروني الرسمي', Icons.email, keyboardType: TextInputType.emailAddress),
        _buildTextField(_welcomeMsgCtrl, 'رسالة الترحيب والشعار العام', Icons.message, maxLines: 2),
        _buildTextField(_logoUrlCtrl, 'رابط شعار المركز (HTTPS)', Icons.image, maxLines: 2),
      ],
    );
  }

  Widget _buildAcademicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('2. المعايير والضوابط الأكاديمية', Icons.auto_stories),
        _buildTextField(_passingScoreCtrl, 'الحد الأدنى لدرجة النجاح في الاختبار (%)', Icons.grade, keyboardType: TextInputType.number),
        _buildTextField(_minAttendanceExamCtrl, 'نسبة الحضور المطلوبة للترشح للاختبار (%)', Icons.percent, keyboardType: TextInputType.number),
        _buildTextField(_maxStudentsCircleCtrl, 'الحد الأقصى لعدد الطلاب في الحلقة القرآنية', Icons.groups, keyboardType: TextInputType.number),
        _buildTextField(_maxAbsenceWarningCtrl, 'أيام الغياب المتتالية لإصدار إنذار غياب', Icons.warning_amber, keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildPermissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('3. الصلاحيات والخصوصية', Icons.shield),
        _buildSwitchTile('السماح للمعلم بتعديل الخطة الدراسية للطالب', 'يمكن للمعلم تعديل خطة حفظ وتلاوة طلابه', _allowTeacherEditPlan, (v) => setState(() => _allowTeacherEditPlan = v)),
        _buildSwitchTile('السماح للمعلم بإسناد وتسجيل الطلاب بنفسه', 'يستطيع المعلم إضافة طالب جديد لحلقته مباشرة', _allowTeacherEnrollment, (v) => setState(() => _allowTeacherEnrollment = v)),
        _buildSwitchTile('إخفاء رقم هاتف ولي الأمر عن المعلم', 'لحماية الخصوصية ومنع التواصل المباشر دون إذن الإدارة', _hideParentPhone, (v) => setState(() => _hideParentPhone = v)),
        _buildSwitchTile('إتاحة طلبات تعديل البيانات لأولياء الأمور', 'تمكين ولي الأمر من طلب تعديل بيانات ابنه', _allowProfileRequests, (v) => setState(() => _allowProfileRequests = v)),
        _buildSwitchTile('حصر رصد المعلم في تاريخ اليوم', 'يمنع المعلم من رصد حضور أو تسميع بتاريخ سابق؛ يظل التصحيح الإداري متاحاً', _enforceAttendance, (v) => setState(() => _enforceAttendance = v)),
      ],
    );
  }

  Widget _buildCertificatesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('4. الشهادات', Icons.military_tech),
        _buildSwitchTile('تفعيل إصدار الشهادات الإلكترونية', 'إتاحة توليد وتحميل شهادات الإجازة والاختبارات', _enableCertificates, (v) => setState(() => _enableCertificates = v)),
        const SizedBox(height: 12),
        _buildTextField(_signatoryNameCtrl, 'اسم رئيس المركز / المعتمد للشهادات', Icons.person_pin),
        _buildTextField(_signatoryTitleCtrl, 'المسمى الوظيفي المعتمد في الشهادة', Icons.badge),
      ],
    );
  }

  Widget _buildAlertsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('5. التنبيهات والإشعارات والواتساب', Icons.notifications_active),
        _buildSwitchTile('تفعيل التنبيه التلقائي لغياب الطلاب', 'إتاحة زر إشعار ولي الأمر عبر الواتساب بنقرة واحدة', _enableAbsenceAlert, (v) => setState(() => _enableAbsenceAlert = v)),
        _buildSwitchTile('السماح بنشر الإعلانات العامة', 'إتاحة إرسال تعميمات لجميع المستخدمين والطلاب', _allowAnnouncements, (v) => setState(() => _allowAnnouncements = v)),
        _buildSwitchTile('تنبيه عدم التسميع', 'إرسال تنبيه عند عدم اكتمال التسميع', _enableRecitationAlert, (v) => setState(() => _enableRecitationAlert = v)),
        const SizedBox(height: 12),
        _buildTextField(_absenceTemplateCtrl, 'نص رسالة تنبيه الغياب لولي الأمر (واتساب)', Icons.chat, maxLines: 3),
        _buildTextField(_recitationTemplateCtrl, 'نص تنبيه عدم اكتمال التسميع', Icons.message, maxLines: 3),
      ],
    );
  }

  Widget _buildAppearanceTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _buildSectionHeader('6. مظهر التطبيق', Icons.palette),
    ...const [
      ('Classic', 'التراثي الأخضر', Color(0xFF0D5C3A)),
      ('Modern', 'الزمردي العصري', Color(0xFF059669)),
      ('Sapphire', 'الكحلي الملكي', Color(0xFF1E40AF)),
      ('Dark', 'الداكن', Color(0xFF0F172A)),
    ].map((option) => ListTile(
      title: Text(option.$2, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
      leading: CircleAvatar(backgroundColor: option.$3, radius: 14),
      trailing: _themeStyle == option.$1 ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
      selected: _themeStyle == option.$1,
      onTap: () => setState(() => _themeStyle = option.$1),
    )),
    const Padding(padding: EdgeInsets.all(12), child: Text('يُطبّق اللون المختار على عناصر واجهة التطبيق بعد الحفظ.')),
  ]);

  Widget _buildBackupTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _buildSectionHeader('7. تصدير بيانات المركز', Icons.backup),
    const Text('ملف JSON يحتوي على بيانات أساسية للأرشفة والمراجعة فقط. النسخة الكاملة القابلة للاستعادة هي ملف BAK من قاعدة البيانات في MonsterASP.'),
    const SizedBox(height: 18),
    FilledButton.icon(
      onPressed: _isExporting ? null : _exportData,
      icon: _isExporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
      label: Text(_isExporting ? 'جاري التجهيز...' : 'تنزيل البيانات الأساسية (JSON)'),
    ),
  ]);

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary))),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool val, ValueChanged<bool> onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      child: SwitchListTile(
        title: Text(title, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600)),
        value: val,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primary,
      ),
    );
  }
}
