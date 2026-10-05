import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/comparison_bloc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../matching/models.dart';
import '../presentation/comparison/widgets/comparison_student_row.dart';
import '../presentation/comparison/widgets/comparison_summary.dart';
import '../printing/native_print_service.dart';
import '../printing/student_print_dialog.dart';

String expectedSourceJsonFileName({required bool psp, required String code}) {
  final normalizedCode = psp ? code.trim().toLowerCase() : code.trim();
  return '${psp ? 'psp_' : 'udise_'}$normalizedCode.json';
}

class ComparisonDashboardScreen extends StatefulWidget {
  final List<ComparisonRow> initialRows;
  final String schoolName;

  const ComparisonDashboardScreen({
    super.key,
    this.initialRows = const <ComparisonRow>[],
    this.schoolName = 'Comparison',
  });

  @override
  State<ComparisonDashboardScreen> createState() =>
      _ComparisonDashboardScreenState();
}

class _ComparisonDashboardScreenState
    extends State<ComparisonDashboardScreen> {
  ComparisonBloc get _bloc => context.read<ComparisonBloc>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<ComparisonRow> get _rows => _bloc.state.rows;
  bool get _loadingData => _bloc.state.status == ComparisonStatus.loading || _bloc.state.status == ComparisonStatus.initial;
  String? get _dataError => _bloc.state.error;
  String get _classFilter => _bloc.state.classFilter;
  bool get _searchActive => _bloc.state.searchActive;
  Set<String> get _remarkKeys => _bloc.state.remarkKeys;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<ComparisonBloc>().add(
      ComparisonLoadRequested(initialRows: widget.initialRows),
    );
  }


  Future<List<Map<String, dynamic>>> _decodeJsonRows(Uint8List bytes, String label) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    List<dynamic> rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      rows = decoded['data'] as List;
    } else if (decoded is Map<String, dynamic> && decoded['result'] is List) {
      rows = decoded['result'] as List;
    } else if (decoded is Map<String, dynamic> &&
        decoded['result'] is Map<String, dynamic> &&
        decoded['result']['data'] is List) {
      rows = decoded['result']['data'] as List;
    } else {
      throw Exception('No $label student records found.');
    }
    final out = rows.whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    if (out.isEmpty) throw Exception('No valid $label student records found.');
    return out;
  }

  Future<void> _importJson(bool pspImport) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
      final fileName = file.name.trim();
      final profile = await _bloc.getActiveSchoolProfile();
      if (profile == null) {
        throw StateError(
          'Please create and select a school profile before importing JSON.',
        );
      }

      final expectedCode = pspImport
          ? profile['pspCode']?.toString().trim().toUpperCase() ?? ''
          : profile['udiseCode']?.toString().trim() ?? '';
      final sourceLabel = pspImport ? 'PSP' : 'UDISE';
      final expectedFileName = expectedSourceJsonFileName(
        psp: pspImport,
        code: expectedCode,
      );

      // Exact school-code filename. Examples:
      // PSP: p12345 -> psp_p12345.json
      // UDISE: 01234567890 -> udise_01234567890.json
      if (fileName.toLowerCase() != expectedFileName.toLowerCase()) {
        throw FormatException(
          'Invalid $sourceLabel file name. Expected "$expectedFileName", but "$fileName" was selected.',
        );
      }

      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Unable to read selected JSON file.');
      }

      final rows = await _decodeJsonRows(
        bytes,
        pspImport ? 'PSP' : 'UDISE',
      );
      if (pspImport) {
        await _bloc.importJsonRows(psp: true, rows: rows);
      } else {
        await _bloc.importJsonRows(psp: false, rows: rows);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$sourceLabel data imported for ${profile['schoolName']?.toString() ?? 'selected school'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _bloc.setError('JSON import failed: $e');
    }
  }

  Future<void> _importLegacyRemarks() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Unable to read selected SQLite file.');

      final imported = await _bloc.importLegacyRemarks(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported == 0
                ? 'No matching remarks found in the old database.'
                : '$imported old remarks imported successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _bloc.setError('Old remarks import failed: $e');
    }
  }

  Future<void> _exportCsv() async {
    try {
      final rows = _filteredRows;
      final data = <List<dynamic>>[
        ['Status', 'PSP NIC ID', 'UDISE PEN', 'PSP Name', 'UDISE Name', 'PSP Class', 'UDISE Class', 'DOB PSP', 'DOB UDISE', 'Differences'],
        ...rows.map((r) => [
          _statusText(r), r.psp?.nicId ?? '', r.udise?.studentCodeNat ?? '',
          r.psp?.studentName ?? '', r.udise?.studentName ?? '',
          r.psp?.studyingClass ?? '', r.udise?.classDesc ?? r.udise?.classId ?? '',
          r.psp?.dob ?? '', r.udise?.dob ?? '', r.diffs.join('; '),
        ]),
      ];
      final bytes = Uint8List.fromList(utf8.encode('﻿${const ListToCsvConverter().convert(data)}'));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export comparison CSV',
        fileName: 'student_comparison.csv',
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported successfully.')));
      }
    } catch (e) {
      if (mounted) _bloc.setError('CSV export failed: $e');
    }
  }

  Future<void> _exportSourceJson(bool pspExport) async {
    try {
      final rows = await _bloc.loadSourceRows(psp: pspExport);
      final bytes = Uint8List.fromList(utf8.encode(
        const JsonEncoder.withIndent('  ').convert(rows),
      ));
      final profile = await _bloc.getActiveSchoolProfile();
      final code = pspExport
          ? (profile == null ? '' : profile['pspCode']?.toString().trim() ?? '')
          : (profile == null ? '' : profile['udiseCode']?.toString().trim() ?? '');
      if (code.isEmpty) {
        throw StateError('No active school profile code is available.');
      }
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${pspExport ? 'PSP' : 'UDISE'} JSON',
        fileName: expectedSourceJsonFileName(psp: pspExport, code: code),
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON exported successfully.')));
      }
    } catch (e) {
      if (mounted) _bloc.setError('JSON export failed: $e');
    }
  }

  String _key(String value) => value.trim().toUpperCase();

  String _remarkKeyFor(ComparisonRow row) {
    final p = row.psp?.nicId ?? '';
    final u = row.udise?.studentCodeNat ?? '';
    return '${_key(p)}|${_key(u)}';
  }


  Map<String, dynamic>? _remarkFor(ComparisonRow row) =>
      _bloc.state.remarks[_remarkKeyFor(row)];

  String _pspRte(ComparisonRow row) {
    final raw = row.psp?.raw ?? const <String, dynamic>{};
    final value = raw['Getting Free Education']?.toString().trim() ?? '';
    final normalized = value.toLowerCase();
    final isRte = normalized == 'yes' || normalized == 'y' ||
        normalized == 'true' || normalized == '1';
    return isRte ? 'RTE' : 'NON-RTE';
  }

  Future<void> _editRemark(ComparisonRow row) async {
    final existing = _remarkFor(row);
    final controller = TextEditingController(text: existing?['remark']?.toString() ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit Remark', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: controller, autofocus: true, minLines: 3, maxLines: 6,
            decoration: const InputDecoration(labelText: 'Remark', hintText: 'Enter remark...', border: OutlineInputBorder(), alignLabelWithHint: true),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.save_rounded, size: 17), label: const Text('Save')),
          ],
        ),
      );
      if (saved != true) return;
      final text = controller.text.trim();
      if (text.isEmpty) {
        if (!mounted) return;
        await _bloc.deleteRemark(row);
      } else {
        if (!mounted) return;
        await _bloc.saveRemark(row: row, remark: text);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remark update failed: $e')));
    } finally {
      controller.dispose();
    }
  }

  bool _hasRemark(ComparisonRow row) =>
      _remarkKeys.contains(_remarkKeyFor(row));

  Future<void> _printReport() async {
    try {
      final profile = await _bloc.getActiveSchoolProfile();
      if (profile == null) {
        throw StateError('Please select a school profile before printing.');
      }
      final settings = await NativePrintService.loadSettings();
      if (!mounted) return;
      await showStudentPrintDialog(
        context,
        // Print exactly the list currently visible after all active filters/search.
        rows: _filteredRows,
        schoolName: profile['schoolName']?.toString() ?? widget.schoolName,
        pspCode: profile['pspCode']?.toString() ?? '',
        udiseCode: profile['udiseCode']?.toString() ?? '',
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print setup failed: $e')),
        );
      }
    }
  }

  Future<void> _printPageSetup() async {
    try {
      final current = await NativePrintService.loadSettings();
      if (!mounted) return;
      await showPrintPageSetup(context, initial: current);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print page setup failed: $e')),
        );
      }
    }
  }


  List<ComparisonRow> get _filteredRows => _bloc.state.filteredRows;

  int _countType(MatchType type) => _bloc.state.typeCounts[type] ?? 0;

  int _countDiff(String diff) => _bloc.state.diffCounts[diff] ?? 0;

  Set<String> get _classes => _bloc.state.classes;

  String _statusText(ComparisonRow row) {
    switch (row.type) {
      case MatchType.matched:
        return 'MATCHED';

      case MatchType.mismatch:
        return 'MISMATCH';

      case MatchType.possibleMatch:
        return 'REVIEW';

      case MatchType.notInUdise:
        return 'PSP ONLY';

      case MatchType.notInPsp:
        return 'UDISE ONLY';
    }
  }

  Color _statusColor(
    BuildContext context,
    ComparisonRow row,
  ) {
    final scheme = Theme.of(context).colorScheme;

    switch (row.type) {
      case MatchType.matched:
        return Colors.green;

      case MatchType.mismatch:
        return scheme.error;

      case MatchType.possibleMatch:
        return Colors.orange;

      case MatchType.notInUdise:
      case MatchType.notInPsp:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ComparisonBloc, ComparisonState>(
        builder: (context, state) {
          final filtered = _filteredRows;
          final pspBaseCount = state.pspCount;
          final matchedBaseCount = state.matchedPspCount;
          final mismatchBaseCount = state.mismatchPspCount;
          final classes = _classes.toList()
            ..sort((a, b) {
              final ai = int.tryParse(a) ?? 99;
              final bi = int.tryParse(b) ?? 99;
              if (ai != bi) return ai.compareTo(bi);
              return a.compareTo(b);
            });

          return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 14,
        title: _searchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  // Avoid rebuilding the full dashboard for every keystroke.
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 180), () {
                    if (mounted) _bloc.setSearch(value);
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search name, NIC, PEN...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              )
            : Text(
                widget.schoolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: [
          if (!_searchActive)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  '${filtered.length}/${_rows.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: _searchActive ? 'Close search' : 'Search',
            icon: Icon(
              _searchActive ? Icons.close_rounded : Icons.search_rounded,
            ),
            onPressed: () {
              _searchDebounce?.cancel();
              final wasActive = _searchActive;
              _bloc.setSearchActive(!wasActive);
              if (wasActive) {
                _searchController.clear();
                _bloc.setSearch('');
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Import / Export',
            onSelected: (value) {
              switch (value) {
                case 'import_psp': _importJson(true); break;
                case 'import_udise': _importJson(false); break;
                case 'import_legacy_remarks': _importLegacyRemarks(); break;
                case 'export_csv': _exportCsv(); break;
                case 'export_psp': _exportSourceJson(true); break;
                case 'export_udise': _exportSourceJson(false); break;
                case 'print_setup': _printPageSetup(); break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'import_psp', child: Text('Import PSP JSON')),
              const PopupMenuItem(value: 'import_udise', child: Text('Import UDISE JSON')),
              if (!kIsWeb)
                const PopupMenuItem(value: 'import_legacy_remarks', child: Text('Import remarks from old database')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'export_csv', child: Text('Export comparison CSV')),
              const PopupMenuItem(value: 'export_psp', child: Text('Export PSP JSON')),
              const PopupMenuItem(value: 'export_udise', child: Text('Export UDISE JSON')),
              if (!kIsWeb)
                const PopupMenuItem(value: 'print_setup', child: Text('Print Page Setup')),

            ],
          ),
        ],
      ),

      body: Column(
        children: [
          if (_loadingData) const LinearProgressIndicator(minHeight: 2),
          if (_dataError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                _dataError!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_loadingData && _rows.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 14),
                    Text('Loading comparison data...'),
                  ],
                ),
              ),
            )
          else ...[
          ComparisonSummarySection(
            sourceFilter: state.sourceFilter,
            classFilter: _classFilter,
            statusFilters: state.statusFilters,
            apaarStatusFilters: state.apaarStatusFilters,
            aadhaarStatusFilters: state.aadhaarStatusFilters,
            classes: classes,
            apaarStatusOptions: _bloc.apaarStatusOptions,
            aadhaarStatusOptions: _bloc.aadhaarStatusOptions,
            apaarStatusLabel: _bloc.apaarStatusLabel,
            aadhaarStatusLabel: _bloc.aadhaarStatusLabel,
            onSourceChanged: _bloc.setSourceFilter,
            onStatusToggle: _bloc.toggleStatusFilter,
            onApaarToggle: _bloc.toggleApaarStatusFilter,
            onAadhaarToggle: _bloc.toggleAadhaarStatusFilter,
            onClassChanged: _bloc.setClassFilter,
            onClearFilters: () {
              _bloc.setSourceFilter('ALL');
              _bloc.setDiffFilters(const <String>{});
              for (final value in List<String>.from(state.statusFilters)) {
                _bloc.toggleStatusFilter(value);
              }
              for (final value in List<String>.from(state.apaarStatusFilters)) {
                _bloc.toggleApaarStatusFilter(value);
              }
              for (final value in List<String>.from(state.aadhaarStatusFilters)) {
                _bloc.toggleAadhaarStatusFilter(value);
              }
              _bloc.setClassFilter('');
            },
            onPrint: _printReport,
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No students found',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  )
                : SelectionArea(
                    // One selection registrar for the whole lazy list keeps text
                    // selectable without creating a SelectionArea per student row.
                    child: ListView.builder(
                      // The sliver already wraps rows in repaint boundaries.
                      // Do not retain off-screen row states for this read-only list.
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      semanticChildCount: filtered.length,
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final row = filtered[index];
                        return ComparisonStudentRow(
                          key: ValueKey(
                            '${row.psp?.nicId ?? ''}|${row.udise?.studentCodeNat ?? ''}',
                          ),
                          row: row,
                          hasRemark: _hasRemark(row),
                          statusText: _statusText(row),
                          statusColor: _statusColor(context, row),
                          rteText: _pspRte(row),
                          remark: _remarkFor(row)?['remark']?.toString() ?? '',
                          onRemarkTap: () => _editRemark(row),
                        );
                      },
                    ),
                  ),
          )
          ],
        ],
      ),
    );
        },
      ),
    );
  }

}

