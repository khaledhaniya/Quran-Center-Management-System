import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'student_360_screen.dart';

class ParentPortalScreen extends StatefulWidget {
  final bool embedded;
  const ParentPortalScreen({super.key,this.embedded=false});
  @override State<ParentPortalScreen> createState()=>_ParentPortalScreenState();
}
class _ParentPortalScreenState extends State<ParentPortalScreen> {
  Map<String,dynamic>? data;
  String? error,from,to;
  int? selected;
  bool loading=true;
  int version=0;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    final request=++version;setState((){loading=true;error=null;});
    try{final value=await ApiService.getParentPortal(from:from,to:to);if(!mounted||request!=version)return;setState((){data=value;from=value['from'];to=value['to'];loading=false;if(!(value['children'] as List).any((c)=>c['studentId']==selected))selected=null;});}
    catch(e){if(mounted&&request==version)setState((){error='$e';loading=false;});}
  }
  Future<void> pick(bool first)async{
    final today=DateTime.parse(data!['today']);
    final value=await showDatePicker(context:context,initialDate:DateTime.parse((first?from:to)!),firstDate:DateTime(2020),lastDate:today);
    if(value!=null&&mounted)setState((){if(first){from=value.toIso8601String().substring(0,10);}else{to=value.toIso8601String().substring(0,10);}});
  }
  Future<void> download(int id)async{
    try{final url=await ApiService.createDownloadTicket(format:'pdf',filter:{'kind':'student_profile','studentIds':[id]});if(!await launchUrl(url,mode:LaunchMode.externalApplication))throw Exception('تعذر فتح الملف');}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  Future<void> requestChanges(Map<String,dynamic> child) async {
    const fields={'familyContact':'هاتف العائلة','studentMobile':'جوال الطالب','currentAddress':'عنوان السكن','healthStatus':'الحالة الصحية','notes':'ملاحظات'};
    final profile=Map<String,dynamic>.from(child['profile']??{});
    final controllers={for(final key in fields.keys)key:TextEditingController(text:profile[key]?.toString()??'')};
    bool saving=false;
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(title:Text('طلب تعديل بيانات ${child['studentName']}'),scrollable:true,content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('يراجع المركز الطلب قبل اعتماد التعديل على بيانات الطالب.'),...fields.entries.map((f)=>Padding(padding:const EdgeInsets.only(top:12),child:TextField(controller:controllers[f.key],decoration:InputDecoration(labelText:f.value,border:const OutlineInputBorder()))))]),actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:saving?null:()async{
      final changes=<String,String>{};controllers.forEach((key,c){if(c.text.trim()!=(profile[key]?.toString()??''))changes[key]=c.text.trim();});
      if(changes.isEmpty){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('غيّر أحد الحقول أولاً.')));return;}
      change(()=>saving=true);try{final ok=await ApiService.submitProfileUpdateRequest(studentId:child['studentId'],requestedByRole:'Parent',requestedByName:ApiService.currentUser?.fullName??'',changes:changes);if(!ok)throw Exception('تعذر إرسال الطلب');if(ctx.mounted)Navigator.pop(ctx);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال الطلب إلى إدارة المركز للمراجعة.')));}
      catch(e){if(ctx.mounted){change(()=>saving=false);ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e')));}}
    },child:Text(saving?'جاري الإرسال…':'إرسال للمراجعة'))])));
    for(final c in controllers.values){c.dispose();}
  }
  Widget metric(String label,Object? value)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xfff5f9f6),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value',style:AppTheme.cairoStyle(fontWeight:FontWeight.bold,fontSize:18,color:AppTheme.primary)),const SizedBox(height:6),Text(label,style:AppTheme.cairoStyle(fontSize:11,color:AppTheme.textMuted,height:1.7))]));
  Widget records(String title,List rows,String empty,Widget Function(dynamic) render,{bool open=false})=>Container(margin:const EdgeInsets.only(top:12),decoration:BoxDecoration(border:Border.all(color:const Color(0xffe4ece6)),borderRadius:BorderRadius.circular(12)),child:Material(type:MaterialType.transparency,borderRadius:BorderRadius.circular(12),clipBehavior:Clip.antiAlias,child:ExpansionTile(initiallyExpanded:open,title:Text(title,style:AppTheme.cairoStyle(fontSize:13,fontWeight:FontWeight.bold)),childrenPadding:const EdgeInsets.fromLTRB(16,0,16,12),children:rows.isEmpty?[Text(empty,style:AppTheme.cairoStyle(color:AppTheme.textMuted,fontSize:12))]:rows.map(render).toList())));
  Widget record(String title,String detail)=>Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:AppTheme.cairoStyle(fontSize:12,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(detail,style:AppTheme.cairoStyle(fontSize:11,color:AppTheme.textMuted,height:1.8))]));
  Widget childCard(Map<String,dynamic> c){
    final target=(c['targetAjzaaCount'] as num).toDouble();final completed=(c['completedAjzaaCount'] as num).toDouble();
    return Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xffdce8df)),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${c['circleName']}',style:AppTheme.cairoStyle(color:AppTheme.accent,fontSize:12)),const SizedBox(height:6),Text('${c['studentName']}',style:AppTheme.cairoStyle(fontSize:20,fontWeight:FontWeight.bold)),Text('المعلم: ${c['teacherName']}',style:AppTheme.cairoStyle(color:AppTheme.textMuted,fontSize:12))])),Chip(label:Text(c['isActive']==true?'نشط':'معلق'),backgroundColor:const Color(0xffe7f4eb))]),
      const SizedBox(height:20),Text('تقدم الحفظ المسجل • ${c['completedAjzaaCount']} / ${c['targetAjzaaCount']} جزءاً',style:AppTheme.cairoStyle(fontSize:12)),const SizedBox(height:9),ClipRRect(borderRadius:BorderRadius.circular(99),child:LinearProgressIndicator(value:target>0?(completed/target).clamp(0,1):0,minHeight:9,color:AppTheme.accent,backgroundColor:const Color(0xffecf1ed))),
      const SizedBox(height:20),LayoutBuilder(builder:(context,size)=>Wrap(spacing:10,runSpacing:10,children:[['الحضور',c['attendanceRate']==null?'لم يرصد':'${c['attendanceRate']}%'],['جلسات التسميع',c['totalSessions']],['حفظ جديد • صفحة',c['newPages']],['مراجعة • صفحة',c['reviewPages']],['غياب دون عذر',c['absentCount']],['غياب بعذر',c['excusedAbsentCount']],['تأخر',c['lateCount']],['مشاركات المواهب',c['talentsCount']]].map((m)=>SizedBox(width:(size.maxWidth-10)/2,child:metric(m[0].toString(),m[1]))).toList())),
      records('آخر جلسات التسميع',c['recentSessions'] as List,'لا توجد جلسات مسجلة في هذه الفترة.',(r)=>record('${r['surah']} • ${r['type']}','${r['date']} • ${r['pages']} صفحة • ${r['assessment']}'),open:true),
      records('آخر سجلات الحضور',c['recentAttendance'] as List,'لا يوجد حضور مرصود في هذه الفترة.',(r)=>record('${r['status']}','${r['date']}')),
      records('الدورات المسجل بها • ${(c['courses'] as List).length}',c['courses'] as List,'غير مسجل في دورات حالياً.',(r)=>record('${r['name']} • ${r['status']}','المعلم: ${r['teacherName']} • الدرجة: ${r['grade']??'لم ترصد'}')),
      const SizedBox(height:16),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton(onPressed:()=>requestChanges(c),child:const Text('طلب تعديل بيانات الابن')),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Student360Screen(initialStudentId:c['studentId'],isParentView:true))),child:const Text('الملف الشامل')),OutlinedButton(onPressed:()=>download(c['studentId']),child:const Text('تنزيل الملف الشامل PDF')),if((c['teacherPhone']??'').toString().isNotEmpty)OutlinedButton(onPressed:()=>launchUrl(Uri(scheme:'tel',path:c['teacherPhone'].toString().replaceAll(RegExp(r'[^+\d]'),''))),child:const Text('التواصل مع المعلم'))]),
    ]));
  }
  @override Widget build(BuildContext context){
    final children=data?['children'] as List? ?? [];
    final visible=children.where((c)=>selected==null||c['studentId']==selected).toList();
    final summary=data?['summary'] as Map? ?? {};
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:AppTheme.background,appBar:widget.embedded?null:AppBar(title:const Text('متابعة أبنائي'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),body:RefreshIndicator(onRefresh:load,child:SingleChildScrollView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff0d5c3a),Color(0xff1e7653)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.family_restroom,color:Color(0xffebd296),size:35),const SizedBox(height:12),Text('متابعة أبنائي',style:AppTheme.cairoStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold)),Text('الحضور والتسميع والحفظ والدورات من سجلات المركز الفعلية.',style:AppTheme.cairoStyle(color:Colors.white,height:1.8,fontSize:13)),const SizedBox(height:8),Text('مؤشرات الحضور والتسميع تخص الفترة المختارة؛ تقدم الأجزاء يعرض المحفوظ المسجل بالكامل.',style:AppTheme.cairoStyle(color:const Color(0xffd5e9dc),height:1.8,fontSize:11))])),
      const SizedBox(height:16),if(loading)const Padding(padding:EdgeInsets.all(28),child:Center(child:CircularProgressIndicator()))
      else if(error!=null)Column(children:[Text('تعذر تحميل متابعة الأبناء\n$error'),TextButton(onPressed:load,child:const Text('إعادة المحاولة'))])
      else ...[
        Wrap(spacing:8,runSpacing:8,children:[OutlinedButton(onPressed:()=>pick(true),child:Text('من: $from')),OutlinedButton(onPressed:()=>pick(false),child:Text('إلى: $to')),FilledButton(onPressed:load,child:const Text('عرض المتابعة'))]),
        const SizedBox(height:12),DropdownButtonFormField<int?>(key:ValueKey(selected),initialValue:selected,isExpanded:true,decoration:const InputDecoration(labelText:'الابن',border:OutlineInputBorder()),hint:const Text('كل الأبناء'),items:[const DropdownMenuItem<int?>(value:null,child:Text('كل الأبناء')),...children.map((c)=>DropdownMenuItem<int?>(value:c['studentId'] as int,child:Text('${c['studentName']}',overflow:TextOverflow.ellipsis)))],onChanged:(v)=>setState(()=>selected=v)),
        const SizedBox(height:18),LayoutBuilder(builder:(ctx,size)=>Wrap(spacing:12,runSpacing:12,children:[['الأبناء',summary['childrenCount']],['جلسات التسميع',summary['totalSessions']],['غياب دون عذر',summary['absentCount']],['غياب بعذر',summary['excusedAbsentCount']]].map((m)=>SizedBox(width:(size.maxWidth-12)/2,child:metric(m[0].toString(),m[1]))).toList())),const SizedBox(height:20),
        if(visible.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('لا يوجد أبناء مرتبطون بحسابك. تواصل مع إدارة المركز لتدقيق الربط.')),
        ...visible.map((c)=>Padding(padding:const EdgeInsets.only(bottom:20),child:childCard(Map<String,dynamic>.from(c)))),
      ],
    ])))));
  }
}
