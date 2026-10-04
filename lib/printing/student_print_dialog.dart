import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/print_bloc.dart';
import '../data/repositories/print_repository.dart';
import '../matching/models.dart';
import 'native_print_service.dart';

Future<PrintSettings?> showPrintPageSetup(
  BuildContext context, {
  required PrintSettings initial,
}) async {
  final cubit = PrintSettingsBloc(repository: context.read<PrintRepository>(), initial: initial);
  final topController = TextEditingController(text: initial.marginTop.toString());
  final rightController = TextEditingController(text: initial.marginRight.toString());
  final bottomController = TextEditingController(text: initial.marginBottom.toString());
  final leftController = TextEditingController(text: initial.marginLeft.toString());
  final cellVerticalController = TextEditingController(text: initial.cellVerticalPadding.toString());
  final cellHorizontalController = TextEditingController(text: initial.cellHorizontalPadding.toString());
  try {
    return await showDialog<PrintSettings>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<PrintSettingsBloc, PrintSettingsState>(
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
                  onChanged: context.read<PrintSettingsBloc>().setPaper,
                ),
                DropdownButtonFormField<String>(
                  initialValue: s.orientation,
                  decoration: const InputDecoration(labelText: 'Orientation'),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto (based on columns)')),
                    DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                    DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                  ],
                  onChanged: context.read<PrintSettingsBloc>().setOrientation,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Margins (mm)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _MarginField(
                    label: 'Top',
                    controller: topController,
                    onChanged: (v) => context.read<PrintSettingsBloc>().setMarginTop(int.tryParse(v) ?? s.marginTop),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _MarginField(
                    label: 'Right',
                    controller: rightController,
                    onChanged: (v) => context.read<PrintSettingsBloc>().setMarginRight(int.tryParse(v) ?? s.marginRight),
                  )),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _MarginField(
                    label: 'Bottom',
                    controller: bottomController,
                    onChanged: (v) => context.read<PrintSettingsBloc>().setMarginBottom(int.tryParse(v) ?? s.marginBottom),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _MarginField(
                    label: 'Left',
                    controller: leftController,
                    onChanged: (v) => context.read<PrintSettingsBloc>().setMarginLeft(int.tryParse(v) ?? s.marginLeft),
                  )),
                ]),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cell Padding (mm)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _MarginField(
                    label: 'Vertical',
                    controller: cellVerticalController,
                    onChanged: (v) => context.read<PrintSettingsBloc>().setCellVerticalPadding(int.tryParse(v) ?? s.cellVerticalPadding),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _MarginField(
                    label: 'Horizontal',
                    controller: cellHorizontalController,
                    onChanged: (v) => context.read<PrintSettingsBloc>().setCellHorizontalPadding(int.tryParse(v) ?? s.cellHorizontalPadding),
                  )),
                ]),
                Row(children: [
                  const Text('Table font'),
                  Expanded(child: Slider(
                    min: 7, max: 16, divisions: 9, value: s.fontSize,
                    label: '${s.fontSize.toStringAsFixed(0)} pt',
                    onChanged: context.read<PrintSettingsBloc>().setFontSize,
                  )),
                  Text('${s.fontSize.toStringAsFixed(0)} pt'),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-fit columns'),
                  value: s.autoFit,
                  onChanged: context.read<PrintSettingsBloc>().setAutoFit,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat table header'),
                  value: s.repeatHeader,
                  onChanged: context.read<PrintSettingsBloc>().setRepeatHeader,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Page number'),
                  value: s.pageNumber,
                  onChanged: context.read<PrintSettingsBloc>().setPageNumber,
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: s.saving
                    ? null
                    : () async {
                        final bloc = context.read<PrintSettingsBloc>();
                        try {
                          await bloc.persist();
                          if (context.mounted) {
                            // Read state after the persist event has completed.
                            // The builder snapshot may be older than the saved state.
                            Navigator.pop(context, bloc.state.settings);
                          }
                        } catch (_) {
                          // Keep the dialog open; the Bloc exposes the error and
                          // the user can retry.
                        }
                      },
                child: Text(s.saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    topController.dispose();
    rightController.dispose();
    bottomController.dispose();
    leftController.dispose();
    cellVerticalController.dispose();
    cellHorizontalController.dispose();
    await cubit.close();
  }
}

class _MarginField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _MarginField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: false),
    decoration: InputDecoration(
      labelText: label,
      suffixText: 'mm',
      isDense: true,
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged,
  );
}

Future<void> showStudentPrintDialog(
  BuildContext context, {
  required List<ComparisonRow> rows,
  required String schoolName,
  required String pspCode,
  required String udiseCode,
  required PrintSettings settings,
}) async {
  final cubit = PrintReportBloc(repository: context.read<PrintRepository>(), rows: rows);
  try {
    cubit.initialize();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<PrintReportBloc, PrintReportState>(
          builder: (context, s) {
            final scheme = Theme.of(context).colorScheme;
            final bloc = context.read<PrintReportBloc>();
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
                                          key: ValueKey('header-$key'),
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
