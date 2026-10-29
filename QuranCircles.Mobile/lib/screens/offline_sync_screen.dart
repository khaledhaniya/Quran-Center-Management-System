import 'package:flutter/material.dart';
import '../services/offline_sync_manager.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class OfflineSyncScreen extends StatefulWidget {
  const OfflineSyncScreen({super.key});

  @override
  State<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen> {
  List<OfflineAction> _actions = [];
  List<Map<String, dynamic>> _recent = [];
  bool _loading = false;
  String? _readError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final actions = await OfflineSyncManager.getQueuedActions();
      final recent = await OfflineSyncManager.getRecentSynced();
      if (mounted) setState(() { _actions = actions; _recent = recent; _readError = null; });
    } catch (_) {
      if (mounted) setState(() => _readError = 'تعذر قراءة العمليات المحفوظة. لم تُحذف البيانات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveDraft(OfflineAction action) async {
    final controller = TextEditingController();
    try {
      final password = await showDialog<String>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اعتماد تقييم الاختبار'),
          content: TextField(
            controller: controller, obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('اعتماد')),
          ],
        ));
      if (password == null) return;
      await OfflineSyncManager.approveEvaluationDraft(action.id, password);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اعتماد التقييم على الخادم.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر الاعتماد: $e')));
      }
    } finally {
      controller.dispose();
    }
  }

  String _label(String type) => switch (type) {
        'circle_attendance' => 'حضور الحلقة',
        'course_attendance' => 'حضور الدورة',
        'recitation_session' => 'جلسة تسميع',
        'create_student' => 'تسجيل طالب',
        'circle_enrollment' => 'تنسيب طالب للحلقة',
        'course_enrollment' => 'تسجيل في دورة',
        'exam_nomination' => 'ترشيح لاختبار',
        'exam_schedule' => 'جدولة اختبار',
        'exam_evaluation_draft' => 'مسودة تقييم اختبار',
        'quality_visit' => 'زيارة رقابية',
        'create_announcement' => 'إعلان',
        _ => 'عملية محفوظة',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المزامنة والحفظ المحلي')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('كل عملية هنا محفوظة على هذا الجهاز. تبقى حتى يؤكد الخادم استلامها.',
                  style: AppTheme.cairoStyle(fontSize: 14)),
              if (ApiService.authToken == null)
                Text('انتهت جلسة الدخول. ستبقى العمليات محفوظة؛ سجّل الدخول مجدداً عند توفر الإنترنت للمزامنة.',
                    style: AppTheme.cairoStyle(color: Colors.orange.shade900)),
              const SizedBox(height: 12),
              if (OfflineSyncManager.lastSyncError.value != null)
                Text(OfflineSyncManager.lastSyncError.value!,
                    style: AppTheme.cairoStyle(color: Colors.orange.shade900)),
              if (_readError != null)
                Text(_readError!, style: AppTheme.cairoStyle(color: Colors.red)),
              FilledButton.icon(
                onPressed: _loading ? null : () async {
                  setState(() => _loading = true);
                  await OfflineSyncManager.syncPendingActions();
                  await _refresh();
                },
                icon: const Icon(Icons.sync),
                label: const Text('مزامنة الآن'),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_actions.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(child: Text('لا توجد عمليات بانتظار الإرسال',
                      style: AppTheme.cairoStyle())),
                ),
              ..._actions.map((action) => Card(
                    child: ListTile(
                      leading: Icon(action.reviewError == null
                          ? Icons.cloud_upload_outlined : Icons.rule,
                          color: action.reviewError == null
                              ? Colors.orange : Colors.red),
                      title: Text(_label(action.actionType),
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action.reviewError == null
                              ? 'محفوظ على الجهاز، بانتظار المزامنة'
                              : 'يحتاج مراجعة: ${action.reviewError}',
                              style: AppTheme.cairoStyle(fontSize: 12)),
                          Text(action.createdAt.toLocal().toString().substring(0, 16),
                              style: AppTheme.cairoStyle(fontSize: 11)),
                        ],
                      ),
                      trailing: action.reviewError == null ? null : IconButton(
                        tooltip: 'إعادة المحاولة',
                        icon: Icon(action.actionType == 'exam_evaluation_draft'
                            ? Icons.verified : Icons.refresh),
                        onPressed: () async {
                          if (action.actionType == 'exam_evaluation_draft') {
                            await _approveDraft(action);
                            return;
                          }
                          await OfflineSyncManager.retryReviewAction(action.id);
                          await OfflineSyncManager.syncPendingActions();
                          await _refresh();
                        },
                      ),
                    ),
                  )),
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('تمت مزامنتها مؤخرًا',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                ..._recent.map((item) => ListTile(
                  leading: const Icon(Icons.cloud_done, color: Colors.green),
                  title: Text(_label(item['type']?.toString() ?? ''),
                      style: AppTheme.cairoStyle()),
                  subtitle: Text(item['at']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? ''),
                )),
              ],
            ],
          ),
        ),
      );
}
