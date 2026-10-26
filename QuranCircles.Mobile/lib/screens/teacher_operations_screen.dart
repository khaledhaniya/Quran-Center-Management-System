import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'teacher_sessions_screen.dart';
import 'teacher_attendance_screen.dart';
import '../theme/app_theme.dart';

class TeacherOperationsScreen extends StatefulWidget {
  final int? circleId;
  const TeacherOperationsScreen({super.key, this.circleId});
  @override
  State<TeacherOperationsScreen> createState() =>
      _TeacherOperationsScreenState();
}

class _TeacherOperationsScreenState extends State<TeacherOperationsScreen> {
  String selectedDate = '';
  String fromDate = '';
  int? circle;
  final search = TextEditingController();
  List<Circle> circles = [];
  List<dynamic> rows = [];
  bool loading = true;
  bool tableView = true;
  String? error;
  bool get canEdit =>
      ['Admin', 'Developer'].contains(ApiService.currentUser?.role) ||
      ApiService.currentUser?.isQualitySupervisor == true;
  @override
  void initState() {
    super.initState();
    circle = widget.circleId;
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Map<String, dynamic> get reportFilter => {
        'kind': 'teacher_discipline',
        'from': fromDate,
        'to': selectedDate,
        'circleId': circle,
        'search': search.text.trim()
      };
  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (selectedDate.isEmpty) {
        final clock = await ApiService.centerOperation('today');
        selectedDate = clock['date'];
        fromDate = DateTime.parse(selectedDate).subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
      }
      if (DateTime.parse(selectedDate).difference(DateTime.parse(fromDate)).inDays < 0 ||
          DateTime.parse(selectedDate).difference(DateTime.parse(fromDate)).inDays > 92) {
        throw Exception('حدد فترة صحيحة لا تتجاوز 92 يوماً');
      }
      final query = Uri(
          queryParameters: reportFilter.entries
              .where((e) => e.key != 'kind' && e.value != null)
              .fold<Map<String, String>>(
                  {}, (map, e) => map..[e.key] = e.value.toString())).query;
      final results = await Future.wait<Object?>([
        ApiService.getCircles(),
        ApiService.centerOperation('teacher-attendance?$query')
      ]);
      if (mounted) {
        setState(() {
          circles = results[0] as List<Circle>;
          rows = results[1] as List;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> chooseDate({bool start = false}) async {
    final clock = await ApiService.centerOperation('today');
    if (!mounted) return;
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(start ? fromDate : selectedDate),
        firstDate: DateTime(2020),
        lastDate: start ? DateTime.parse(selectedDate) : DateTime.parse(clock['date']));
    if (picked != null) {
      setState(() {
        if (start) { fromDate = picked.toIso8601String().substring(0, 10); }
        else { selectedDate = picked.toIso8601String().substring(0, 10); }
      });
      load();
    }
  }

  Future<void> coverage(Map<String, dynamic> row) async {
    try {
      final candidates = await ApiService.centerOperation(
          'substitutes?circleId=${row['circleId']}') as List;
      if (!mounted) return;
      int? selected = candidates.any((u) => u['id'] == row['substituteUserId'])
          ? (row['substituteUserId'] as int?)
          : null;
      final reason =
          TextEditingController(text: row['reason']?.toString() ?? '');
      bool saving = false;
      await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (context, change) => AlertDialog(
                    title: Text('غياب وتغطية • ${row['circleName']}'),
                    scrollable: true,
                    content: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  'يسجل المعلم الأصلي غائباً بتاريخ ${row['date']}، ويمنح الحساب المختار صلاحية الرصد لهذا اليوم فقط.',
                                  style: AppTheme.cairoStyle(
                                      fontSize: 12, height: 1.8)),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int?>(
                                  initialValue: selected,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'الحساب المكلف بالتغطية',
                                      border: OutlineInputBorder()),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('غياب دون معلم بديل')),
                                    ...candidates.map((u) =>
                                        DropdownMenuItem<int?>(
                                            value: u['id'] as int,
                                            child: Text(
                                                u['fullName'].toString(),
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                  ],
                                  onChanged: saving
                                      ? null
                                      : (value) =>
                                          change(() => selected = value)),
                              const SizedBox(height: 14),
                              TextField(
                                  controller: reason,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'العذر أو سبب الغياب (اكتب بدون عذر عند عدم وجوده)',
                                      border: OutlineInputBorder())),
                            ])),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (reason.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text('سبب الغياب مطلوب')));
                                    return;
                                  }
                                  change(() => saving = true);
                                  try {
                                    await ApiService.centerOperation(
                                        'coverage/${row['circleId']}',
                                        body: {
                                          'date': row['date'],
                                          'substituteUserId': selected,
                                          'reason': reason.text.trim()
                                        });
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      change(() => saving = false);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                          child: Text(
                              saving ? 'جاري الحفظ…' : 'حفظ الغياب والتكليف'))
                    ],
                  )));
      reason.dispose();
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> downloadReport(String format) async {
    try {
      final uri = await ApiService.createDownloadTicket(
          format: format, filter: reportFilter);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String get dayTitle {
    if (selectedDate.isEmpty) return 'جارٍ تحديد اليوم';
    const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return '$fromDate — $selectedDate (${weekdays[DateTime.parse(selectedDate).weekday - 1]})';
  }

  static String absenceLabel(Map<String, dynamic> row) {
    switch (row['status']) {
      case 'Absent': return 'غائب';
      case 'Pending':
      case 'LatePending': return 'قيد المتابعة';
      case 'Suspended': return 'الحلقة معلقة';
      case 'Unscheduled': return 'دون موعد';
      default: return 'مش غايب';
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('حضور المعلمين والبدلاء'), actions: [
            IconButton(onPressed: load, icon: const Icon(Icons.refresh))
          ]),
          body: SingleChildScrollView(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text(
                      'اختر فترة تصل إلى 92 يوماً. يظهر كل يوم مع حالة الغياب والبديل المسند له.',
                      style: AppTheme.cairoStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          height: 1.8)),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                        onPressed: selectedDate.isEmpty ? null : () => chooseDate(start: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('من: $fromDate')),
                    OutlinedButton.icon(
                        onPressed: selectedDate.isEmpty ? null : () => chooseDate(),
                        icon: const Icon(Icons.event),
                        label: Text('إلى: $selectedDate')),
                    OutlinedButton(
                        onPressed: () => downloadReport('xlsx'),
                        child: const Text('Excel')),
                    OutlinedButton(
                        onPressed: () => downloadReport('pdf'),
                        child: const Text('PDF'))
                  ]),
                  if (circles.isNotEmpty)
                    DropdownButtonFormField<int?>(
                        key: ValueKey(circle),
                        initialValue: circle,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'الحلقة'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('كل الحلقات')),
                          ...circles.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis)))
                        ],
                        onChanged: (value) {
                          setState(() => circle = value);
                          load();
                        }),
                  const SizedBox(height: 12),
                  TextField(
                      controller: search,
                      onSubmitted: (_) => load(),
                      decoration: InputDecoration(
                          labelText: 'المعلم الأصلي أو البديل أو الحلقة',
                          suffixIcon: IconButton(
                              onPressed: load,
                              icon: const Icon(Icons.search)))),
                  Wrap(spacing: 8, children: [
                    TextButton(onPressed: load, child: const Text('عرض الكشف')),
                    TextButton(
                        onPressed: () async {
                          search.clear();
                          circle = null;
                          selectedDate = '';
                          fromDate = '';
                          await load();
                        },
                        child: const Text('كشف اليوم بالكامل')),
                    TextButton.icon(
                        onPressed: () => setState(() => tableView = !tableView),
                        icon: Icon(
                            tableView ? Icons.view_agenda : Icons.table_rows),
                        label: Text(tableView ? 'عرض البطاقات' : 'عرض الجدول'))
                  ]),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(18)),
                    child: Text('كشف الفترة $dayTitle', textAlign: TextAlign.center,
                      style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('الحلقات: ${rows.length}  •  الغياب: ${rows.where((r) => r['status'] == 'Absent').length}  •  أسباب موثقة: ${rows.where((r) => r['status'] == 'Absent' && (r['reason'] ?? '').toString().isNotEmpty).length}  •  مش غايب: ${rows.where((r) => absenceLabel(r as Map<String, dynamic>) == 'مش غايب').length}',
                      style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                  ),
                  Text('حرّك الجدول أفقياً لرؤية الغياب والعذر وباقي التفاصيل.',
                    style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
                ])),
            if (tableView && !loading && error == null)
              Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.62,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > 1450
                            ? MediaQuery.sizeOf(context).width - 28
                            : 1450,
                        child: PaginatedDataTable(
                      header: const Text('كشف حضور المعلمين'),
                      rowsPerPage: 20,
                      availableRowsPerPage: const [20],
                      showEmptyRows: false,
                      showFirstLastButtons: true,
                      columnSpacing: 20,
                      horizontalMargin: 16,
                      columns: const [
                        DataColumn(label: Text('اليوم والتاريخ')),
                        DataColumn(label: Text('الحلقة')),
                        DataColumn(label: Text('المعلم')),
                        DataColumn(label: Text('وقت الحلقة')),
                        DataColumn(label: Text('البدء / الإغلاق')),
                        DataColumn(label: Text('التأخير')),
                        DataColumn(label: Text('الغياب')),
                        DataColumn(label: Text('العذر')),
                        DataColumn(label: Text('المعلم البديل')),
                        DataColumn(label: Text('التغطية'))
                      ],
                      source: TeacherRegisterSource(rows, canEdit, coverage))))))),
            if (!tableView || loading || error != null)
              loading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(error!)))
                          : rows.isEmpty
                              ? Padding(padding: const EdgeInsets.all(30), child: Text('لا توجد حلقات مجدولة في الفترة المحددة.', style: AppTheme.cairoStyle(color: AppTheme.textMuted)))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 0, 14, 28),
                                  itemCount: rows.length,
                                  itemBuilder: (context, index) {
                                    final r =
                                        rows[index] as Map<String, dynamic>;
                                    final absent = r['status'] == 'Absent';
                                    return Card(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            side: BorderSide(
                                                color: absent
                                                    ? const Color(0xFFF0D8C6)
                                                    : const Color(0xFFDDE9E0))),
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                      r['circleName']
                                                          .toString(),
                                                      style:
                                                          AppTheme.cairoStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15)),
                                                  Text(
                                                      '${r['date']} • ${r['teacherName']}',
                                                      style:
                                                          AppTheme.cairoStyle(
                                                              fontSize: 12)),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                      'الغياب: ${absenceLabel(r)} • ${r['statusText']}',
                                                      style: AppTheme.cairoStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: absent
                                                              ? Colors
                                                                  .deepOrange
                                                              : AppTheme
                                                                  .primary)),
                                                  Text(
                                                      'الموعد: ${r['scheduledStart'] == null ? 'غير محدد' : '${r['scheduledStart']} - ${r['scheduledEnd'] ?? ''}'} • البدء: ${r['openedAt'] ?? 'لم تبدأ'}'),
                                                  Text('الإغلاق: ${r['closedAt'] ?? 'لم تغلق'} • التأخر: ${r['lateMinutes'] == null ? '—' : '${r['lateMinutes']} دقيقة'}'),
                                                  Text('العذر: ${r['status'] == 'Absent' ? ((r['reason'] ?? '').toString().isEmpty ? 'لم يذكر عذر' : r['reason'].toString()) : '—'}'),
                                                  if ((r['substituteName'] ??
                                                          '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Text(
                                                        'المعلم البديل: ${r['substituteName']}',
                                                        style:
                                                            AppTheme.cairoStyle(
                                                                color: AppTheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                  if (r['substituteUserId'] ==
                                                      ApiService
                                                          .currentUser?.id)
                                                    Wrap(spacing: 8, children: [
                                                      TextButton(
                                                          onPressed: () => Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder: (_) => TeacherSessionsScreen(
                                                                      currentUser:
                                                                          ApiService
                                                                              .currentUser!))),
                                                          child: const Text(
                                                              'رصد التسميع')),
                                                      TextButton(
                                                          onPressed: () => Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder: (_) => TeacherAttendanceScreen(
                                                                      currentUser:
                                                                          ApiService
                                                                              .currentUser!))),
                                                          child: const Text(
                                                              'تحضير الطلاب'))
                                                    ]),
                                                  if (canEdit)
                                                    TextButton.icon(
                                                        onPressed: () =>
                                                            coverage(r),
                                                        icon: const Icon(Icons
                                                            .person_add_alt),
                                                        label: const Text(
                                                            'تسجيل غياب / تكليف بديل')),
                                                ])));
                                  }),
          ]))));
}

class TeacherRegisterSource extends DataTableSource {
  static const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  final List<dynamic> rows;
  final bool canEdit;
  final Future<void> Function(Map<String, dynamic>) coverage;
  TeacherRegisterSource(this.rows, this.canEdit, this.coverage);
  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final r = rows[index] as Map<String, dynamic>;
    return DataRow.byIndex(index: index, cells: [
      DataCell(Text('${weekdays[DateTime.parse(r['date'].toString()).weekday - 1]}\n${r['date']}')),
      DataCell(SizedBox(width: 140, child: Text('${r['circleName']}', maxLines: 3, overflow: TextOverflow.ellipsis))),
      DataCell(Text('${r['teacherName']}')),
      DataCell(Text(r['scheduledStart'] == null ? 'دون موعد' : '${r['scheduledStart']} - ${r['scheduledEnd'] ?? ''}')),
      DataCell(Text('${r['openedAt'] ?? 'لم تبدأ'} / ${r['closedAt'] ?? 'لم تغلق'}')),
      DataCell(Text(r['lateMinutes'] == null ? '—' : '${r['lateMinutes']} دقيقة')),
      DataCell(Text(_TeacherOperationsScreenState.absenceLabel(r))),
      DataCell(Text(r['status'] == 'Absent' ? ((r['reason'] ?? '').toString().isEmpty ? 'لم يذكر عذر' : r['reason'].toString()) : '—')),
      DataCell(Text((r['substituteName'] ?? '').toString().isEmpty
          ? 'لا يوجد'
          : r['substituteName'].toString())),
      DataCell(canEdit
          ? TextButton(
              onPressed: () => coverage(r),
              child: const Text('غياب / تكليف بديل'))
          : const Text('—')),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rows.length;
  @override
  int get selectedRowCount => 0;
}
