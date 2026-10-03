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

    void addRawKey(String key) {
      final trimmed=key.trim();
      if (trimmed.isEmpty || normKey(trimmed) == 'sno') {
        return;
      }
      if (seen.add(trimmed)) {
        out.add(MapEntry(trimmed,label(trimmed)));
      }
    }

    // Printable columns come exclusively from the selected source's raw DB JSON.
    for(final r in sourceRows()) {
      final raw=source=='PSP'?r.psp!.raw:r.udise!.raw;
      for(final key in raw.keys) {
        addRawKey(key);
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
  var classes=buildClasses();

  Future<void> restoreColumnPreset() async {
    final preset=await NativePrintService.loadColumnPreferences(source:source);
    if (preset == null) {
      fields=entries.map((e)=>e.key).toList();
      customHeaders={for(final e in entries)e.key:e.value};
      return;
    }

    final byNormalized=<String,String>{
      for(final e in entries) normKey(e.key):e.key,
    };
    final savedFields=(preset['fields'] as List<dynamic>? ?? const <dynamic>[]);
    final savedHeaders=(preset['headers'] as Map<dynamic,dynamic>? ?? const <dynamic,dynamic>{});

    final restoredFields=<String>[];
    for(final item in savedFields) {
      final actual=byNormalized[normKey(item.toString())];
      if (actual != null && !restoredFields.contains(actual)) {
        restoredFields.add(actual);
      }
    }

    fields=restoredFields;
    customHeaders={for(final e in entries)e.key:e.value};
    for(final entry in savedHeaders.entries) {
      final actual=byNormalized[normKey(entry.key.toString())];
      if (actual != null) {
        final header=entry.value?.toString() ?? '';
        if (header.trim().isNotEmpty) {
          customHeaders[actual]=header;
        }
      }
    }
  }

  await restoreColumnPreset();

  final ok=await showModalBottomSheet<bool>(
    context:context,
    isScrollControlled:true,
    useSafeArea:true,
    backgroundColor:Colors.transparent,
    builder:(_)=>StatefulBuilder(builder:(context,set){
      final scheme=Theme.of(context).colorScheme;
      return Material(
        color:scheme.surface,
        borderRadius:const BorderRadius.vertical(top:Radius.circular(22)),
        clipBehavior:Clip.antiAlias,
        child:SizedBox(
          height:MediaQuery.sizeOf(context).height*0.90,
          child:Padding(
            padding:const EdgeInsets.fromLTRB(14,8,14,10),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Center(
                  child:Container(
                    width:42,
                    height:4,
                    margin:const EdgeInsets.only(bottom:8),
                    decoration:BoxDecoration(
                      color:scheme.onSurfaceVariant.withValues(alpha:.35),
                      borderRadius:BorderRadius.circular(20),
                    ),
                  ),
                ),
                Row(children:[
                  Expanded(
                    child:Text(
                      'Print Report',
                      style:Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight:FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:'Close',
                    onPressed:()=>Navigator.pop(context,false),
                    icon:const Icon(Icons.close_rounded),
                  ),
                ]),
                const SizedBox(height:2),
                Text(
                  'Current filtered list: ${rows.length} student(s)',
                  style:Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height:10),
                Row(children:[
                  Expanded(child:SegmentedButton<String>(
                    segments:const[
                      ButtonSegment(value:'PSP',label:Text('PSP')),
                      ButtonSegment(value:'UDISE',label:Text('UDISE')),
                    ],
                    selected:{source},
                    onSelectionChanged:(v) async {
                      final nextSource=v.first;
                      set((){
                        source=nextSource;
                        selectedClass='';
                        entries=buildAvailableFields();
                        classes=buildClasses();
                        fields=[];
                        customHeaders={for(final e in entries)e.key:e.value};
                      });
                      await restoreColumnPreset();
                      if (context.mounted) {
                        set(());
                      }
                    },
                  )),
                ]),
                const SizedBox(height:10),
                SegmentedButton<String>(
                  segments:const[
                    ButtonSegment(value:'ALL',label:Text('Current List')),
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
                    style:Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight:FontWeight.w800,
                    ),
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
                    border:Border.all(color:scheme.outlineVariant),
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
                    style:Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight:FontWeight.w800,
                    ),
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
                const SizedBox(height:6),
                Row(children:[
                  Expanded(
                    child:OutlinedButton(
                      onPressed:()=>Navigator.pop(context,false),
                      child:const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width:10),
                  Expanded(
                    child:FilledButton.icon(
                      onPressed:()=>Navigator.pop(context,true),
                      icon:const Icon(Icons.print_rounded),
                      label:const Text('Print'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
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
        if (target == 'gettingfreeeducation') {
          final normalizedValue=v.toLowerCase();
          final yesValue=normalizedValue == 'yes' ||
              normalizedValue == 'y' ||
              normalizedValue == 'true' ||
              normalizedValue == '1';
          return yesValue ? 'YES' : 'NO';
        }
        return v;
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
  for(final row in data){
    table.add(selected.map((e)=>valueFor(row,e.key)).toList());
  }

  await NativePrintService.printTable(
    title:'($pspCode) ($udiseCode) $schoolName',
    subtitle:'${scope=='ALL'?'All':'Class : $selectedClass'}    $source REPORT    Student Count : $table.length',
    columns:selected.map((e)=>e.value).toList(),
    rows:table,
    settings:settings,
  );

  // Remember the exact raw-field selection, order and renamed headings for the next print.
  await NativePrintService.saveColumnPreferences(
    source:source,
    fields:fields,
    headers:customHeaders,
  );
}
