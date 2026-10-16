import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'teacher_operations_screen.dart';

class CenterOperationsScreen extends StatefulWidget {
  const CenterOperationsScreen({super.key});
  @override State<CenterOperationsScreen> createState()=>_CenterOperationsScreenState();
}
class _CenterOperationsScreenState extends State<CenterOperationsScreen> {
  List<dynamic> plans=[], schedules=[], days=[];
  Map<int,String> circleNames={};
  bool loading=true;
  String? error;
  bool get canEdit => ['Admin','Developer'].contains(ApiService.currentUser?.role);
  Map<String,String> get headers=>{'Content-Type':'application/json','Authorization':'Bearer ${ApiService.authToken??''}'};
  Future<dynamic> request(String path,[Map<String,dynamic>? body]) async {
    final uri=Uri.parse('${ApiService.baseUrl}/operations/$path');
    final response=body==null?await ApiService.httpClient.get(uri,headers:headers):
      await ApiService.httpClient.post(uri,headers:headers,body:jsonEncode(body));
    if(response.statusCode<200 || response.statusCode>=300) throw Exception('تعذر حفظ أو تحميل البيانات (${response.statusCode})');
    return jsonDecode(response.body);
  }
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    setState((){loading=true;error=null;});
    try {final results=await Future.wait([request('plans'),request('schedules'),request('days')]);
      final circles=await ApiService.getCircles();
      if(mounted){setState((){plans=results[0];schedules=results[1];days=results[2];
        circleNames={for(final c in circles)c.id:c.name};loading=false;});}
    }catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  Future<void> addPlan() async {
    final circles=await ApiService.getCircles();
    if(circles.isEmpty || !mounted)return;
    int circle=circles.first.id; String track='Quran';
    final title=TextEditingController(), target=TextEditingController(), done=TextEditingController(text:'0');
    DateTime from=DateTime.now(),to=DateTime.now().add(const Duration(days:30));
    await showDialog(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,change)=>AlertDialog(
      title:const Text('خطة الحلقة الشهرية'),scrollable:true,
      content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(initialValue:circle,decoration:const InputDecoration(labelText:'الحلقة'),
          items:circles.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.name,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>change(()=>circle=v??circle)),
        TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان الخطة')),
        DropdownButtonFormField<String>(initialValue:track,decoration:const InputDecoration(labelText:'المسار'),
          items:const [DropdownMenuItem(value:'Quran',child:Text('قرآن')),DropdownMenuItem(value:'Aqeedah',child:Text('عقيدة')),
            DropdownMenuItem(value:'Tajweed',child:Text('أحكام وتجويد')),DropdownMenuItem(value:'Course',child:Text('دورة شرعية'))],
          onChanged:(v)=>change(()=>track=v??track)),
        Wrap(spacing:8,children:[TextButton(onPressed:() async {final d=await showDatePicker(context:context,initialDate:from,firstDate:DateTime(2020),lastDate:DateTime(2035));if(d!=null)change(()=>from=d);},child:Text('من ${from.toIso8601String().substring(0,10)}')),
          TextButton(onPressed:() async {final d=await showDatePicker(context:context,initialDate:to,firstDate:DateTime(2020),lastDate:DateTime(2035));if(d!=null)change(()=>to=d);},child:Text('إلى ${to.toIso8601String().substring(0,10)}'))]),
        TextField(controller:target,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الهدف')),
        TextField(controller:done,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المنجز')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),
        FilledButton(onPressed:() async {try {await request('plans',{'circleId':circle,'title':title.text,'track':track,'unit':'صفحة',
          'startsOn':from.toIso8601String().substring(0,10),'endsOn':to.toIso8601String().substring(0,10),
          'target':double.parse(target.text),'completed':double.parse(done.text)});
          if(context.mounted)Navigator.pop(context);await load();
        }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('حفظ'))]
    )));
    title.dispose();target.dispose();done.dispose();
  }
  Future<void> editPlan(Map<String,dynamic> plan) async {
    final controller=TextEditingController(text:'${plan['completed']}');
    final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text('${plan['title']}'),
      content:TextField(controller:controller,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المنجز')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('حفظ'))]));
    if(result!=null){try {await request('plans',{...plan,'completed':double.parse(result)});await load();}
      catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
    controller.dispose();
  }
  Future<void> addSchedule() async {
    final circles=await ApiService.getCircles();
    if(circles.isEmpty || !mounted)return;
    int circle=circles.first.id;
    final selected=<int>{1,2,3,4,7};
    var start=const TimeOfDay(hour:16,minute:0);
    final capacity=TextEditingController(text:'20');
    final duration=TextEditingController(text:'60');
    const names=['','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(
      title:const Text('موعد الحلقة وسعتها'),scrollable:true,
      content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:500),child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(initialValue:circle,decoration:const InputDecoration(labelText:'الحلقة'),
          items:circles.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.name,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v)=>change(()=>circle=v??circle)),
        const SizedBox(height:12),
        Wrap(spacing:6,runSpacing:6,children:[for(var day=1;day<=7;day++)FilterChip(
          label:Text(names[day]),selected:selected.contains(day),onSelected:(yes)=>change((){if(yes){selected.add(day);}else{selected.remove(day);}}))]),
        TextButton.icon(icon:const Icon(Icons.schedule),label:Text('موعد البدء: ${start.format(ctx)}'),
          onPressed:() async {final value=await showTimePicker(context:ctx,initialTime:start);
            if(value!=null)change(()=>start=value);}),
        TextField(controller:capacity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الطاقة الاستيعابية')),
        TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مدة الحلقة بالدقائق')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:() async {
          try {
            if(selected.isEmpty)throw Exception('حدد يوماً واحداً على الأقل');
            final time='${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}';
            await request('schedules',{'circleId':circle,'weekdays':(selected.toList()..sort()).join(','),
              'startTime':time,'capacity':int.parse(capacity.text),'durationMinutes':int.parse(duration.text)});
            if(ctx.mounted)Navigator.pop(ctx);
            await load();
          }catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e')));}
        },child:const Text('حفظ الموعد'))]
    )));
    capacity.dispose();duration.dispose();
  }
  Future<void> recordAbsence() async {
    final circles=await ApiService.getCircles();
    if(circles.isEmpty || !mounted)return;
    int circle=circles.first.id;
    final reason=TextEditingController();
    await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(
      title:const Text('تسجيل غياب معلم الحلقة اليوم'),scrollable:true,
      content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(initialValue:circle,decoration:const InputDecoration(labelText:'الحلقة'),
          items:circles.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.name,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(v)=>change(()=>circle=v??circle)),
        TextField(controller:reason,maxLines:2,decoration:const InputDecoration(labelText:'سبب الغياب الرسمي'))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:() async {
          try {
            if(reason.text.trim().isEmpty)throw Exception('سبب الغياب مطلوب');
            final today=await request('today');
            await request('days/$circle',{'date':today['date'],
              'status':'Absent','reason':reason.text.trim()});
            if(ctx.mounted)Navigator.pop(ctx);
            await load();
          }catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('$e')));}
        },child:const Text('تسجيل الغياب'))]
    )));
    reason.dispose();
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:Text('خطط الحلقات والتشغيل',style:AppTheme.cairoStyle(fontWeight:FontWeight.bold)),
      actions:[if(canEdit)IconButton(onPressed:addSchedule,tooltip:'موعد جديد',icon:const Icon(Icons.calendar_month)),
        if(canEdit)IconButton(onPressed:recordAbsence,tooltip:'غياب المعلم',icon:const Icon(Icons.person_off)),
        IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
    floatingActionButton:canEdit?FloatingActionButton.extended(onPressed:addPlan,icon:const Icon(Icons.add),label:const Text('خطة جديدة')):null,
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):
      ListView(padding:const EdgeInsets.fromLTRB(16,16,16,110),children:[
        OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TeacherOperationsScreen())),icon:const Icon(Icons.punch_clock),label:const Text('كشف حضور المعلمين والتغطية البديلة')),
        Text('الخطط المسجلة',style:AppTheme.cairoStyle(fontSize:20,fontWeight:FontWeight.bold)),
        if(plans.isEmpty)const ListTile(title:Text('لا توجد خطط مسجلة بعد.')),
        ...plans.map((raw){final p=raw as Map<String,dynamic>;return Card(child:ListTile(
          title:Text('${p['title']} • ${p['track']}'),
          subtitle:Text('${p['startsOn']} — ${p['endsOn']}\nالمنجز: ${p['completed']} من ${p['target']} ${p['unit']}'),
          isThreeLine:true,trailing:canEdit?IconButton(onPressed:()=>editPlan(p),icon:const Icon(Icons.edit)):null));}),
        const SizedBox(height:16),Text('مواعيد الحلقات',style:AppTheme.cairoStyle(fontSize:19,fontWeight:FontWeight.bold)),
        ...schedules.map((raw){final s=raw as Map<String,dynamic>;return Card(child:ListTile(
          leading:const Icon(Icons.schedule),title:Text(circleNames[s['circleId']]??'حلقة ${s['circleId']}'),
          subtitle:Text('الأيام ${s['weekdays']} • البدء ${s['startTime']} • السعة ${s['capacity']}')));}),
        const SizedBox(height:16),Text('سجل حضور المعلمين',style:AppTheme.cairoStyle(fontSize:19,fontWeight:FontWeight.bold)),
        ...days.map((raw){final d=raw as Map<String,dynamic>;return Card(child:ListTile(
          title:Text('${circleNames[d['circleId']]??'حلقة ${d['circleId']}'} • ${d['date']}'),
          subtitle:Text('${d['status']} • ${d['openedAt']??'لم تبدأ'}')));}),
      ])));
}
