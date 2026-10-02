import 'package:flutter/material.dart';
import '../matching/models.dart';
import 'native_print_service.dart';

Future<PrintSettings?> showPrintPageSetup(BuildContext context, {required PrintSettings initial}) async {
  var s = initial;
  return showDialog<PrintSettings>(
    context: context,
    builder: (_) => StatefulBuilder(builder: (context, set) => AlertDialog(
      title: const Text('Print Page Setup'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          initialValue: s.paper,
          decoration: const InputDecoration(labelText: 'Paper Size'),
          items: const [
            DropdownMenuItem(value:'A4',child:Text('A4')), DropdownMenuItem(value:'A5',child:Text('A5')),
            DropdownMenuItem(value:'A3',child:Text('A3')), DropdownMenuItem(value:'LETTER',child:Text('Letter')),
            DropdownMenuItem(value:'LEGAL',child:Text('Legal')),
          ],
          onChanged:(v)=>set(() { s=s.copyWith(paper:v); }),
        ),
        DropdownButtonFormField<String>(
          initialValue:s.orientation,
          decoration:const InputDecoration(labelText:'Orientation'),
          items:const [
            DropdownMenuItem(value:'auto',child:Text('Auto (based on columns)')),
            DropdownMenuItem(value:'portrait',child:Text('Portrait')),
            DropdownMenuItem(value:'landscape',child:Text('Landscape')),
          ],
          onChanged:(v)=>set(() { s=s.copyWith(orientation:v); }),
        ),
        Row(children:[const Text('Margin'),Expanded(child:Slider(min:2,max:20,divisions:18,value:s.margin.toDouble(),label:'${s.margin} mm',onChanged:(v)=>set(() { s=s.copyWith(margin:v.round()); }))),Text('${s.margin} mm')]),
        Row(children:[const Text('Table font'),Expanded(child:Slider(min:7,max:16,divisions:9,value:s.fontSize,label:'${s.fontSize.toStringAsFixed(0)} pt',onChanged:(v)=>set(() { s=s.copyWith(fontSize:v); }))),Text('${s.fontSize.toStringAsFixed(0)} pt')]),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Auto-fit columns'),value:s.autoFit,onChanged:(v)=>set(() { s=s.copyWith(autoFit:v); })),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Repeat table header'),value:s.repeatHeader,onChanged:(v)=>set(() { s=s.copyWith(repeatHeader:v); })),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Page number'),value:s.pageNumber,onChanged:(v)=>set(() { s=s.copyWith(pageNumber:v); })),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
        FilledButton(onPressed:()async{await NativePrintService.saveSettings(s);if(context.mounted)Navigator.pop(context,s);},child:const Text('Save')),
      ],
    )),
  );
}

Future<void> showStudentPrintDialog(BuildContext context,{
  required List<ComparisonRow> rows,
  required String schoolName,
  required String pspCode,
  required String udiseCode,
  required PrintSettings settings,
}) async {
  var source='PSP'; var scope='ALL'; String selectedClass='';
  var fields=<String>['id','sr','name','father','mother','dob','admission','mobile'];
  const labels={'id':'NIC ID / PEN','sr':'S.No / SR','name':'Name','father':'Father Name','mother':'Mother Name','dob':'DOB','admission':'Admission Date','mobile':'Mobile'};

  final ok=await showDialog<bool>(context:context,builder:(_)=>StatefulBuilder(builder:(context,set){
    final sourceRows=rows.where((r)=>source=='PSP'?r.psp!=null:r.udise!=null);
    final classes=<String>{};
    for(final r in sourceRows){
      final c=source=='PSP'?(r.psp?.classCanonValue??''):(r.udise?.classDescCanon.isNotEmpty==true?r.udise!.classDescCanon:r.udise?.classIdCanon??'');
      if(c.isNotEmpty) { classes.add(c); }
    }
    final cs=classes.toList()..sort();
    return AlertDialog(
      title:const Text('Print Report'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SegmentedButton<String>(segments:const[ButtonSegment(value:'PSP',label:Text('PSP')),ButtonSegment(value:'UDISE',label:Text('UDISE'))],selected:{source},onSelectionChanged:(v)=>set(() { source=v.first; selectedClass=''; })),
        const SizedBox(height:10),
        SegmentedButton<String>(segments:const[ButtonSegment(value:'ALL',label:Text('All Students')),ButtonSegment(value:'CLASS',label:Text('Selected Class'))],selected:{scope},onSelectionChanged:(v)=>set(() =>scope=v.first)),
        if(scope=='CLASS')DropdownButtonFormField<String>(initialValue:selectedClass.isEmpty?null:selectedClass,decoration:const InputDecoration(labelText:'Class'),items:cs.map((c)=>DropdownMenuItem(value:c,child:Text('Class $c'))).toList(),onChanged:(v)=>set(() =>selectedClass=v??'')),
        const SizedBox(height:10),Text('Select fields',style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w800)),
        ...labels.entries.map((e)=>CheckboxListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(e.value),value:fields.contains(e.key),onChanged:(v)=>set(() { if(v==true&&!fields.contains(e.key)) fields=[...fields,e.key]; if(v==false&&fields.length>1) fields=fields.where((x)=>x!=e.key).toList(); }))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(context,true),icon:const Icon(Icons.print),label:const Text('Print'))],
    );
  }));
  if(ok!=true||!context.mounted)return;
  if(scope=='CLASS'&&selectedClass.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please select a class.')));return;}

  var data=rows.where((r)=>source=='PSP'?r.psp!=null:r.udise!=null).toList();
  if(scope=='CLASS')data=data.where((r){
    final c=source=='PSP'?(r.psp?.classCanonValue??''):(r.udise?.classDescCanon.isNotEmpty==true?r.udise!.classDescCanon:r.udise?.classIdCanon??'');
    return c==selectedClass;
  }).toList();

  final cols=['S.No',...fields.map((x)=>labels[x]!)];
  String val(ComparisonRow r,String k){
    if(source=='PSP'){final p=r.psp!;switch(k){case'id':return p.nicId;case'sr':return p.srNo;case'name':return p.studentName;case'father':return p.fatherName;case'mother':return p.motherName;case'dob':return p.dob;case'admission':return _raw(p.raw);case'mobile':return p.mobile;}}
    final u=r.udise!;switch(k){case'id':return u.studentCodeNat;case'sr':return u.studentId;case'name':return u.studentName;case'father':return u.fatherName;case'mother':return u.motherName;case'dob':return u.dob;case'admission':return _raw(u.raw);case'mobile':return u.mobile;}return '';
  }
  final table=<List<String>>[];
  for(var i=0;i<data.length;i++)table.add(['${i+1}',...fields.map((k)=>val(data[i],k))]);
  await NativePrintService.printTable(
    title:'($pspCode) ($udiseCode) $schoolName',
    subtitle:'${scope=='ALL'?'All':'Class : $selectedClass'}    $source REPORT    Student Count : ${table.length}',
    columns:cols,rows:table,settings:settings,
  );
}

String _raw(Map<String,dynamic> r){for(final k in const['Admission Date','AdmissionDate','admissionDate','admission_date']){final v=r[k]?.toString().trim()??'';if(v.isNotEmpty)return v;}return'';}
