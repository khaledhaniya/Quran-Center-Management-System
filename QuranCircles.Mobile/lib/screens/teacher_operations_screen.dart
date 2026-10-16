import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'teacher_sessions_screen.dart';
import 'teacher_attendance_screen.dart';
import '../theme/app_theme.dart';

class TeacherOperationsScreen extends StatefulWidget {
  final int? circleId;
  const TeacherOperationsScreen({super.key,this.circleId});
  @override State<TeacherOperationsScreen> createState()=>_TeacherOperationsScreenState();
}
class _TeacherOperationsScreenState extends State<TeacherOperationsScreen> {
  String from='',to='';
  int? circle;
  List<Circle> circles=[];
  List<dynamic> rows=[];
  bool loading=true;
  String? error;
  bool get canEdit => ['Admin','Developer'].contains(ApiService.currentUser?.role) || ApiService.currentUser?.isQualitySupervisor==true;
  @override void initState(){super.initState();circle=widget.circleId;load();}
  Future<void> load() async {
    setState((){loading=true;error=null;});
    try {
      if(from.isEmpty){final clock=await ApiService.centerOperation('today');from=clock['date'];to=from;}
      final results=await Future.wait<Object?>([ApiService.getCircles(),ApiService.centerOperation('teacher-attendance?from=$from&to=$to${circle==null?'':'&circleId=$circle'}')]);
      if(mounted)setState((){circles=results[0] as List<Circle>;rows=results[1] as List;loading=false;});
    }catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  Future<void> chooseDate(bool first) async {
    final clock=await ApiService.centerOperation('today');if(!mounted)return;
    final picked=await showDatePicker(context:context,initialDate:DateTime.parse(first?from:to),firstDate:DateTime(2020),lastDate:DateTime.parse(clock['date']));
    if(picked!=null){setState((){if(first){from=picked.toIso8601String().substring(0,10);}else{to=picked.toIso8601String().substring(0,10);}});load();}
  }
  Future<void> coverage(Map<String,dynamic> row) async {
    try {
      final candidates=await ApiService.centerOperation('substitutes?circleId=${row['circleId']}') as List;
      if(!mounted)return;
      int? selected = candidates.any((u) => u['id'] == row['substituteUserId']) ? (row['substituteUserId'] as int?) : null;
      final reason=TextEditingController(text:row['reason']?.toString()??'');bool saving=false;
      await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(context,change)=>AlertDialog(
        title:Text('غياب وتغطية • ${row['circleName']}'),scrollable:true,
        content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('يسجل المعلم الأصلي غائباً بتاريخ ${row['date']}، ويمنح الحساب المختار صلاحية الرصد لهذا اليوم فقط.',style:AppTheme.cairoStyle(fontSize:12,height:1.8)),
          const SizedBox(height:16),DropdownButtonFormField<int?>(initialValue:selected,isExpanded:true,
            decoration:const InputDecoration(labelText:'الحساب المكلف بالتغطية',border:OutlineInputBorder()),
            items:[const DropdownMenuItem<int?>(value:null,child:Text('غياب دون معلم بديل')), ...candidates.map((u)=>DropdownMenuItem<int?>(value:u['id'] as int,child:Text(u['fullName'].toString(),overflow:TextOverflow.ellipsis)))],
            onChanged:saving?null:(value)=>change(()=>selected=value)),
          const SizedBox(height:14),TextField(controller:reason,maxLines:3,decoration:const InputDecoration(labelText:'سبب الغياب أو الإجازة',border:OutlineInputBorder())),
        ])),
        actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:saving?null:()async{
          if(reason.text.trim().isEmpty){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('سبب الغياب مطلوب')));return;}
          change(()=>saving=true);
          try{await ApiService.centerOperation('coverage/${row['circleId']}',body:{'date':row['date'],'substituteUserId':selected,'reason':reason.text.trim()});if(ctx.mounted)Navigator.pop(ctx);}
          catch(e){if(ctx.mounted){change(()=>saving=false);ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e')));}}
        },child:Text(saving?'جاري الحفظ…':'حفظ الغياب والتكليف'))],
      )));
      reason.dispose();await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  Future<void> downloadReport(String format)async{
    try{final uri=await ApiService.createDownloadTicket(format:format,filter:{'kind':'teacher_discipline','from':from,'to':to,'circleId':circle});await launchUrl(uri,mode:LaunchMode.externalApplication);}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('حضور المعلمين والبدلاء'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(14),child:Column(children:[
        Text('يرصد بدء الحلقة من أول تسميع. يظهر التأخر بعد 15 دقيقة والغياب بعد انتهاء الموعد دون نشاط. الموعد غير المحدد لا يحتسب غياباً.',style:AppTheme.cairoStyle(fontSize:11,color:AppTheme.textMuted,height:1.8)),
        Wrap(spacing:8,runSpacing:8,children:[OutlinedButton(onPressed:from.isEmpty?null:()=>chooseDate(true),child:Text('من: $from')),OutlinedButton(onPressed:to.isEmpty?null:()=>chooseDate(false),child:Text('إلى: $to')),OutlinedButton(onPressed:()=>downloadReport('xlsx'),child:const Text('Excel')),OutlinedButton(onPressed:()=>downloadReport('pdf'),child:const Text('PDF'))]),
        if(circles.isNotEmpty)DropdownButtonFormField<int?>(initialValue:circle,isExpanded:true,decoration:const InputDecoration(labelText:'الحلقة'),
          items:[const DropdownMenuItem<int?>(value:null,child:Text('كل الحلقات')), ...circles.map((c)=>DropdownMenuItem<int?>(value:c.id,child:Text(c.name,overflow:TextOverflow.ellipsis)))],
          onChanged:(value){setState(()=>circle=value);load();}),
      ])),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Padding(padding:const EdgeInsets.all(20),child:Text(error!))):RefreshIndicator(onRefresh:load,child:ListView.builder(
        padding:const EdgeInsets.fromLTRB(14,0,14,28),itemCount:rows.length,itemBuilder:(context,index){final r=rows[index] as Map<String,dynamic>;final absent=r['status']=='Absent';return Card(
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:absent?const Color(0xFFF0D8C6):const Color(0xFFDDE9E0))),
          child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(r['circleName'].toString(),style:AppTheme.cairoStyle(fontWeight:FontWeight.bold,fontSize:15)),
            Text('${r['date']} • ${r['teacherName']}',style:AppTheme.cairoStyle(fontSize:12)),const SizedBox(height:8),
            Text('${r['statusText']}${r['isAutomatic']==true?' • رصد تلقائي':''}',style:AppTheme.cairoStyle(fontWeight:FontWeight.bold,color:absent?Colors.deepOrange:AppTheme.primary)),
            Text('الموعد: ${r['scheduledStart']??'غير محدد'} • البدء: ${r['openedAt']??'لم تبدأ'}'),
            if((r['substituteName']??'').toString().isNotEmpty)Text('المعلم البديل: ${r['substituteName']}',style:AppTheme.cairoStyle(color:AppTheme.primary,fontWeight:FontWeight.bold)),
            if((r['reason']??'').toString().isNotEmpty)Text(r['reason'].toString()),
            if(r['substituteUserId']==ApiService.currentUser?.id)Wrap(spacing:8,children:[TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TeacherSessionsScreen(currentUser:ApiService.currentUser!))),child:const Text('��� �������')),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TeacherAttendanceScreen(currentUser:ApiService.currentUser!))),child:const Text('����� ������'))]),
            if(canEdit)TextButton.icon(onPressed:()=>coverage(r),icon:const Icon(Icons.person_add_alt),label:const Text('تسجيل غياب / تكليف بديل')),
          ])));}))),
    ])));
}
