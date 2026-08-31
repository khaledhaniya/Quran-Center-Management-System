import 'package:flutter/material.dart';
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

  // Booleans
  bool _allowTeacherEditPlan = true;
  bool _allowTeacherEnrollment = true;
  bool _hideParentPhone = false;
  bool _allowProfileRequests = true;
  bool _enforceAttendance = true;
  bool _enableCertificates = true;
  bool _showHonorsBoard = true;
  bool _allowAnnouncements = true;
  bool _enableAbsenceAlert = true;
  bool _maintenanceMode = false;
  String _themeStyle = 'Classic';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final s = await ApiService.getSystemSettings();
      if (s != null) {
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

        _allowTeacherEditPlan = s['allowTeacherEditStudentPlan'] ?? s['AllowTeacherEditStudentPlan'] ?? true;
        _allowTeacherEnrollment = s['allowTeacherSelfEnrollment'] ?? s['AllowTeacherSelfEnrollment'] ?? true;
        _hideParentPhone = s['hideParentPhoneFromTeacher'] ?? s['HideParentPhoneFromTeacher'] ?? false;
        _allowProfileRequests = s['allowStudentProfileEditRequests'] ?? s['AllowStudentProfileEditRequests'] ?? true;
        _enforceAttendance = s['enforceDailyAttendanceRecording'] ?? s['EnforceDailyAttendanceRecording'] ?? true;
        _enableCertificates = s['enableCertificates'] ?? s['EnableCertificates'] ?? true;
        _showHonorsBoard = s['showHonorsBoard'] ?? s['ShowHonorsBoard'] ?? true;
        _allowAnnouncements = s['allowPublicAnnouncements'] ?? s['AllowPublicAnnouncements'] ?? true;
        _enableAbsenceAlert = s['enableAbsenceAutoAlert'] ?? s['EnableAbsenceAutoAlert'] ?? true;
        _maintenanceMode = s['maintenanceMode'] ?? s['MaintenanceMode'] ?? false;
        _themeStyle = s['themeStyle'] ?? s['ThemeStyle'] ?? 'Classic';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الإعدادات: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
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
      'passingScoreThreshold': int.tryParse(_passingScoreCtrl.text) ?? 70,
      'minAttendancePercentForExam': int.tryParse(_minAttendanceExamCtrl.text) ?? 75,
      'maxStudentsPerCircle': int.tryParse(_maxStudentsCircleCtrl.text) ?? 20,
      'maxAbsenceDaysWarning': int.tryParse(_maxAbsenceWarningCtrl.text) ?? 3,
      'allowTeacherEditStudentPlan': _allowTeacherEditPlan,
      'allowTeacherSelfEnrollment': _allowTeacherEnrollment,
      'hideParentPhoneFromTeacher': _hideParentPhone,
      'allowStudentProfileEditRequests': _allowProfileRequests,
      'enforceDailyAttendanceRecording': _enforceAttendance,
      'signatoryName': _signatoryNameCtrl.text.trim(),
      'signatoryTitle': _signatoryTitleCtrl.text.trim(),
      'enableCertificates': _enableCertificates,
      'showHonorsBoard': _showHonorsBoard,
      'allowPublicAnnouncements': _allowAnnouncements,
      'enableAbsenceAutoAlert': _enableAbsenceAlert,
      'absenceAlertTemplate': _absenceTemplateCtrl.text.trim(),
      'maintenanceMode': _maintenanceMode,
    };

    final ok = await ApiService.updateSystemSettings(data);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات المنظومة (CMS)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildIdentityTab(),
                _buildAcademicTab(),
                _buildPermissionsTab(),
                _buildCertificatesTab(),
                _buildAlertsTab(),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveSettings,
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
        _buildTextField(_centerNameCtrl, 'اسم مركز التحفيظ الرسمي', Icons.quran),
        _buildTextField(_mosqueNameCtrl, 'اسم المسجد التابع له', Icons.mosque),
        _buildTextField(_centerAddressCtrl, 'عنوان ومقر المركز', Icons.location_on),
        _buildTextField(_supportPhoneCtrl, 'رقم هاتف الدعم والتواصل', Icons.phone, keyboardType: TextInputType.phone),
        _buildTextField(_supportEmailCtrl, 'البريد الإلكتروني الرسمي', Icons.email, keyboardType: TextInputType.emailAddress),
        _buildTextField(_welcomeMsgCtrl, 'رسالة الترحيب والشعار العام', Icons.message, maxLines: 2),
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
        _buildSwitchTile('إلزامية تسجيل الحضور والغياب اليومي', 'تفعيل التحذيرات اليومية عند عدم تسجيل حضور الحلقة', _enforceAttendance, (v) => setState(() => _enforceAttendance = v)),
      ],
    );
  }

  Widget _buildCertificatesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('4. الشهادات ولوحة الشرف', Icons.military_tech),
        _buildSwitchTile('تفعيل إصدار الشهادات الإلكترونية', 'إتاحة توليد وتحميل شهادات الإجازة والاختبارات', _enableCertificates, (v) => setState(() => _enableCertificates = v)),
        _buildSwitchTile('عرض لوحة الشرف والمتميزين', 'إظهار قائمة أوائل الحفظة والمتميزين في التطبيق', _showHonorsBoard, (v) => setState(() => _showHonorsBoard = v)),
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
        const SizedBox(height: 12),
        _buildTextField(_absenceTemplateCtrl, 'نص رسالة تنبيه الغياب لولي الأمر (واتساب)', Icons.chat, maxLines: 3),
        _buildSwitchTile('وضع الصيانة للنظام', 'إظهار تنبيه بوجود أعمال صيانة دورية', _maintenanceMode, (v) => setState(() => _maintenanceMode = v)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
        activeColor: AppTheme.primary,
      ),
    );
  }
}
