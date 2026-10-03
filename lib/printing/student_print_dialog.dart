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
        FilledButton(onPressed:()async{
          await NativePrintService.saveSettings(s);
          if(context.mounted){Navigator.pop(context,s);}
        },child:const Text('Save')),
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
  var source='PSP';
  var scope='ALL';
  String selectedClass='';
  List<String> fields=[];
  Map<String,String> customHeaders={};

  List<ComparisonRow> sourceRows() =>
      rows.where((r)=>source=='PSP'?r.psp!=null:r.udise!=null).toList();

  String normKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'),'');
  String label(String key) {
    final s=key.replaceAll(RegExp(r'[_-]+'),' ').replaceAll(RegExp(r'\s+'),' ').trim();
    return s.isEmpty?key:s.split(' ').map((w)=>w.isEmpty?w:'${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  List<MapEntry<String,String>> buildAvailableFields() {
    final out=<MapEntry<String,String>>[];
    final seen=<String>{};
    void add(String key,String text) {
      final n=normKey(key);
      if (n.isEmpty || seen.contains(n)) {
        return;
      }
      seen.add(n);
      out.add(MapEntry(key,text));
    }

    // Preferred labels/order only. Cell values always come from raw DB JSON.
    final preferred=<MapEntry<String,String>>[
      const MapEntry('Student NIC ID','NIC ID / PEN'),
      const MapEntry('studentCodeNat','National Student Code'),
      const MapEntry('studentId','Student ID'),
      const MapEntry('SR No.','S.No / SR'),
      const MapEntry('Student Name','Name'),
      const MapEntry('studentName','Name'),
      const MapEntry('Father Name','Father Name'),
      const MapEntry('fatherName','Father Name'),
      const MapEntry('Mother Name','Mother Name'),
      const MapEntry('motherName','Mother Name'),
      const MapEntry('DOB','DOB'),
      const MapEntry('dob','DOB'),
      const MapEntry('Admission Date','Admission Date'),
      const MapEntry('admissionDate','Admission Date'),
      const MapEntry('dateOfAdmission','Admission Date'),
      const MapEntry('Gender','Gender'),
      const MapEntry('gender','Gender'),
      const MapEntry('Studying in Class','Class'),
      const MapEntry('classDesc','Class'),
      const MapEntry('classId','Class ID'),
      const MapEntry('Mobile Number','Mobile'),
      const MapEntry('primaryMobile','Mobile'),
      const MapEntry('Aadhar Number','Aadhaar'),
      const MapEntry('uuid','UUID / Aadhaar'),
      const MapEntry('uuidStatus','Aadhaar Verification Status'),
      const MapEntry('nameAsUuid','Name as Aadhaar'),
      const MapEntry('Social Category','Social Category'),
      const MapEntry('socialCategoryDesc','Social Category'),
      const MapEntry('socCatId','Social Category ID'),
      const MapEntry('Religion','Religion'),
      const MapEntry('minorityDesc','Religion / Minority'),
      const MapEntry('minorityId','Religion / Minority ID'),
    ];

    final data=sourceRows();
    for(final e in preferred) {
      if(data.any((r){
        final raw=source=='PSP'?r.psp!.raw:r.udise!.raw;
        return raw.keys.any((k)=>normKey(k)==normKey(e.key));
      })) {
        add(e.key,e.value);
      }
    }
    for(final r in data) {
      final raw=source=='PSP'?r.psp!.raw:r.udise!.raw;
      for(final k in raw.keys) {
        add(k,label(k));
      }
    }
    return out;
  }

  List<String> buildClasses() {
    final classes=<String>{};
    for(final r in sourceRows()){
      final c=source=='PSP'
          ?(r.psp?.classCanonValue??'')
          :(r.udise?.classDescCanon.isNotEmpty==true?r.udise!.classDescCanon:r.udise?.classIdCanon??'');
      if (c.isNotEmpty) {
        classes.add(c);
      }
    }
    return classes.toList()..sort();
  }

  var entries=buildAvailableFields();
  fields=entries.map((e)=>e.key).toList();
  customHeaders={for(final e in entries)e.key:e.value};
  var classes=buildClasses();

  final ok=await showDialog<bool>(
    context:context,
    builder:(_)=>StatefulBuilder(builder:(context,set){
      return AlertDialog(
        title:const Text('Print Report'),
        content:SizedBox(
          width:600,
          height:620,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Expanded(child:SegmentedButton<String>(
                segments:const[
                  ButtonSegment(value:'PSP',label:Text('PSP')),
                  ButtonSegment(value:'UDISE',label:Text('UDISE')),
                ],
                selected:{source},
                onSelectionChanged:(v)=>set((){
                  source=v.first;
                  selectedClass='';
                  entries=buildAvailableFields();
                  classes=buildClasses();
                  fields=entries.map((e)=>e.key).toList();
                  customHeaders={for(final e in entries)e.key:e.value};
                }),
              )),
            ]),
            const SizedBox(height:10),
            SegmentedButton<String>(
              segments:const[
                ButtonSegment(value:'ALL',label:Text('All Students')),
                ButtonSegment(value:'CLASS',label:Text('Selected Class')),
              ],
              selected:{scope},
              onSelectionChanged:(v)=>set(()=>scope=v.first),
            ),
            if(scope=='CLASS') Padding(
              padding:const EdgeInsets.only(top:8),
              child:DropdownButtonFormField<String>(
                initialValue:selectedClass.isEmpty?null:selectedClass,
                isExpanded:true,
                decoration:const InputDecoration(labelText:'Class'),
                items:classes.map((c)=>DropdownMenuItem(
                  value:c,
                  child:Text('Class $c',overflow:TextOverflow.ellipsis),
                )).toList(),
                onChanged:(v)=>set(()=>selectedClass=v??''),
              ),
            ),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:Text(
                'Selected columns (${fields.length})',
                style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w800),
              )),
              TextButton(
                onPressed:()=>set(()=>fields=entries.map((e)=>e.key).toList()),
                child:const Text('All'),
              ),
              TextButton(
                onPressed:()=>set(()=>fields=[]),
                child:const Text('Clear'),
              ),
            ]),
            Container(
              height:150,
              decoration:BoxDecoration(
                border:Border.all(color:Theme.of(context).dividerColor),
                borderRadius:BorderRadius.circular(8),
              ),
              child:fields.isEmpty
                  ?const Center(child:Text('No columns selected'))
                  :ReorderableListView.builder(
                      padding:const EdgeInsets.symmetric(vertical:2),
                      itemCount:fields.length,
                      onReorder:(oldIndex,newIndex)=>set((){
                        if(newIndex>oldIndex){newIndex--;}
                        final item=fields.removeAt(oldIndex);
                        fields.insert(newIndex,item);
                      }),
                      itemBuilder:(context,index){
                        final key=fields[index];
                        final defaultHeader=customHeaders[key]??label(key);
                        return ListTile(
                          key:ValueKey('selected-column-$key'),
                          dense:true,
                          visualDensity:const VisualDensity(vertical:-3),
                          contentPadding:const EdgeInsets.only(left:4,right:2),
                          leading:const Icon(Icons.drag_handle,size:20),
                          title:TextFormField(
                            key:ValueKey('header-$key-$defaultHeader'),
                            initialValue:defaultHeader,
                            decoration:const InputDecoration(
                              isDense:true,
                              labelText:'Column heading',
                              border:OutlineInputBorder(),
                            ),
                            onChanged:(v)=>customHeaders[key]=v,
                          ),
                          trailing:IconButton(
                            tooltip:'Remove column',
                            visualDensity:VisualDensity.compact,
                            icon:const Icon(Icons.close,size:19),
                            onPressed:()=>set(()=>fields=fields.where((x)=>x!=key).toList()),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:Text(
                'Available DB fields (${entries.length})',
                style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w800),
              )),
            ]),
            const Divider(height:1),
            const SizedBox(height:2),
            Expanded(
              child:ListView.builder(
                cacheExtent:200,
                itemCount:entries.length,
                itemBuilder:(context,index){
                  final e=entries[index];
                  final checked=fields.contains(e.key);
                  return CheckboxListTile(
                    dense:true,
                    visualDensity:const VisualDensity(vertical:-2),
                    contentPadding:EdgeInsets.zero,
                    title:Text(
                      customHeaders[e.key]??e.value,
                      overflow:TextOverflow.ellipsis,
                    ),
                    subtitle:Text(e.key,overflow:TextOverflow.ellipsis),
                    value:checked,
                    onChanged:(v)=>set((){
                      if (v == true && !fields.contains(e.key)) {
                        fields=[...fields,e.key];
                      } else if (v == false) {
                        fields=fields.where((x)=>x!=e.key).toList();
                      }
                    }),
                  );
                },
              ),
            ),
          ]),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
          FilledButton.icon(
            onPressed:()=>Navigator.pop(context,true),
            icon:const Icon(Icons.print),
            label:const Text('Print'),
          ),
        ],
      );
    }),
  );

  if (ok != true || !context.mounted) {
    return;
  }
  if (scope == 'CLASS' && selectedClass.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class.')));
    return;
  }
  if (fields.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one field.')));
    return;
  }

  var data=sourceRows();
  if (scope == 'CLASS') {
    data=data.where((r){
      final c=source=='PSP'
          ?(r.psp?.classCanonValue??'')
          :(r.udise?.classDescCanon.isNotEmpty==true?r.udise!.classDescCanon:r.udise?.classIdCanon??'');
      return c==selectedClass;
    }).toList();
  }

  // Printable values are read only from the raw DB JSON.
  String valueFor(ComparisonRow r,String requested){
    final raw=source=='PSP'?r.psp!.raw:r.udise!.raw;
    final target=normKey(requested);
    for (final e in raw.entries) {
      if (normKey(e.key) == target) {
        final v=e.value?.toString().trim()??'';
        if (v.isNotEmpty) {
          return v;
        }
      }
    }
    if (target == 'admissiondate' || target == 'dateofadmission' || target == 'admissiondt') {
      for (final e in raw.entries) {
        final n=normKey(e.key);
        if (n.contains('admission') && (n.contains('date') || n.contains('dt'))) {
          final v=e.value?.toString().trim()??'';
          if (v.isNotEmpty) {
            return v;
          }
        }
      }
    }
    return '';
  }

  final selected=fields.map((k){
    for (final e in entries) {
      if (e.key == k) {
        final header=(customHeaders[k]??e.value).trim();
        return MapEntry(k,header.isEmpty?e.value:header);
      }
    }
    return null;
  }).whereType<MapEntry<String,String>>().toList();

  final table=<List<String>>[];
  for(var i=0;i<data.length;i++){
    table.add(['${i+1}',...selected.map((e)=>valueFor(data[i],e.key))]);
  }

  await NativePrintService.printTable(
    title:'($pspCode) ($udiseCode) $schoolName',
    subtitle:'${scope=='ALL'?'All':'Class : $selectedClass'}    $source REPORT    Student Count : $table.length',
    columns:['S.No',...selected.map((e)=>e.value)],
    rows:table,
    settings:settings,
  );
}
