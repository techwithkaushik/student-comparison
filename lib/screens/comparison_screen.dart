import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../matching/matching_engine.dart';
import '../matching/models.dart';

class ComparisonDashboardScreen extends StatefulWidget {
  final List<ComparisonRow> initialRows;

  const ComparisonDashboardScreen({
    super.key,
    this.initialRows = const <ComparisonRow>[],
  });

  @override
  State<ComparisonDashboardScreen> createState() =>
      _ComparisonDashboardScreenState();
}

class _ComparisonDashboardScreenState
    extends State<ComparisonDashboardScreen> {
  List<ComparisonRow> _rows = <ComparisonRow>[];
  bool _loadingData = true;
  String? _dataError;

  String _filter = 'ALL';
  String _classFilter = '';
  String _search = '';
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _remarkKeys = <String>{};
  final Map<String, Map<String, dynamic>> _remarks = <String, Map<String, dynamic>>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRows.isNotEmpty) {
      _rows = List<ComparisonRow>.from(widget.initialRows);
      _loadingData = false;
    }
    _loadData();
    _loadRemarkKeys();
  }

  Future<void> _loadData() async {
    try {
      final db = AppDatabase.instance;
      final pspRows = await db.loadPspRows();
      final udiseRows = await db.loadUdiseRows();
      final psp = pspRows.map(PspStudent.fromJson).toList();
      final udise = udiseRows.map(UdiseStudent.fromJson).toList();
      final rows = psp.isEmpty || udise.isEmpty
          ? <ComparisonRow>[]
          : runMatchingEngine(psp, udise);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadingData = false;
        _dataError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingData = false;
        _dataError = 'Unable to load saved data: $e';
      });
    }
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
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Unable to read selected JSON file.');
      final rows = await _decodeJsonRows(bytes, pspImport ? 'PSP' : 'UDISE');
      if (pspImport) {
        await AppDatabase.instance.replacePspRows(rows);
      } else {
        await AppDatabase.instance.replaceUdiseRows(rows);
      }
      await _loadData();
      await _loadRemarkKeys();
    } catch (e) {
      if (!mounted) return;
      setState(() => _dataError = 'JSON import failed: $e');
    }
  }

  Future<void> _importSqlite() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Unable to read selected SQLite file.');
      final imported = await AppDatabase.instance.importSqliteBytes(bytes);
      await _loadData();
      await _loadRemarkKeys();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'SQLite imported: ${imported.pspCount} PSP, ${imported.udiseCount} UDISE'
          '${imported.remarkCount > 0 ? ', ${imported.remarkCount} remarks' : ''}.',
        )),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _dataError = 'SQLite import failed: $e');
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final bytes = await AppDatabase.instance.exportDatabaseBytes();
      final path = await FilePicker.platform.saveFile(dialogTitle: 'Export SQLite database', fileName: 'student_comparison.db', bytes: bytes);
      if (path != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SQLite database exported successfully.')));
    } catch (e) {
      if (mounted) setState(() => _dataError = 'Database export failed: $e');
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
      if (mounted) setState(() => _dataError = 'CSV export failed: $e');
    }
  }

  Future<void> _exportSourceJson(bool pspExport) async {
    try {
      final rows = pspExport
          ? await AppDatabase.instance.loadPspRows()
          : await AppDatabase.instance.loadUdiseRows();
      final bytes = Uint8List.fromList(utf8.encode(
        const JsonEncoder.withIndent('  ').convert(rows),
      ));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${pspExport ? 'PSP' : 'UDISE'} JSON',
        fileName: '${pspExport ? 'psp' : 'udise'}_export.json',
        bytes: bytes,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON exported successfully.')));
      }
    } catch (e) {
      if (mounted) setState(() => _dataError = 'JSON export failed: $e');
    }
  }

  String _key(String value) => value.trim().toUpperCase();

  String _remarkKeyFor(ComparisonRow row) {
    final p = row.psp?.nicId ?? '';
    final u = row.udise?.studentCodeNat ?? '';
    return '${_key(p)}|${_key(u)}';
  }

  Future<void> _loadRemarkKeys() async {
    try {
      final rows = await AppDatabase.instance.getAllRemarks();
      final keys = <String>{};
      final remarks = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        final p = r['psp_nic']?.toString() ?? '';
        final u = r['udise_pen']?.toString() ?? '';
        if (p.isNotEmpty || u.isNotEmpty) {
          final key = '${_key(p)}|${_key(u)}';
          keys.add(key);
          remarks[key] = Map<String, dynamic>.from(r);
        }
      }
      if (!mounted) return;
      setState(() {
        _remarkKeys
          ..clear()
          ..addAll(keys);
        _remarks
          ..clear()
          ..addAll(remarks);
      });
    } catch (_) {
      // Keep the comparison list usable even if the remark table cannot be read.
    }
  }

  Map<String, dynamic>? _remarkFor(ComparisonRow row) =>
      _remarks[_remarkKeyFor(row)];

  String _pspRte(ComparisonRow row) {
    final raw = row.psp?.raw ?? const <String, dynamic>{};
    final value = raw['Getting Free Education']?.toString().trim() ?? '';
    final normalized = value.toLowerCase();
    final isRte = normalized == 'yes' || normalized == 'y' ||
        normalized == 'true' || normalized == '1';
    return isRte ? 'RTE' : 'NON-RTE';
  }

  Future<void> _editRemark(ComparisonRow row) async {
    final key = _remarkKeyFor(row);
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
        await AppDatabase.instance.deleteRemark(pspNic: row.psp?.nicId, udisePen: row.udise?.studentCodeNat);
        if (!mounted) return;
        setState(() { _remarks.remove(key); _remarkKeys.remove(key); });
      } else {
        await AppDatabase.instance.saveRemark(remark: text, pspNic: row.psp?.nicId, udisePen: row.udise?.studentCodeNat);
        final updated = await AppDatabase.instance.getRemark(pspNic: row.psp?.nicId, udisePen: row.udise?.studentCodeNat);
        if (!mounted) return;
        if (updated != null) setState(() { _remarks[key] = updated; _remarkKeys.add(key); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remark update failed: $e')));
    } finally {
      controller.dispose();
    }
  }

  bool _hasRemark(ComparisonRow row) =>
      _remarkKeys.contains(_remarkKeyFor(row));

  List<ComparisonRow> get _filteredRows {
    final q = _search.trim().toLowerCase();

    return _rows.where((row) {
      // Remark filter
      if (_filter == 'REMARKED' && !_hasRemark(row)) {
        return false;
      }

      if (_filter == 'RTE' && _pspRte(row) != 'RTE') {
        return false;
      }

      // Status / difference filter
      if (_filter == 'MATCHED' &&
          row.type != MatchType.matched) {
        return false;
      }

      if (_filter == 'MISMATCH' &&
          row.type != MatchType.mismatch) {
        return false;
      }

      if (_filter == 'PSP_ONLY' &&
          row.type != MatchType.notInUdise) {
        return false;
      }

      if (_filter == 'UDISE_ONLY' &&
          row.type != MatchType.notInPsp) {
        return false;
      }

      if (_filter.startsWith('DIFF:')) {
        final diff = _filter.substring(5);
        if (!row.diffs.contains(diff)) {
          return false;
        }
      }

      // Class filter
      if (_classFilter.isNotEmpty) {
        final pClass =
            row.psp?.classCanonValue ?? '';

        final uClass =
            row.udise?.classDescCanon ??
            row.udise?.classIdCanon ??
            '';

        if (pClass != _classFilter &&
            uClass != _classFilter) {
          return false;
        }
      }

      // Search
      if (q.isNotEmpty) {
        final values = [
          row.psp?.studentName,
          row.psp?.srNo,
          row.psp?.nicId,
          row.psp?.fatherName,
          row.psp?.motherName,
          row.psp?.mobile,
          row.udise?.studentName,
          row.udise?.studentCodeNat,
          row.udise?.studentId,
          row.udise?.fatherName,
          row.udise?.motherName,
          row.udise?.mobile,
        ];

        final found = values.any(
          (value) =>
              (value ?? '').toLowerCase().contains(q),
        );

        if (!found) return false;
      }

      return true;
    }).toList();
  }

  int _countType(MatchType type) {
    return _rows
        .where((row) => row.type == type)
        .length;
  }

  int _countDiff(String diff) {
    return _rows
        .where((row) => row.diffs.contains(diff))
        .length;
  }

  Set<String> get _classes {
    final result = <String>{};

    for (final row in _rows) {
      final pClass =
          row.psp?.classCanonValue ?? '';

      final uClass =
          row.udise?.classDescCanon ??
          row.udise?.classIdCanon ??
          '';

      if (pClass.isNotEmpty) {
        result.add(pClass);
      }

      if (uClass.isNotEmpty) {
        result.add(uClass);
      }
    }

    return result;
  }

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
    final filtered = _filteredRows;
    final pspBaseCount = _rows.where((row) => row.psp != null).length;
    final matchedBaseCount = _rows.where((row) => row.psp != null && row.type == MatchType.matched).length;
    final mismatchBaseCount = _rows.where((row) => row.psp != null && row.type == MatchType.mismatch).length;

    final classes = _classes.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? 99;
        final bi = int.tryParse(b) ?? 99;

        if (ai != bi) {
          return ai.compareTo(bi);
        }

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
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  hintText: 'Search name, NIC, PEN...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              )
            : const Text(
                'Comparison',
                style: TextStyle(
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
                    fontSize: 12,
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
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchController.clear();
                  _search = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Import / Export',
            onSelected: (value) {
              switch (value) {
                case 'import_psp': _importJson(true); break;
                case 'import_udise': _importJson(false); break;
                case 'import_sqlite': _importSqlite(); break;
                case 'export_csv': _exportCsv(); break;
                case 'export_psp': _exportSourceJson(true); break;
                case 'export_udise': _exportSourceJson(false); break;
                case 'export_database': _exportDatabase(); break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import_psp', child: Text('Import PSP JSON')),
              PopupMenuItem(value: 'import_udise', child: Text('Import UDISE JSON')),
              PopupMenuItem(value: 'import_sqlite', child: Text('Import SQLite database')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'export_csv', child: Text('Export comparison CSV')),
              PopupMenuItem(value: 'export_psp', child: Text('Export PSP JSON')),
              PopupMenuItem(value: 'export_udise', child: Text('Export UDISE JSON')),
              PopupMenuItem(value: 'export_database', child: Text('Export SQLite database')),
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
          _SummarySection(
            all: pspBaseCount,
            matched: matchedBaseCount,
            mismatch: mismatchBaseCount,
            matchedPercent: pspBaseCount == 0 ? 0 : (matchedBaseCount * 100 / pspBaseCount),
            mismatchPercent: pspBaseCount == 0 ? 0 : (mismatchBaseCount * 100 / pspBaseCount),
            rte: _rows.where((row) => _pspRte(row) == 'RTE').length,
            pspOnly: _countType(MatchType.notInUdise),
            udiseOnly: _countType(MatchType.notInPsp),
            remarks: _rows.where(_hasRemark).length,
            name: _countDiff('NAME_MISMATCH'),
            dob: _countDiff('DOB_MISMATCH'),
            father: _countDiff('FATHER_MISMATCH'),
            mother: _countDiff('MOTHER_MISMATCH'),
            classMismatch: _countDiff('CLASS_MISMATCH'),
            gender: _countDiff('GENDER_MISMATCH'),
            category: _countDiff('CATEGORY_MISMATCH'),
            religion: _countDiff('RELIGION_MISMATCH'),
            aadhaar: _countDiff('AADHAAR_MISMATCH'),
            aadhaarMissing: _countDiff(
              'AADHAAR_NOT_FOUND',
            ),
            mobile: _countDiff('MOBILE_MISMATCH'),
            selected: _filter,
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            onDiffSelected: (diff) {
              setState(() {
                _filter = _filter == 'DIFF:$diff'
                    ? 'ALL'
                    : 'DIFF:$diff';
              });
            },
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 90,
                height: 26,
                child: DropdownButtonFormField<String>(
                  initialValue: _classFilter.isEmpty ? null : _classFilter,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    ...classes.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('Class $value'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _classFilter = value ?? ''),
                ),
              ),
            ),
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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      8,
                      2,
                      8,
                      8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      return _StudentRow(
                        row: filtered[index],
                        hasRemark: _hasRemark(filtered[index]),
                        statusText:
                            _statusText(filtered[index]),
                        statusColor: _statusColor(context, filtered[index]),
                        rteText: _pspRte(filtered[index]),
                        remark: _remarkFor(filtered[index])?['remark']?.toString() ?? '',
                        onRemarkTap: () => _editRemark(filtered[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final int all;
  final int matched;
  final int mismatch;
  final double matchedPercent;
  final double mismatchPercent;
  final int rte;
  final int pspOnly;
  final int udiseOnly;
  final int remarks;

  final int name;
  final int dob;
  final int father;
  final int mother;
  final int classMismatch;
  final int gender;
  final int category;
  final int religion;
  final int aadhaar;
  final int aadhaarMissing;
  final int mobile;

  final String selected;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDiffSelected;

  const _SummarySection({
    required this.all,
    required this.matched,
    required this.mismatch,
    required this.matchedPercent,
    required this.mismatchPercent,
    required this.rte,
    required this.pspOnly,
    required this.udiseOnly,
    required this.remarks,
    required this.name,
    required this.dob,
    required this.father,
    required this.mother,
    required this.classMismatch,
    required this.gender,
    required this.category,
    required this.religion,
    required this.aadhaar,
    required this.aadhaarMissing,
    required this.mobile,
    required this.selected,
    required this.onSelected,
    required this.onDiffSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary/status chips wrap to the next line instead of scrolling.
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _StatChip(
                label: 'All',
                value: all,
                selected: selected == 'ALL',
                onTap: () => onSelected('ALL'),
              ),
              _PercentChip(label: 'Matched', percent: matchedPercent, color: Colors.green, selected: selected == 'MATCHED', onTap: () => onSelected('MATCHED')),
              _PercentChip(label: 'Mismatch', percent: mismatchPercent, color: Colors.red, selected: selected == 'MISMATCH', onTap: () => onSelected('MISMATCH')),
              _StatChip(
                label: 'PSP only',
                value: pspOnly,
                color: Colors.blue,
                selected: selected == 'PSP_ONLY',
                onTap: () => onSelected('PSP_ONLY'),
              ),
              _StatChip(
                label: 'UDISE only',
                value: udiseOnly,
                color: Colors.blue,
                selected: selected == 'UDISE_ONLY',
                onTap: () => onSelected('UDISE_ONLY'),
              ),
              _StatChip(
                label: 'Remarked',
                value: remarks,
                color: Colors.deepPurple,
                selected: selected == 'REMARKED',
                onTap: () => onSelected('REMARKED'),
              ),
              _StatChip(label: 'RTE', value: rte, color: Colors.orange, selected: selected == 'RTE', onTap: () => onSelected('RTE')),
            ],
          ),
          const SizedBox(height: 5),
          // Difference chips also wrap vertically. No horizontal scrolling.
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _DiffChip(
                label: 'Name',
                value: name,
                selected: selected == 'DIFF:NAME_MISMATCH',
                onTap: () => onDiffSelected('NAME_MISMATCH'),
              ),
              _DiffChip(
                label: 'DOB',
                value: dob,
                selected: selected == 'DIFF:DOB_MISMATCH',
                onTap: () => onDiffSelected('DOB_MISMATCH'),
              ),
              _DiffChip(
                label: 'Father',
                value: father,
                selected: selected == 'DIFF:FATHER_MISMATCH',
                onTap: () => onDiffSelected('FATHER_MISMATCH'),
              ),
              _DiffChip(
                label: 'Mother',
                value: mother,
                selected: selected == 'DIFF:MOTHER_MISMATCH',
                onTap: () => onDiffSelected('MOTHER_MISMATCH'),
              ),
              _DiffChip(
                label: 'Class',
                value: classMismatch,
                selected: selected == 'DIFF:CLASS_MISMATCH',
                onTap: () => onDiffSelected('CLASS_MISMATCH'),
              ),
              _DiffChip(
                label: 'Gender',
                value: gender,
                selected: selected == 'DIFF:GENDER_MISMATCH',
                onTap: () => onDiffSelected('GENDER_MISMATCH'),
              ),
              _DiffChip(
                label: 'Category',
                value: category,
                selected: selected == 'DIFF:CATEGORY_MISMATCH',
                onTap: () => onDiffSelected('CATEGORY_MISMATCH'),
              ),
              _DiffChip(
                label: 'Religion',
                value: religion,
                selected: selected == 'DIFF:RELIGION_MISMATCH',
                onTap: () => onDiffSelected('RELIGION_MISMATCH'),
              ),
              _DiffChip(
                label: 'Aadhaar ✗',
                value: aadhaar,
                selected: selected == 'DIFF:AADHAAR_MISMATCH',
                onTap: () => onDiffSelected('AADHAAR_MISMATCH'),
              ),
              _DiffChip(
                label: 'Aadhaar —',
                value: aadhaarMissing,
                selected: selected == 'DIFF:AADHAAR_NOT_FOUND',
                onTap: () => onDiffSelected('AADHAAR_NOT_FOUND'),
              ),
              _DiffChip(
                label: 'Mobile',
                value: mobile,
                selected: selected == 'DIFF:MOBILE_MISMATCH',
                onTap: () => onDiffSelected('MOBILE_MISMATCH'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = color ?? scheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(
          width: 80,
          height: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? baseColor.withValues(alpha: .16)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? baseColor : scheme.outlineVariant,
                width: selected ? 1.2 : .6,
              ),
            ),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$value ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? baseColor : scheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PercentChip({required this.label, required this.percent, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(9),
      child: Container(width: 80, height: 26, alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? color.withValues(alpha: .16) : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? color : scheme.outlineVariant, width: selected ? 1.2 : .6)),
        child: Text('$label ${percent.toStringAsFixed(1)}%', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: selected ? color : scheme.onSurface)),
      ),
    ));
  }
}
class _DiffChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _DiffChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 90,
          height: 26,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.1 : .6,
              ),
            ),
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final ComparisonRow row;
  final bool hasRemark;
  final String statusText;
  final Color statusColor;
  final String rteText;
  final String remark;
  final VoidCallback onRemarkTap;

  const _StudentRow({required this.row, required this.hasRemark, required this.statusText, required this.statusColor, required this.rteText, required this.remark, required this.onRemarkTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = row.psp;
    final u = row.udise;
    return Card(
      margin: const EdgeInsets.only(bottom: 6), elevation: 0, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7), side: BorderSide(color: scheme.outlineVariant)),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), color: statusColor.withValues(alpha: .07),
          child: Row(children: [
            Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
            const Spacer(),
            if (remark.isNotEmpty) Flexible(child: Padding(padding: const EdgeInsets.only(right: 4), child: Text(remark, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 7.5, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)))),
            IconButton(tooltip: 'Edit remark', visualDensity: VisualDensity.compact, onPressed: onRemarkTap,
              icon: Icon(hasRemark ? Icons.edit_note_rounded : Icons.add_comment_outlined, size: 18, color: hasRemark ? Colors.deepPurple.shade600 : scheme.onSurfaceVariant)),
          ]),
        ),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), color: scheme.surfaceContainerHighest,
          child: Row(children: [
            Expanded(flex: 2, child: Text('FIELD', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant))),
            Expanded(flex: 3, child: Text('PSP — Correct Data', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: scheme.primary))),
            Expanded(flex: 3, child: Text('UDISE — Current Data', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.green.shade700))),
            SizedBox(width: 52, child: Text('RTE', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant))),
          ]),
        ),
        _ComparisonFieldRow(label: 'Name', psp: p?.studentName, udise: u?.studentName, mismatch: row.diffs.contains('NAME_MISMATCH')),
        _ComparisonFieldRow(label: 'Father', psp: p?.fatherName, udise: u?.fatherName, mismatch: row.diffs.contains('FATHER_MISMATCH')),
        _ComparisonFieldRow(label: 'Mother', psp: p?.motherName, udise: u?.motherName, mismatch: row.diffs.contains('MOTHER_MISMATCH')),
        _ComparisonFieldRow(label: 'DOB', psp: p?.dob, udise: u?.dob, mismatch: row.diffs.contains('DOB_MISMATCH')),
        _ComparisonFieldRow(label: 'Class', psp: p?.studyingClass, udise: u?.classDesc.isNotEmpty == true ? u?.classDesc : u?.classId, mismatch: row.diffs.contains('CLASS_MISMATCH')),
        _ComparisonFieldRow(label: 'Gender', psp: p?.gender, udise: _genderLabel(u?.gender), mismatch: row.diffs.contains('GENDER_MISMATCH')),
        _ComparisonFieldRow(label: 'Category', psp: p?.categoryNorm, udise: u?.categoryNorm, mismatch: row.diffs.contains('CATEGORY_MISMATCH')),
        _ComparisonFieldRow(label: 'Religion', psp: p?.religionNormValue, udise: u?.religionNormValue, mismatch: row.diffs.contains('RELIGION_MISMATCH')),
        _ComparisonFieldRow(label: 'NIC ID / PEN', psp: p == null ? null : (p.srNo.isEmpty ? p.nicId : '${p.nicId} | SR: ${p.srNo}'), udise: u?.studentCodeNat),
        _ComparisonFieldRow(label: 'Mobile', psp: p?.mobile, udise: u?.mobile, mismatch: row.diffs.contains('MOBILE_MISMATCH')),
        _ComparisonFieldRow(label: 'Aadhaar', psp: p?.aadhaarLast4.isEmpty == true ? 'Not Found' : '****${p?.aadhaarLast4}', udise: u?.uuidLast4.isEmpty == true ? 'Not Found' : '****${u?.uuidLast4}', mismatch: row.diffs.contains('AADHAAR_MISMATCH')),
        Padding(padding: const EdgeInsets.fromLTRB(7, 3, 7, 5), child: Row(children: [const Expanded(flex: 2, child: SizedBox()), const Expanded(flex: 3, child: SizedBox()),
          Expanded(flex: 3, child: Align(alignment: Alignment.center, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: rteText == 'RTE' ? Colors.orange.withValues(alpha: .14) : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)),
            child: Text(rteText, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: rteText == 'RTE' ? Colors.orange.shade800 : scheme.onSurfaceVariant)))),
          const SizedBox(width: 52),
        ])),
      ]),
    );
  }

  static String _genderLabel(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v == '1' || v == 'MALE' || v == 'M') return 'MALE';
    if (v == '2' || v == 'FEMALE' || v == 'F') return 'FEMALE';
    return value ?? '—';
  }
}

class _ComparisonFieldRow extends StatelessWidget {
  final String label; final String? psp; final String? udise; final bool mismatch;
  const _ComparisonFieldRow({required this.label, required this.psp, required this.udise, this.mismatch = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = (psp ?? '').trim().isEmpty ? '—' : psp!.trim();
    final u = (udise ?? '').trim().isEmpty ? '—' : udise!.trim();
    final style = TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: scheme.onSurface);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant))),
        Expanded(flex: 3, child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: mismatch ? style.copyWith(fontWeight: FontWeight.w800, color: scheme.error) : style)),
        Expanded(flex: 3, child: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis, style: mismatch ? style.copyWith(fontWeight: FontWeight.w800, color: scheme.error) : style)),
      ]));
  }
}
class _ProfileReviewDialog extends StatelessWidget {
  final ComparisonRow row;
  final String side;
  final Map<String, dynamic> raw;

  const _ProfileReviewDialog({
    required this.row,
    required this.side,
    required this.raw,
  });

  String _display(dynamic value) {
    if (value == null) return 'empty';
    if (value is String && value.trim().isEmpty) return 'empty';
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  bool _isMismatch(String key) {
    final diffs = row.diffs.toSet();

    if (side == 'PSP') {
      const map = <String, String>{
        'Student Name': 'NAME_MISMATCH',
        'Father Name': 'FATHER_MISMATCH',
        'Mother Name': 'MOTHER_MISMATCH',
        'DOB': 'DOB_MISMATCH',
        'Studying in Class': 'CLASS_MISMATCH',
        'Gender': 'GENDER_MISMATCH',
        'Mobile Number': 'MOBILE_MISMATCH',
        'Aadhar Number': 'AADHAAR_MISMATCH',
        'Social Category': 'CATEGORY_MISMATCH',
        'Religion': 'RELIGION_MISMATCH',
      };
      return diffs.contains(map[key]);
    }

    const map = <String, String>{
      'studentName': 'NAME_MISMATCH',
      'nameAsUuid': 'NAME_MISMATCH',
      'fatherName': 'FATHER_MISMATCH',
      'motherName': 'MOTHER_MISMATCH',
      'dob': 'DOB_MISMATCH',
      'classId': 'CLASS_MISMATCH',
      'classDesc': 'CLASS_MISMATCH',
      'gender': 'GENDER_MISMATCH',
      'genderDesc': 'GENDER_MISMATCH',
      'primaryMobile': 'MOBILE_MISMATCH',
      'secondaryMobile': 'MOBILE_MISMATCH',
      'uuid': 'AADHAAR_MISMATCH',
      'uuidMasked': 'AADHAAR_MISMATCH',
      'socCatId': 'CATEGORY_MISMATCH',
      'socialCategoryDesc': 'CATEGORY_MISMATCH',
      'minorityId': 'RELIGION_MISMATCH',
      'minorityDesc': 'RELIGION_MISMATCH',
    };
    return diffs.contains(map[key]);
  }

  String _humanKey(String key) {
    final value = key
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m.group(1) ?? ''} ${m.group(2) ?? ''}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return value
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : part[0].toUpperCase() + part.substring(1),
        )
        .join(' ');
  }

  String _statusLabel(MatchType type) {
    switch (type) {
      case MatchType.matched:
        return 'MATCHED';
      case MatchType.mismatch:
        return 'MISMATCH';
      case MatchType.possibleMatch:
        return 'POSSIBLE MATCH';
      case MatchType.notInUdise:
        return 'NOT IN UDISE';
      case MatchType.notInPsp:
        return 'NOT IN PSP';
    }
  }

  String _flagLabel(String value) {
    switch (value) {
      case 'AADHAAR_NOT_FOUND':
        return 'AADHAAR NOT FOUND';
      case 'MOBILE_NOT_FOUND':
        return 'MOBILE NOT FOUND';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPsp = side == 'PSP';
    final accent = isPsp ? scheme.primary : Colors.green.shade700;
    final status = _statusLabel(row.type);
    final flags = row.diffs.isEmpty
        ? 'None (Clean Match)'
        : row.diffs.map(_flagLabel).join(', ');
    final entries = raw.entries.toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 9, 7, 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$side Student Profile Review — $status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: accent,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified $side Database Attributes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: Scrollbar(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(1, 1, 1, 2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 7,
                        childAspectRatio: 3.0,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (_, index) {
                        final entry = entries[index];
                        final key = entry.key.toString();
                        final mismatch = _isMismatch(key);
                        final display = _display(entry.value);

                        return Container(
                          padding: const EdgeInsets.fromLTRB(11, 8, 9, 7),
                          decoration: BoxDecoration(
                            color: mismatch
                                ? scheme.errorContainer.withValues(alpha: .28)
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: mismatch
                                  ? scheme.error
                                  : scheme.outlineVariant.withValues(alpha: .65),
                              width: mismatch ? 1.0 : .7,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _humanKey(key).toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .15,
                                  color: mismatch
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    display,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      height: 1.15,
                                      fontWeight: mismatch
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: mismatch
                                          ? scheme.error
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      left: BorderSide(
                        color: scheme.outline,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Active Conflict Flags: ',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: flags,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: row.diffs.isEmpty
                                    ? Colors.green.shade700
                                    : scheme.error,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 8.5),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Cross-System Match Confidence Score: ',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: '${row.score}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurfaceVariant,
              foregroundColor: scheme.surface,
              minimumSize: const Size(82, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close Review',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
