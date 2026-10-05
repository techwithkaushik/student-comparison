import 'package:flutter/material.dart';

class ComparisonSummarySection extends StatelessWidget {
  final int all, matchedCount, mismatchCount, rte, pspOnly, udiseOnly, remarks;
  final int name, dob, father, mother, classMismatch, gender, category, religion, aadhaar, aadhaarMissing, mobile;
  final String sourceFilter, classFilter;
  final Set<String> statusFilters, diffFilters, apaarStatusFilters, aadhaarStatusFilters;
  final List<String> classes;
  final Set<String> apaarStatusOptions, aadhaarStatusOptions;
  final String Function(String) apaarStatusLabel, aadhaarStatusLabel;
  final ValueChanged<String> onSourceChanged, onStatusToggle, onApaarToggle, onAadhaarToggle, onClassChanged;
  final ValueChanged<Set<String>> onDiffChanged;
  final VoidCallback onClearFilters, onPrint;

  const ComparisonSummarySection({
    super.key, required this.all, required this.matchedCount, required this.mismatchCount,
    required this.rte, required this.pspOnly, required this.udiseOnly, required this.remarks,
    required this.name, required this.dob, required this.father, required this.mother,
    required this.classMismatch, required this.gender, required this.category, required this.religion,
    required this.aadhaar, required this.aadhaarMissing, required this.mobile,
    required this.sourceFilter, required this.classFilter, required this.statusFilters,
    required this.diffFilters, required this.apaarStatusFilters, required this.aadhaarStatusFilters,
    required this.classes, required this.apaarStatusOptions, required this.aadhaarStatusOptions,
    required this.apaarStatusLabel, required this.aadhaarStatusLabel, required this.onSourceChanged,
    required this.onStatusToggle, required this.onDiffChanged, required this.onApaarToggle,
    required this.onAadhaarToggle, required this.onClassChanged, required this.onClearFilters, required this.onPrint,
  });

  int get activeFilterCount => statusFilters.length + diffFilters.length +
      apaarStatusFilters.length + aadhaarStatusFilters.length +
      (classFilter.isEmpty ? 0 : 1) + (sourceFilter == 'ALL' ? 0 : 1);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: SizedBox(
      height: activeFilterCount == 0 ? 36 : 64,
      child: Column(children: [
        SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
          _SourceChip('All', Icons.select_all_rounded, sourceFilter == 'ALL', () => onSourceChanged('ALL')),
          _SourceChip('PSP', Icons.description_rounded, sourceFilter == 'PSP', () => onSourceChanged('PSP')),
          _SourceChip('UDISE', Icons.school_rounded, sourceFilter == 'UDISE', () => onSourceChanged('UDISE')),
          const SizedBox(width: 5),
          ActionChip(avatar: const Icon(Icons.tune_rounded, size: 17), label: Text(activeFilterCount == 0 ? 'Filters' : 'Filters $activeFilterCount'), onPressed: () => _showFilters(context)),
          const SizedBox(width: 2),
          IconButton(tooltip: 'Print', visualDensity: VisualDensity.compact, onPressed: onPrint, icon: const Icon(Icons.print_rounded, size: 21)),
        ])),
        if (activeFilterCount > 0) SizedBox(height: 26, child: ListView(scrollDirection: Axis.horizontal, children: [
          if (sourceFilter != 'ALL') _MiniFilter(sourceFilter),
          if (classFilter.isNotEmpty) _MiniFilter('Class $classFilter'),
          ...statusFilters.map((e) => _MiniFilter(_statusLabel(e))),
          ...diffFilters.map((e) => _MiniFilter(_diffLabel(e))),
          ...apaarStatusFilters.map((e) => _MiniFilter('APAAR: ${apaarStatusLabel(e)}')),
          ...aadhaarStatusFilters.map((e) => _MiniFilter('Aadhaar: ${aadhaarStatusLabel(e)}')),
        ])),
      ]),
    ),
  );

  String _statusLabel(String s) => switch (s) {
    'MATCHED' => 'Matched', 'MISMATCH' => 'Mismatch', 'PSP_ONLY' => 'PSP only',
    'UDISE_ONLY' => 'UDISE only', 'REMARKED' => 'Remarked', 'RTE' => 'RTE', _ => s,
  };
  String _diffLabel(String s) => switch (s) {
    'NAME_MISMATCH' => 'Name', 'DOB_MISMATCH' => 'DOB', 'FATHER_MISMATCH' => 'Father',
    'MOTHER_MISMATCH' => 'Mother', 'CLASS_MISMATCH' => 'Class', 'GENDER_MISMATCH' => 'Gender',
    'CATEGORY_MISMATCH' => 'Category', 'RELIGION_MISMATCH' => 'Religion',
    'AADHAAR_MISMATCH' => 'Aadhaar', 'AADHAAR_NOT_FOUND' => 'Aadhaar missing',
    'MOBILE_MISMATCH' => 'Mobile', _ => s,
  };

  Future<void> _showFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (ctx) => _FilterSheet(
      sourceFilter: sourceFilter, statusFilters: statusFilters, diffFilters: diffFilters,
      apaarStatusFilters: apaarStatusFilters, aadhaarStatusFilters: aadhaarStatusFilters,
      classes: classes, classFilter: classFilter,
      diffOptions: {'NAME_MISMATCH':name,'DOB_MISMATCH':dob,'FATHER_MISMATCH':father,'MOTHER_MISMATCH':mother,
        'CLASS_MISMATCH':classMismatch,'GENDER_MISMATCH':gender,'CATEGORY_MISMATCH':category,'RELIGION_MISMATCH':religion,
        'AADHAAR_MISMATCH':aadhaar,'AADHAAR_NOT_FOUND':aadhaarMissing,'MOBILE_MISMATCH':mobile},
      apaarStatusOptions: apaarStatusOptions, aadhaarStatusOptions: aadhaarStatusOptions,
      apaarStatusLabel: apaarStatusLabel, aadhaarStatusLabel: aadhaarStatusLabel,
      onSourceChanged: onSourceChanged, onStatusToggle: onStatusToggle, onDiffChanged: onDiffChanged,
      onApaarToggle: onApaarToggle, onAadhaarToggle: onAadhaarToggle, onClassChanged: onClassChanged,
      onClearFilters: onClearFilters,
    ),
  );
}

class _FilterSheet extends StatelessWidget {
  final String sourceFilter, classFilter;
  final Set<String> statusFilters, diffFilters, apaarStatusFilters, aadhaarStatusFilters;
  final List<String> classes;
  final Map<String,int> diffOptions;
  final Set<String> apaarStatusOptions, aadhaarStatusOptions;
  final String Function(String) apaarStatusLabel, aadhaarStatusLabel;
  final ValueChanged<String> onSourceChanged, onStatusToggle, onApaarToggle, onAadhaarToggle, onClassChanged;
  final ValueChanged<Set<String>> onDiffChanged;
  final VoidCallback onClearFilters;

  const _FilterSheet({required this.sourceFilter, required this.statusFilters, required this.diffFilters,
    required this.apaarStatusFilters, required this.aadhaarStatusFilters, required this.classes, required this.classFilter,
    required this.diffOptions, required this.apaarStatusOptions, required this.aadhaarStatusOptions,
    required this.apaarStatusLabel, required this.aadhaarStatusLabel, required this.onSourceChanged,
    required this.onStatusToggle, required this.onDiffChanged, required this.onApaarToggle, required this.onAadhaarToggle,
    required this.onClassChanged, required this.onClearFilters});

  @override
  Widget build(BuildContext context) => SafeArea(child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
    child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
      const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _Section('Source', Icons.source_rounded, Wrap(spacing: 7, children: [
        _Choice('All', Icons.select_all_rounded, sourceFilter == 'ALL', () => onSourceChanged('ALL')),
        _Choice('PSP', Icons.description_rounded, sourceFilter == 'PSP', () => onSourceChanged('PSP')),
        _Choice('UDISE', Icons.school_rounded, sourceFilter == 'UDISE', () => onSourceChanged('UDISE')),
      ])),
      _Section('Comparison Status', Icons.compare_arrows_rounded, Wrap(spacing: 7, runSpacing: 7, children: [
        _F('Matched', matchedCount:null, icon:Icons.check_circle_rounded, selected:statusFilters.contains('MATCHED'), onTap:()=>onStatusToggle('MATCHED')),
        _F('Mismatch', matchedCount:null, icon:Icons.error_rounded, selected:statusFilters.contains('MISMATCH'), onTap:()=>onStatusToggle('MISMATCH')),
        _F('PSP only', matchedCount:null, icon:Icons.person_add_rounded, selected:statusFilters.contains('PSP_ONLY'), onTap:()=>onStatusToggle('PSP_ONLY')),
        _F('UDISE only', matchedCount:null, icon:Icons.person_search_rounded, selected:statusFilters.contains('UDISE_ONLY'), onTap:()=>onStatusToggle('UDISE_ONLY')),
        _F('Remarked', matchedCount:null, icon:Icons.comment_rounded, selected:statusFilters.contains('REMARKED'), onTap:()=>onStatusToggle('REMARKED')),
        _F('RTE', matchedCount:null, icon:Icons.verified_rounded, selected:statusFilters.contains('RTE'), onTap:()=>onStatusToggle('RTE')),
      ])),
      _Section('Class', Icons.school_rounded, DropdownButtonFormField<String>(
        initialValue: classFilter.isEmpty ? '' : classFilter,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.school_rounded), labelText: 'Select class'),
        items: [const DropdownMenuItem(value:'',child:Text('All classes')), ...classes.map((v)=>DropdownMenuItem(value:v,child:Text('Class $v')))],
        onChanged: (v)=>onClassChanged(v ?? ''),
      )),
      _Section('Differences', Icons.rule_rounded, Wrap(spacing:7,runSpacing:7,children:diffOptions.entries.map((e)=>FilterChip(
        avatar:Icon(_diffIcon(e.key),size:17), label:Text(e.key == 'AADHAAR_NOT_FOUND' ? 'Aadhaar missing ${e.value}' : '${e.key.replaceAll('_MISMATCH','').replaceAll('_',' ')} ${e.value}'),
        selected:diffFilters.contains(e.key), onSelected:(_)=>{ final next=<String>{...diffFilters}; if(!next.add(e.key))next.remove(e.key); onDiffChanged(next); },
      )).toList())),
      if(apaarStatusOptions.isNotEmpty)_Section('APAAR Status',Icons.badge_rounded,Wrap(spacing:7,runSpacing:7,children:apaarStatusOptions.map((k)=>FilterChip(
        avatar:const Icon(Icons.badge_rounded,size:17),label:Text(apaarStatusLabel(k)),selected:apaarStatusFilters.contains(k),onSelected:(_)=>onApaarToggle(k))).toList())),
      if(aadhaarStatusOptions.isNotEmpty)_Section('Aadhaar Status',Icons.fingerprint_rounded,Wrap(spacing:7,runSpacing:7,children:aadhaarStatusOptions.map((k)=>FilterChip(
        avatar:const Icon(Icons.fingerprint_rounded,size:17),label:Text(aadhaarStatusLabel(k)),selected:aadhaarStatusFilters.contains(k),onSelected:(_)=>onAadhaarToggle(k))).toList())),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:onClearFilters,icon:const Icon(Icons.clear_all_rounded),label:const Text('Clear all filters')),
    ]),
  ));

  IconData _diffIcon(String k)=>switch(k){
    'NAME_MISMATCH'=>Icons.person_rounded,'DOB_MISMATCH'=>Icons.cake_rounded,'FATHER_MISMATCH'=>Icons.man_rounded,
    'MOTHER_MISMATCH'=>Icons.woman_rounded,'CLASS_MISMATCH'=>Icons.school_rounded,'GENDER_MISMATCH'=>Icons.wc_rounded,
    'CATEGORY_MISMATCH'=>Icons.category_rounded,'RELIGION_MISMATCH'=>Icons.diversity_3_rounded,
    'AADHAAR_MISMATCH'||'AADHAAR_NOT_FOUND'=>Icons.fingerprint_rounded,'MOBILE_MISMATCH'=>Icons.phone_rounded,_=>Icons.filter_alt_rounded};
}

class _Section extends StatelessWidget {
  final String title; final IconData icon; final Widget child;
  const _Section(this.title,this.icon,this.child);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[Icon(icon,size:17),const SizedBox(width:7),Text(title,style:const TextStyle(fontWeight:FontWeight.w800))])),child]));
}
class _SourceChip extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _SourceChip(this.label,this.icon,this.selected,this.onTap);
  @override Widget build(BuildContext c)=>ChoiceChip(avatar:Icon(icon,size:16),label:Text(label),selected:selected,onSelected:(_)=>onTap(),visualDensity:VisualDensity.compact);
}
class _Choice extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _Choice(this.label,this.icon,this.selected,this.onTap);
  @override Widget build(BuildContext c)=>ChoiceChip(avatar:Icon(icon,size:17),label:Text(label),selected:selected,onSelected:(_)=>onTap());
}
class _F extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _F({required this.label,required this.icon,required this.selected,required this.onTap});
  @override Widget build(BuildContext c)=>FilterChip(avatar:Icon(icon,size:17),label:Text(label),selected:selected,onSelected:(_)=>onTap(),visualDensity:VisualDensity.compact);
}
class _MiniFilter extends StatelessWidget {
  final String label; const _MiniFilter(this.label);
  @override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.only(right:5),child:Chip(label:Text(label,style:const TextStyle(fontSize:10)),visualDensity:VisualDensity.compact));
}
