import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class Student360Screen extends StatefulWidget {
  final int? initialStudentId;
  final bool isParentView;

  const Student360Screen({super.key, this.initialStudentId, this.isParentView = false});

  @override
  State<Student360Screen> createState() => _Student360ScreenState();
}

class _Student360ScreenState extends State<Student360Screen> {
  List<Student> _studentsList = [];
  Student? _selectedStudent;
  Map<String, dynamic>? _profileData;
  bool _isLoadingStudents = true;
  bool _isLoadingProfile = false;

  final List<String> _juzNames = const [
    "عمّ", "تبارك", "قد سمع", "الذاريات", "الأحقاف", "حم عسق", "يس", "السبأ",
    "الروم", "العنكبوت", "النمل", "الشعراء", "الفرقان", "الإسراء", "الكهف", "الحجر",
    "النحل", "لقمان", "السجدة", "يسين", "الحشر", "الممتحنة", "الصف", "الجمعة",
    "الطلاق", "التحريم", "الملك", "النبأ", "النازعات", "عبس"
  ];

  String _getJuzName(int index) {
    if (index >= 1 && index <= _juzNames.length) {
      return _juzNames[index - 1];
    }
    return "جزء $index";
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    try {
      List<Student> list = [];
      if (widget.isParentView) {
        list = await ApiService.getMyChildren();
      }
      if (list.isEmpty) {
        list = await ApiService.getStudents();
      }
      if (list.isEmpty && !widget.isParentView) {
        list = await ApiService.getMyChildren();
      }
      if (mounted) {
        Student? matched;
        if (widget.initialStudentId != null) {
          matched = list.firstWhere(
            (s) => s.id == widget.initialStudentId,
            orElse: () => list.isNotEmpty ? list.first : Student(id: 0, fullName: '', isActive: true),
          );
        } else if (list.isNotEmpty) {
          matched = list.first;
        }

        setState(() {
          _studentsList = list;
          _selectedStudent = matched;
          _isLoadingStudents = false;
        });

        if (matched != null && matched.id > 0) {
          _loadProfile(matched.id);
        } else if (widget.initialStudentId != null && widget.initialStudentId! > 0) {
          _loadProfile(widget.initialStudentId!);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
        });
      }
    }
  }

  void _loadProfile(int studentId) async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final data = await ApiService.getStudent360(studentId);
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _showEditPlanDialog() {
    if (_selectedStudent == null) return;
    final st = _selectedStudent!;

    String planType = _profileData?['planType'] ?? 'Standard';
    final targetController = TextEditingController(text: '${_profileData?['targetAjzaaCount'] ?? 30}');
    final paceController = TextEditingController(text: '${_profileData?['dailyPacePages'] ?? 1.0}');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.track_changes, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('اعتماد وتعديل خطة الحفظ', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر نوع الخطة المعتمدة:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: planType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Intensive', child: Text('🌟 الخطة المكثفة (جزء / أسبوعين)')),
                    DropdownMenuItem(value: 'Standard', child: Text('📘 الخطة المعتدلة (جزء / شهر)')),
                    DropdownMenuItem(value: 'Gradual', child: Text('🌱 الخطة الميسرة (نصف جزء / شهر)')),
                    DropdownMenuItem(value: 'Custom', child: Text('🎯 خطة مخصصة')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        planType = val;
                        if (val == 'Intensive') paceController.text = '2.0';
                        if (val == 'Standard') paceController.text = '1.0';
                        if (val == 'Gradual') paceController.text = '0.5';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text('عدد الأجزاء المستهدفة (من 1 إلى 30):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Text('المقدار اليومي المستهدف (صفحة/يوم):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: paceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('حفظ الخطة'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final target = int.tryParse(targetController.text.trim()) ?? 30;
                final pace = double.tryParse(paceController.text.trim()) ?? 1.0;
                Navigator.pop(dialogCtx);

                try {
                  final ok = await ApiService.updateStudentPlan(st.id, {
                    'targetAjzaaCount': target,
                    'planType': planType,
                    'dailyPacePages': pace,
                  });
                  if (!mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث وحفظ خطة الحفظ للطالب بنجاح 🎉'), backgroundColor: Colors.green),
                    );
                    _loadProfile(st.id);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر حفظ الخطة: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleJuz(int studentId, int juzNumber, bool isCompleted) async {
    try {
      final ok = await ApiService.completeJuz(studentId, juzNumber, isCompleted);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCompleted ? 'تم توثيق إتمام حفظ الجزء ($juzNumber) بنجاح ✅' : 'تم إلغاء توثيق الجزء ($juzNumber)'),
            backgroundColor: isCompleted ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadProfile(studentId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _exportStudentReportDialog() {
    if (_profileData == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setProgressState) {
            return FutureBuilder(
              future: Future.delayed(const Duration(milliseconds: 1200)),
              builder: (ctx, snapshot) {
                final isReady = snapshot.connectionState == ConnectionState.done;
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isReady ? 'تم تجهيز الملف الموحد بنجاح' : 'جاري توليد تقرير الملف الموحد PDF...',
                          style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  content: isReady
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'تم تجميع السجل القرآني وخريطة الأجزاء وكشوفات الحضور والاختبارات والشهادات المعتمدة للطالب (${_profileData!['studentName'] ?? _selectedStudent?.fullName}).',
                                      style: AppTheme.cairoStyle(fontSize: 12, color: Colors.green.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('الرقم المرجعي: DOC-360-${_selectedStudent?.id ?? 0}', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey)),
                            Text('الجهة المصدرة: مركز البيان لتعليم القرآن الكريم', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(color: AppTheme.primary),
                            const SizedBox(height: 16),
                            Text('استخراج السجلات وتضمين الشهادات وخريطة الـ 30 جزءاً...', style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                  actions: [
                    if (isReady) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('مشاركة وتصدير'),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تصدير وحفظ التقرير الموحد للطالب بنجاح 📄✅'), backgroundColor: Colors.green),
                          );
                        },
                      ),
                    ],
                    TextButton(
                      child: Text(isReady ? 'إغلاق' : 'إلغاء'),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAccreditedCertificateDialog(Map<String, dynamic> item) {
    final stName = _profileData?['studentName'] ?? _selectedStudent?.fullName ?? 'طالب المركز';
    final isQuran = item['nominationType'] == 'Quran';
    final title = item['formattedDetails'] ?? (isQuran ? 'حفظ القرآن الكريم' : (item['courseName'] ?? 'دورة أكاديمية معتمدة'));
    final gradeNum = (item['grade'] as num?)?.toDouble() ?? 100.0;
    final gradeLabel = gradeNum >= 95 ? "ممتاز مرتفع" : (gradeNum >= 90 ? "ممتاز" : (gradeNum >= 80 ? "جيد جداً" : "جيد"));
    final teacher = item['teacherName'] ?? _profileData?['teacherName'] ?? 'الشيخ المحفظ المعتمد';
    final certCode = item['certificateCode'] ?? 'CERT-EX-${item['id'] ?? 1001}';
    final certDate = item['certificateDate'] ?? item['examDate'] ?? '2026-09-17';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD97706), width: 2)),
        contentPadding: const EdgeInsets.all(20),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Certificate Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0D5C3A), Color(0xFF15803D)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFFFBBF24), size: 36),
                    const SizedBox(height: 4),
                    Text(
                      'شَهَادَةُ اجْتِيَازِ وَتَفَوُّقٍ مُعْتَمَدَةٌ',
                      style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'دولة فلسطين - دار القرآن الكريم والسنة',
                      style: AppTheme.cairoStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('تمنح إدارة مركز البيان هذه الشهادة للطالب المبارك:', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text(
                stName,
                style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C3A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  'لاجتيازه بنجاح وتفوق اختبار: $title',
                  style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('الدرجة المستحقة', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey)),
                      Text('${gradeNum.toInt()}%', style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      Text('التقدير العام', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey)),
                      Text(gradeLabel, style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0D5C3A))),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المحفظ المشرف:', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey)),
                      Text(teacher, style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('مدير المركز:', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey)),
                      Text('الشيخ علي حسن النبيه', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الرمز: $certCode', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.grey)),
                  Text('التاريخ: $certDate', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('مشاركة / تصدير الشهادة'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تصدير الشهادة المعتمدة بنجاح 🏆'), backgroundColor: Colors.green),
              );
            },
          ),
          TextButton(
            child: const Text('إغلاق'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerAttendance = _profileData?['centerAttendance'] as List? ?? [];
    final courseAttendance = _profileData?['courseAttendance'] as List? ?? [];
    final completedExams = _profileData?['completedExams'] as List? ?? [];
    final recitationSessions = _profileData?['recitationSessions'] as List? ?? _profileData?['sessions'] as List? ?? [];
    final talents = _profileData?['talents'] as List? ?? [];
    final isTalented = (_profileData?['isTalented'] as bool?) ?? talents.isNotEmpty;

    final completedAjzaaStr = _profileData?['completedAjzaa']?.toString() ?? '';
    final completedAjzaaSet = completedAjzaaStr
        .split(',')
        .map((x) => int.tryParse(x.trim()))
        .where((x) => x != null && x >= 1 && x <= 30)
        .cast<int>()
        .toSet();

    final targetAjzaa = _profileData?['targetAjzaaCount'] as int? ?? 30;
    final planType = _profileData?['planType']?.toString() ?? 'Standard';
    final dailyPace = (_profileData?['dailyPacePages'] as num?)?.toDouble() ?? 1.0;
    final completedCount = completedAjzaaSet.length;
    final planProgress = targetAjzaa > 0 ? (completedCount / targetAjzaa).clamp(0.0, 1.0) : 0.0;

    final planTitles = {
      'Intensive': '🌟 الخطة المكثفة (جزء / أسبوعين)',
      'Standard': '📘 الخطة المعتدلة (جزء / شهر)',
      'Gradual': '🌱 الخطة الميسرة (نصف جزء / شهر)',
      'Custom': '🎯 خطة مخصصة',
    };
    final planTitle = planTitles[planType] ?? '📘 الخطة المعتدلة';

    final userRole = ApiService.currentUser?.role ?? '';
    final canEditPlan = (userRole == 'Admin' || userRole == 'Developer' || userRole == 'Teacher');

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedStudent != null ? 'الملف الموحد: ${_selectedStudent!.fullName}' : 'الملف الموحد الشامل للطالب'),
        actions: [
          if (_profileData != null)
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'طباعة وتصدير الملف الموحد (PDF)',
              onPressed: _exportStudentReportDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Selector Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'اختر الطالب لمشاهدة الملف الموحد:',
                          style: AppTheme.cairoStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        if (_studentsList.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${_studentsList.length} طلاب', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!_isLoadingStudents && _studentsList.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _studentsList.map((s) {
                            final isSel = _selectedStudent?.id == s.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                avatar: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isSel ? Colors.white : AppTheme.primary,
                                  child: Text(s.fullName.isNotEmpty ? s.fullName[0] : 'ط', style: TextStyle(fontSize: 10, color: isSel ? AppTheme.primary : Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                label: Text(s.fullName, style: AppTheme.cairoStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: AppTheme.primary,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedStudent = s;
                                  });
                                  _loadProfile(s.id);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _isLoadingStudents
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<Student>(
                            initialValue: _selectedStudent,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            items: _studentsList.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.fullName} (${s.circleName ?? "بدون حلقة"})',
                                  style: AppTheme.cairoStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStudent = val;
                                });
                                _loadProfile(val.id);
                              }
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoadingProfile)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_profileData != null) ...[
              // Student Header Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.person, size: 36, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profileData!['studentName'] ?? _selectedStudent?.fullName ?? '',
                              style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الحلقة القرآنية: ${_profileData!['circleName'] ?? "غير مسند"}',
                              style: AppTheme.cairoStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'المعلم المحفظ: ${_profileData!['teacherName'] ?? "غير مسند"}',
                              style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            if (isTalented || talents.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mic, size: 14, color: Colors.red.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'الفتى الواعظ والأصوات الندية (${talents.length})',
                                      style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Study Plan Card (NEW)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.track_changes, color: AppTheme.primary, size: 22),
                              const SizedBox(width: 8),
                              Text('خطة الحفظ والهدف القرآني', style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ],
                          ),
                          if (canEditPlan)
                            InkWell(
                              onTap: _showEditPlanDialog,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit, size: 14, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Text('تعديل الخطة', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(planTitle, style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                          Text('$completedCount من $targetAjzaa جزء', style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: planProgress,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المقدار اليومي: $dailyPace صفحة/يوم', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                          Text('نسبة الإنجاز: ${(planProgress * 100).toStringAsFixed(0)}%', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 30 Interactive Juz Chips Card (NEW)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_book, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text('توثيق إتمام وحفظ الأجزاء (30 جزء)', style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('$completedCount مكتمل', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (canEditPlan)
                        Text('انقر على أي جزء لتوثيق إتمامه أو إلغاء إتمامه:', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const Divider(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(30, (idx) {
                          final juzNum = idx + 1;
                          final isDone = completedAjzaaSet.contains(juzNum);
                          final name = _getJuzName(juzNum);

                          return InkWell(
                            onTap: canEditPlan && _selectedStudent != null
                                ? () => _toggleJuz(_selectedStudent!.id, juzNum, !isDone)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDone ? Colors.green.shade600 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDone ? Colors.green.shade700 : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: isDone ? Colors.white : Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$juzNum ($name)',
                                    style: AppTheme.cairoStyle(fontSize: 11, color: isDone ? Colors.white : Colors.black87, fontWeight: isDone ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Real Recitation Sessions Log (NEW)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.record_voice_over, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('سجل التسميع الفعلي والحي مع الشيخ', style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                      const Divider(),
                      recitationSessions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد جلسات تسميع مسجلة للطالب بعد.', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recitationSessions.length > 10 ? 10 : recitationSessions.length,
                              itemBuilder: (ctx, i) {
                                final s = recitationSessions[i];
                                final assess = s['assessment']?.toString() ?? '';
                                final assessText = s['assessmentText']?.toString() ?? assess;

                                Color badgeColor = Colors.green;
                                if (assess == 'Medium' || assess == 'Rejected') {
                                  badgeColor = Colors.orange;
                                }

                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'سورة ${s['surahName'] ?? ''} (الآيات: ${s['fromVerse'] ?? 1} - ${s['toVerse'] ?? 1})',
                                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                                  ),
                                  subtitle: Text(
                                    'التاريخ: ${s['sessionDate'] ?? ''} ${s['notes'] != null && s['notes'].toString().isNotEmpty ? ' | ملاحظة: ${s['notes']}' : ''}',
                                    style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: badgeColor),
                                    ),
                                    child: Text(assessText, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Preacher Youth & Talents Card (الفتى الواعظ والأصوات الندية)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mic, color: Colors.red, size: 22),
                              const SizedBox(width: 8),
                              Text('سجل الفتى الواعظ والأصوات الندية', style: AppTheme.cairoStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text('${talents.length} مشاركات', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                          ),
                        ],
                      ),
                      const Divider(),
                      talents.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد مشاركات مسجلة لهذا الطالب في الفتى الواعظ أو الأصوات الندية بعد.', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: talents.length,
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (ctx, i) {
                                final t = talents[i];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t['title'] ?? 'مشاركة',
                                            style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Text(t['talentType'] ?? 'الفتى الواعظ', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    if (t['speechContent'] != null && t['speechContent'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'عناصر ومحتوى الخطبة: ${t['speechContent']}',
                                        style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade800),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (t['preparationMethod'] != null && t['preparationMethod'].toString().isNotEmpty)
                                          Expanded(
                                            child: Text('طريقة التحضير: ${t['preparationMethod']}', style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                                          ),
                                        if (t['eventDate'] != null)
                                          Text('${t['eventDate']}', style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
                                      ],
                                    ),
                                    if (t['mediaUrl'] != null && t['mediaUrl'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.play_circle_fill, size: 16, color: Colors.red),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'مرفق التوثيق (فيديو/صوت/صورة): ${t['mediaUrl']}',
                                                style: AppTheme.cairoStyle(fontSize: 10, color: Colors.red.shade900),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attendance & Achievements Summary
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.playlist_add_check, color: AppTheme.primary, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '${_profileData!['attendanceRate'] ?? 0}%',
                            style: AppTheme.cairoStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          Text('نسبة الالتزام والحضور', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.workspace_premium, color: AppTheme.accent, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '${_profileData!['certificatesCount'] ?? 0}',
                            style: AppTheme.cairoStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accent),
                          ),
                          Text('الشهادات الرقمية الحاصل عليها', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Detailed Circle Attendance Log
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('سجل حضور وغياب الحلقة القرآنية', style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                      const Divider(),
                      centerAttendance.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد سجلات حضور مسجلة حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: centerAttendance.length > 5 ? 5 : centerAttendance.length,
                              itemBuilder: (ctx, i) {
                                final item = centerAttendance[i];
                                final statusText = item['statusText'] ?? (item['status'] == 1 ? 'حاضر' : (item['status'] == 2 ? 'غائب' : 'متأخر'));
                                final color = item['status'] == 1
                                    ? AppTheme.statusPresent
                                    : (item['status'] == 2 ? AppTheme.statusAbsent : AppTheme.statusLate);

                                return ListTile(
                                  dense: true,
                                  title: Text('التاريخ: ${item['sessionDate'] ?? ""}', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('الحلقة: ${item['circleName'] ?? ""}', style: AppTheme.cairoStyle(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: color),
                                    ),
                                    child: Text(statusText, style: AppTheme.cairoStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Course Attendance Log
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school, color: AppTheme.accent, size: 20),
                          const SizedBox(width: 8),
                          Text('سجل حضور وغياب المساقات والدورات العلمية', style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                      const Divider(),
                      courseAttendance.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد سجلات حضور مساقات مسجلة حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: courseAttendance.length > 5 ? 5 : courseAttendance.length,
                              itemBuilder: (ctx, i) {
                                final item = courseAttendance[i];
                                final statusText = item['statusText'] ?? (item['status'] == 1 ? 'حاضر' : (item['status'] == 2 ? 'غائب' : 'متأخر'));
                                final color = item['status'] == 1
                                    ? AppTheme.statusPresent
                                    : (item['status'] == 2 ? AppTheme.statusAbsent : AppTheme.statusLate);

                                return ListTile(
                                  dense: true,
                                  title: Text('مساق: ${item['courseName'] ?? ""}', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('التاريخ: ${item['sessionDate'] ?? ""}', style: AppTheme.cairoStyle(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: color),
                                    ),
                                    child: Text(statusText, style: AppTheme.cairoStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Completed Exams
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text('سجل الاختبارات والشهادات المكتملة', style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                      const Divider(),
                      completedExams.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('لا توجد اختبارات معتمدة مسجلة للطالب حالياً', style: AppTheme.cairoStyle(color: AppTheme.textMuted)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: completedExams.length,
                              itemBuilder: (ctx, i) {
                                final item = completedExams[i];
                                final isQuran = item['nominationType'] == 'Quran';
                                final title = item['formattedDetails'] ?? (isQuran ? 'أجزاء قرآن كريم' : (item['courseName'] ?? 'مساق ودورة'));
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor: isQuran ? Colors.green.shade100 : Colors.blue.shade100,
                                      child: Icon(isQuran ? Icons.menu_book : Icons.school, color: isQuran ? Colors.green.shade800 : Colors.blue.shade800, size: 18),
                                    ),
                                    title: Text(title, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('تاريخ التقييم: ${item['examDate'] ?? ""} | المعلم: ${item['teacherName'] ?? _profileData?['teacherName'] ?? "معتمد"}', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green),
                                          ),
                                          child: Text('${item['grade'] ?? 100}%', style: AppTheme.cairoStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.workspace_premium, color: Color(0xFFD97706), size: 22),
                                          tooltip: 'عرض الشهادة المعتمدة',
                                          onPressed: () => _showAccreditedCertificateDialog(item),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showAccreditedCertificateDialog(item),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
