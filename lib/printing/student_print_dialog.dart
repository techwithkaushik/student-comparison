import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/print_cubit.dart';
import '../matching/models.dart';
import 'native_print_service.dart';

Future<PrintSettings?> showPrintPageSetup(
  BuildContext context, {
  required PrintSettings initial,
}) async {
  final cubit = PrintSettingsCubit(initial);
  try {
    return await showDialog<PrintSettings>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<PrintSettingsCubit, PrintSettings>(
          builder: (context, s) => AlertDialog(
            title: const Text('Print Page Setup'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: s.paper,
                  decoration: const InputDecoration(labelText: 'Paper Size'),
                  items: const [
                    DropdownMenuItem(value: 'A4', child: Text('A4')),
                    DropdownMenuItem(value: 'A5', child: Text('A5')),
                    DropdownMenuItem(value: 'A3', child: Text('A3')),
                    DropdownMenuItem(value: 'LETTER', child: Text('Letter')),
                    DropdownMenuItem(value: 'LEGAL', child: Text('Legal')),
                  ],
                  onChanged: context.read<PrintSettingsCubit>().setPaper,
                ),
                DropdownButtonFormField<String>(
                  initialValue: s.orientation,
                  decoration: const InputDecoration(labelText: 'Orientation'),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto (based on columns)')),
                    DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                    DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                  ],
                  onChanged: context.read<PrintSettingsCubit>().setOrientation,
                ),
                Row(children: [
                  const Text('Margin'),
                  Expanded(child: Slider(
                    min: 2, max: 20, divisions: 18, value: s.margin.toDouble(),
                    label: '${s.margin} mm',
                    onChanged: context.read<PrintSettingsCubit>().setMargin,
                  )),
                  Text('${s.margin} mm'),
                ]),
                Row(children: [
                  const Text('Table font'),
                  Expanded(child: Slider(
                    min: 7, max: 16, divisions: 9, value: s.fontSize,
                    label: '${s.fontSize.toStringAsFixed(0)} pt',
                    onChanged: context.read<PrintSettingsCubit>().setFontSize,
                  )),
                  Text('${s.fontSize.toStringAsFixed(0)} pt'),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-fit columns'),
                  value: s.autoFit,
                  onChanged: context.read<PrintSettingsCubit>().setAutoFit,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat table header'),
                  value: s.repeatHeader,
                  onChanged: context.read<PrintSettingsCubit>().setRepeatHeader,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Page number'),
                  value: s.pageNumber,
                  onChanged: context.read<PrintSettingsCubit>().setPageNumber,
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await context.read<PrintSettingsCubit>().persist();
                  if (context.mounted) Navigator.pop(context, s);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    await cubit.close();
  }
}

Future<void> showStudentPrintDialog(
  BuildContext context, {
  required List<ComparisonRow> rows,
  required String schoolName,
  required String pspCode,
  required String udiseCode,
  required PrintSettings settings,
}) async {
  final cubit = PrintReportCubit(rows);
  try {
    await cubit.initialize();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<PrintReportCubit, PrintReportState>(
          builder: (context, s) {
            final scheme = Theme.of(context).colorScheme;
            final bloc = context.read<PrintReportCubit>();
            return Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .90,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(
                        width: 42, height: 4, margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      )),
                      Row(children: [
                        Expanded(child: Text('Print Report',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ]),
                      Text(
                        'Current filtered list: ${rows.length} student(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'PSP', label: Text('PSP')),
                          ButtonSegment(value: 'UDISE', label: Text('UDISE')),
                        ],
                        selected: {s.source},
                        onSelectionChanged: (v) => bloc.setSource(v.first),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ALL', label: Text('Current List')),
                          ButtonSegment(value: 'CLASS', label: Text('Selected Class')),
                        ],
                        selected: {s.scope},
                        onSelectionChanged: (v) => bloc.setScope(v.first),
                      ),
                      if (s.scope == 'CLASS')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: s.selectedClass.isEmpty ? null : s.selectedClass,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Class'),
                            items: s.classes.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('Class $c', overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (v) { if (v != null) bloc.setClass(v); },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text(
                          'Selected columns (${s.fields.length})',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        )),
                        TextButton(onPressed: bloc.selectAll, child: const Text('All')),
                        TextButton(onPressed: bloc.clearFields, child: const Text('Clear')),
                      ]),
                      if (s.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(s.error!, style: TextStyle(color: scheme.error)),
                        ),
                      SizedBox(
                        height: 150,
                        child: s.loadingPreset
                            ? const Center(child: CircularProgressIndicator())
                            : s.fields.isEmpty
                                ? const Center(child: Text('No columns selected'))
                                : ReorderableListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    itemCount: s.fields.length,
                                    onReorder: bloc.reorder,
                                    itemBuilder: (context, index) {
                                      final key = s.fields[index];
                                      final header = s.customHeaders[key] ?? key;
                                      return ListTile(
                                        key: ValueKey('selected-column-$key'),
                                        dense: true,
                                        visualDensity: const VisualDensity(vertical: -3),
                                        contentPadding: const EdgeInsets.only(left: 4, right: 2),
                                        leading: const Icon(Icons.drag_handle, size: 20),
                                        title: TextFormField(
                                          key: ValueKey('header-$key-$header'),
                                          initialValue: header,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            labelText: 'Column heading',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => bloc.setHeader(key, v),
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Remove column',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.close, size: 19),
                                          onPressed: () => bloc.toggleField(key, false),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Available DB fields (${s.entries.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 2),
                      Expanded(
                        child: ListView.builder(
                          cacheExtent: 200,
                          itemCount: s.entries.length,
                          itemBuilder: (context, index) {
                            final e = s.entries[index];
                            final checked = s.fields.contains(e.key);
                            return CheckboxListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -2),
                              contentPadding: EdgeInsets.zero,
                              title: Text(s.customHeaders[e.key] ?? e.value, overflow: TextOverflow.ellipsis),
                              subtitle: Text(e.key, overflow: TextOverflow.ellipsis),
                              value: checked,
                              onChanged: (v) => bloc.toggleField(e.key, v == true),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton.icon(
                          onPressed: !s.valid ? null : () async {
                            try {
                              await bloc.printReport(
                                schoolName: schoolName,
                                pspCode: pspCode,
                                udiseCode: udiseCode,
                                settings: settings,
                              );
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Print failed: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Print'),
                        )),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  } finally {
    await cubit.close();
  }
}
