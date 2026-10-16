import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class CertificatePreviewDialog extends StatefulWidget {
  final String kind;
  final int certificateId;
  final Uint8List? thumbnail;
  const CertificatePreviewDialog({super.key, required this.kind, required this.certificateId, this.thumbnail});
  @override
  State<CertificatePreviewDialog> createState() => _CertificatePreviewDialogState();
}

class _CertificatePreviewDialogState extends State<CertificatePreviewDialog> {
  late final Future<Uint8List> image;
  bool downloading = false;
  @override
  void initState() {
    super.initState();
    image = ApiService.fetchCertificatePreview(certificateKind:widget.kind, certificateId:widget.certificateId);
  }
  Future<void> download() async {
    setState(() => downloading = true);
    try {
      final uri = await ApiService.createDownloadTicket(format:'pdf', certificateKind:widget.kind, certificateId:widget.certificateId);
      if (!await launchUrl(uri, mode:LaunchMode.externalApplication)) throw Exception('تعذر فتح الملف');
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    } finally { if (mounted) setState(() => downloading = false); }
  }
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding:const EdgeInsets.all(14),
    child:ConstrainedBox(constraints:BoxConstraints(maxWidth:900,maxHeight:MediaQuery.sizeOf(context).height*.88),
      child:Column(mainAxisSize:MainAxisSize.min, children:[
        Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:12,runSpacing:8,alignment:WrapAlignment.center,children:[
          FilledButton.icon(onPressed:downloading?null:download,icon:const Icon(Icons.download),label:Text(downloading?'جاري تجهيز الملف…':'تنزيل PDF')),
          TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق')),
        ])),
        Flexible(child:FutureBuilder<Uint8List>(future:image,initialData:widget.thumbnail,builder:(context,snapshot){
          if(snapshot.hasData) return InteractiveViewer(child:Image.memory(snapshot.data!,fit:BoxFit.contain,gaplessPlayback:true));
          if(snapshot.hasError) return const Padding(padding:EdgeInsets.all(24),child:Text('تعذر تحميل الشهادة. حدّث الملف ثم أعد المحاولة.'));
          return const SizedBox(height:240,child:Center(child:CircularProgressIndicator()));
        })),
      ])),
  );
}
