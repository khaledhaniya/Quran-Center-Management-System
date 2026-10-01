import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeacherComprehensiveReportScreen extends StatefulWidget {
  final User currentUser;
  const TeacherComprehensiveReportScreen({super.key, required this.currentUser});

  @override
  State<TeacherComprehensiveReportScreen> createState() => _TeacherComprehensiveReportScreenState();
}

class _TeacherComprehensiveReportScreenState extends State<TeacherComprehensiveReportScreen> {
  bool _isLoading = true;
  int? _teacherId;
  String _circleName = '';
  String _teacherName = '';

  // Filter Console
  String _selectedPeriod = 'all'; // all, today, this_week, current_month, last_month, custom
  DateTime? _fromDate;
  DateTime? _toDate;
  String _searchQuery = '';
  String _activeView = 'matrix'; // 'matrix' or 'cards'

  // Report Data
  List<Map<String, dynamic>> _studentsData = [];
  final Map<String, String> _dayNotes = {}; // date -> note/holiday

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      int tId = 0;
      if (widget.currentUser.teacherId != null && widget.currentUser.teacherId! > 0) {
        tId = widget.currentUser.teacherId!;
      } else {
        final teachers = await ApiService.getTeachers();
        final match = teachers.firstWhere(
          (t) => t.fullName.trim() == widget.currentUser.fullName.trim(),
          orElse: () => teachers.isNotEmpty ? teachers.first : Teacher(id: 0, fullName: widget.currentUser.fullName, isActive: true),
        );
        tId = match.id;
      }
      _teacherId = tId;

      String? fDate = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      String? tDate = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;

      final data = await ApiService.getTeacherComprehensiveReport(tId, fromDate: fDate, toDate: tDate);
      if (mounted) {
        setState(() {
          _circleName = data['circleName'] ?? 'حلقة القرآن';
          _teacherName = data['teacherName'] ?? widget.currentUser.fullName;
          final List rawStudents = data['students'] ?? [];
          _studentsData = rawStudents.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب الكشف: $e', style: AppTheme.cairoStyle())));
      }
    }
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();
      if (period == 'all') {
        _fromDate = null;
        _toDate = null;
      } else if (period == 'today') {
        _fromDate = now;
        _toDate = now;
      } else if (period == 'this_week') {
        _fromDate = now.subtract(Duration(days: now.weekday % 7));
        _toDate = now;
      } else if (period == 'current_month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = now;
      } else if (period == 'last_month') {
        _fromDate = DateTime(now.year, now.month - 1, 1);
        _toDate = DateTime(now.year, now.month, 0);
      }
    });
    _loadReport();
  }

  Future<void> _exportPdf() async {
    if (_teacherId == null) return;
    try {
      final fDate = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final tDate = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;
      final url = ApiService.getTeacherReportDownloadUrl(_teacherId!, 'pdf', fromDate: fDate, toDate: tDate);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط PDF')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _exportExcel() async {
    if (_teacherId == null) return;
    try {
      final fDate = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final tDate = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;
      final url = ApiService.getTeacherReportDownloadUrl(_teacherId!, 'excel', fromDate: fDate, toDate: tDate);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط Excel')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showAddDayNoteModal() {
    DateTime noteDate = DateTime.now();
    final noteController = TextEditingController(text: 'إجازة رسمية');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('إضافة ملاحظة يوم / إجازة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر اليوم واكتب سبب الملاحظة (سيظهر لجميع طلاب الحلقة في الكشف):', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: noteDate, firstDate: DateTime(2024), lastDate: DateTime(2027));
                  if (picked != null) setDlgState(() => noteDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(noteDate)}', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'الملاحظة / الإجازة:',
                  hintText: 'مثلاً: عطلة العيد، صيانة المسجد...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: AppTheme.cairoStyle())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () {
                final dStr = DateFormat('yyyy-MM-dd').format(noteDate);
                setState(() {
                  _dayNotes[dStr] = noteController.text.trim();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تثبيت ملاحظة اليوم في الكشف', style: AppTheme.cairoStyle())));
              },
              child: Text('تثبيت', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Compute Matrix & KPI Stats
    final dateSet = <String>{};
    for (var s in _studentsData) {
      final sessions = (s['recitationSessions'] ?? s['sessions'] ?? []) as List;
      for (var rs in sessions) {
        final d = rs['sessionDate'] ?? rs['date'];
        if (d != null) dateSet.add(d.toString());
      }
      final attendances = (s['attendanceRecords'] ?? []) as List;
      for (var a in attendances) {
        final d = a['sessionDate'] ?? a['date'];
        if (d != null) dateSet.add(d.toString());
      }
    }
    dateSet.addAll(_dayNotes.keys);
    final sortedDates = dateSet.toList()..sort();

    int totalSessionsCount = 0;
    int totalPresentCount = 0;
    int totalAttCount = 0;

    for (var s in _studentsData) {
      final sessions = (s['recitationSessions'] ?? s['sessions'] ?? []) as List;
      totalSessionsCount += sessions.length;
      final attendances = (s['attendanceRecords'] ?? []) as List;
      for (var a in attendances) {
        totalAttCount++;
        final st = a['status'];
        final stText = (a['statusText'] ?? '').toString();
        if (st == 1 || st == 3 || stText.contains('حاضر') || stText.contains('متأخر')) {
          totalPresentCount++;
        }
      }
    }

    final avgAttendance = totalAttCount > 0 ? ((totalPresentCount / totalAttCount) * 100).round() : 100;

    // Filter students by search
    final displayedStudents = _studentsData.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final name = (s['studentName'] ?? s['fullName'] ?? '').toString().toLowerCase();
      final idNum = (s['studentIdentityNumber'] ?? s['studentId'] ?? '').toString();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || idNum.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('كشف متابعة وتسميع طلاب الحلقة الشامل', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Luxury Header Hero Hub (Matches Web .roster-header-hub-2026)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D3B26), Color(0xFF1B6B48)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.table_chart, color: Colors.amber, size: 24),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('كشف متابعة وتسميع طلاب الحلقة الشامل', style: AppTheme.cairoStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    Text('السجل القرآني الذكي 2026 • $_circleName (الشيخ: $_teacherName)', style: AppTheme.cairoStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Action Buttons Group (Note, Excel, PDF, Refresh)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                icon: const Icon(Icons.event_note, size: 16),
                                label: Text('ملاحظة يوم / إجازة', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _showAddDayNoteModal,
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                icon: const Icon(Icons.file_download, size: 16),
                                label: Text('تصدير إكسل (XLSX)', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _exportExcel,
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: Text('طباعة الكشف (PDF)', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _exportPdf,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                tooltip: 'تحديث الكشف',
                                onPressed: _loadReport,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Filter Console (Matches Web .roster-filter-console-2026)
                    Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedPeriod,
                                    decoration: InputDecoration(
                                      labelText: 'النطاق الزمني:',
                                      labelStyle: AppTheme.cairoStyle(fontSize: 11),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    items: [
                                      DropdownMenuItem(value: 'all', child: Text('كامل الفترة المسجلة', style: AppTheme.cairoStyle(fontSize: 11))),
                                      DropdownMenuItem(value: 'today', child: Text('اليوم الحالي', style: AppTheme.cairoStyle(fontSize: 11))),
                                      DropdownMenuItem(value: 'this_week', child: Text('هذا الأسبوع', style: AppTheme.cairoStyle(fontSize: 11))),
                                      DropdownMenuItem(value: 'current_month', child: Text('الشهر الحالي', style: AppTheme.cairoStyle(fontSize: 11))),
                                      DropdownMenuItem(value: 'last_month', child: Text('الشهر السابق', style: AppTheme.cairoStyle(fontSize: 11))),
                                      DropdownMenuItem(value: 'custom', child: Text('نطاق مخصص (من - إلى)', style: AppTheme.cairoStyle(fontSize: 11))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) _onPeriodChanged(val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedPeriod == 'custom') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final picked = await showDatePicker(context: context, initialDate: _fromDate ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime.now());
                                        if (picked != null) {
                                          setState(() => _fromDate = picked);
                                          _loadReport();
                                        }
                                      },
                                      child: Text(_fromDate != null ? 'من: ${DateFormat('yyyy-MM-dd').format(_fromDate!)}' : 'من تاريخ', style: AppTheme.cairoStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final picked = await showDatePicker(context: context, initialDate: _toDate ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime.now());
                                        if (picked != null) {
                                          setState(() => _toDate = picked);
                                          _loadReport();
                                        }
                                      },
                                      child: Text(_toDate != null ? 'إلى: ${DateFormat('yyyy-MM-dd').format(_toDate!)}' : 'إلى تاريخ', style: AppTheme.cairoStyle(fontSize: 11)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Quick Student Search
                            TextField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 18),
                                hintText: 'بحث سريع باسم الطالب أو الهوية...',
                                hintStyle: AppTheme.cairoStyle(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. KPI Stat Cards Grid (Matches Web .roster-kpi-grid-2026)
                    Row(
                      children: [
                        _buildKpiCard('طلاب الحلقة', '${_studentsData.length}', Colors.green, Icons.people),
                        const SizedBox(width: 8),
                        _buildKpiCard('جلسات التسميع', '$totalSessionsCount', Colors.blue, Icons.book_online),
                        const SizedBox(width: 8),
                        _buildKpiCard('نسبة الحضور', '$avgAttendance%', Colors.purple, Icons.pie_chart),
                        const SizedBox(width: 8),
                        _buildKpiCard('أيام التسميع', '${sortedDates.length}', Colors.amber.shade900, Icons.calendar_today),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 4. View Switcher & Legend (Matches Web .roster-tools-bar-2026)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              _buildSegBtn('matrix', 'مصفوفة التسميع اليومية', Icons.table_view),
                              _buildSegBtn('cards', 'كروت الطلاب التراكمية', Icons.badge),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Legend dots
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildLegendItem('تسميع منجز', Colors.green),
                        _buildLegendItem('لم يحفظ', Colors.red),
                        _buildLegendItem('غياب', Colors.grey),
                        _buildLegendItem('إجازة / ملاحظة', Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. ON-SCREEN MATRIX VIEW (Matching Web table)
                    if (_activeView == 'matrix')
                      _buildOnScreenMatrixTable(displayedStudents, sortedDates)
                    else
                      _buildCumulativeCardsView(displayedStudents),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(label, style: AppTheme.cairoStyle(fontSize: 9.5, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSegBtn(String key, String title, IconData icon) {
    final isSelected = _activeView == key;
    return InkWell(
      onTap: () => setState(() => _activeView = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? AppTheme.primary : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(title, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primary : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.cairoStyle(fontSize: 10, color: Colors.grey.shade700)),
      ],
    );
  }

  // -----------------------------------------------------------------
  // On-Screen Recitation Matrix Table (Interactive, Scrollable Both Ways)
  // -----------------------------------------------------------------
  Widget _buildOnScreenMatrixTable(List<Map<String, dynamic>> students, List<String> dates) {
    if (students.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(child: Text('لا توجد بيانات طلاب مطابقة في هذا النطاق', style: AppTheme.cairoStyle())),
        ),
      );
    }

    if (dates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.calendar_today, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                Text('لا توجد جلسات تسميع موثقة في هذا النطاق الزمني', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                Text('اختر "كامل الفترة المسجلة" لعرض كافة السجلات', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF0D3B26)),
              headingTextStyle: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              dataTextStyle: AppTheme.cairoStyle(fontSize: 10.5),
              columnSpacing: 12,
              horizontalMargin: 12,
              columns: [
                const DataColumn(label: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('اسم الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ...dates.expand((d) => [
                      DataColumn(label: Text('$d\n(حفظ)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9.5))),
                      DataColumn(label: Text('$d\n(مراجعة)', textAlign: TextAlign.center, style: const TextStyle(color: Colors.amberAccent, fontSize: 9.5))),
                    ]),
                const DataColumn(label: Text('الحضور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
              rows: students.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final sName = s['studentName'] ?? s['fullName'] ?? 'طالب';

                final sessions = (s['recitationSessions'] ?? s['sessions'] ?? []) as List;
                final attendances = (s['attendanceRecords'] ?? []) as List;

                int presentCount = 0;
                for (var a in attendances) {
                  final st = a['status'];
                  final stTxt = (a['statusText'] ?? '').toString();
                  if (st == 1 || st == 3 || stTxt.contains('حاضر') || stTxt.contains('متأخر')) {
                    presentCount++;
                  }
                }

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) => idx.isEven ? Colors.grey.shade50 : Colors.white),
                  cells: [
                    DataCell(Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(sName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    ...dates.expand((d) {
                      final dayNote = _dayNotes[d];
                      if (dayNote != null) {
                        return [
                          DataCell(Text(dayNote, style: const TextStyle(color: Colors.amber, fontSize: 9))),
                          DataCell(Text(dayNote, style: const TextStyle(color: Colors.amber, fontSize: 9))),
                        ];
                      }

                      // Check attendance for this date
                      final att = attendances.firstWhere((a) => (a['sessionDate'] ?? a['date']) == d, orElse: () => null);
                      final isAbsent = att != null && (att['status'] == 2 || (att['statusText'] ?? '').toString().contains('غائب'));

                      if (isAbsent) {
                        return [
                          const DataCell(Text('غياب', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10))),
                          const DataCell(Text('غياب', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10))),
                        ];
                      }

                      // Find day sessions
                      final daySessions = sessions.where((rs) => (rs['sessionDate'] ?? rs['date']) == d).toList();

                      // Memorization sessions
                      final memSess = daySessions.where((rs) {
                        final t = rs['recitationType'];
                        final txt = (rs['recitationTypeText'] ?? '').toString();
                        return t == 1 || t == '1' || txt.contains('حفظ') || !txt.contains('مراجعة');
                      }).toList();

                      // Revision sessions
                      final revSess = daySessions.where((rs) {
                        final t = rs['recitationType'];
                        final txt = (rs['recitationTypeText'] ?? '').toString();
                        return t == 2 || t == '2' || txt.contains('مراجعة') || txt.contains('تثبيت');
                      }).toList();

                      String memText = 'لم يحفظ';
                      Color memColor = Colors.grey.shade500;
                      if (memSess.isNotEmpty) {
                        final last = memSess.last;
                        final surah = last['surahName'] ?? '';
                        final fromV = last['fromVerse'] ?? '';
                        final toV = last['toVerse'] ?? '';
                        final assess = last['assessmentText'] ?? last['assessment'] ?? '';
                        memText = '$surah ($fromV-$toV) [$assess]';
                        memColor = Colors.green.shade900;
                      }

                      String revText = 'لم يراجع';
                      Color revColor = Colors.grey.shade500;
                      if (revSess.isNotEmpty) {
                        final last = revSess.last;
                        final surah = last['surahName'] ?? '';
                        final fromV = last['fromVerse'] ?? '';
                        final toV = last['toVerse'] ?? '';
                        final assess = last['assessmentText'] ?? last['assessment'] ?? '';
                        revText = '$surah ($fromV-$toV) [$assess]';
                        revColor = Colors.orange.shade900;
                      }

                      return [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(memText, style: TextStyle(color: memColor, fontSize: 9.5, fontWeight: memSess.isNotEmpty ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(revText, style: TextStyle(color: revColor, fontSize: 9.5, fontWeight: revSess.isNotEmpty ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ];
                    }),
                    DataCell(
                      Text('$presentCount / ${dates.length}', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Mobile Cumulative Cards View
  // -----------------------------------------------------------------
  Widget _buildCumulativeCardsView(List<Map<String, dynamic>> students) {
    if (students.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(child: Text('لا توجد بيانات', style: AppTheme.cairoStyle())),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final s = students[idx];
        final sName = s['studentName'] ?? s['fullName'] ?? 'طالب';
        final sessions = (s['recitationSessions'] ?? s['sessions'] ?? []) as List;
        final attendances = (s['attendanceRecords'] ?? []) as List;

        int presentCount = 0;
        for (var a in attendances) {
          final st = a['status'];
          final stTxt = (a['statusText'] ?? '').toString();
          if (st == 1 || st == 3 || stTxt.contains('حاضر') || stTxt.contains('متأخر')) {
            presentCount++;
          }
        }

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('حضور: $presentCount يوم', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('إجمالي التسميعات المسجلة: ${sessions.length}', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700)),
                const Divider(height: 16),
                if (sessions.isEmpty)
                  Text('لا توجد جلسات تسميع لهذا الطالب في هذا النطاق', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sessions.take(3).map((rs) {
                      final surah = rs['surahName'] ?? '';
                      final fromV = rs['fromVerse'] ?? 0;
                      final toV = rs['toVerse'] ?? 0;
                      final date = rs['sessionDate'] ?? rs['date'] ?? '';
                      final assess = rs['assessmentText'] ?? rs['assessment'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• سورة $surah ($fromV-$toV)', style: AppTheme.cairoStyle(fontSize: 11)),
                            Text('$date [$assess]', style: AppTheme.cairoStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
