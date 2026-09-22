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
            matchedCount: matchedBaseCount,
            mismatchCount: mismatchBaseCount,
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
            classes: classes,
            classFilter: _classFilter,
            onClassChanged: (value) {
              setState(() => _classFilter = value);
            },
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
  final int matchedCount;
  final int mismatchCount;
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
  final List<String> classes;
  final String classFilter;
  final ValueChanged<String> onClassChanged;

  const _SummarySection({
    required this.all,
    required this.matchedCount,
    required this.mismatchCount,
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
    required this.classes,
    required this.classFilter,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
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
              _CountChip(label: 'Matched', percent: matchedCount, color: Colors.green, selected: selected == 'MATCHED', onTap: () => onSelected('MATCHED')),
              _CountChip(label: 'Mismatch', percent: mismatchCount, color: Colors.red, selected: selected == 'MISMATCH', onTap: () => onSelected('MISMATCH')),
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
              const SizedBox(width: 2),
              SizedBox(
                width: 118,
                height: 30,
                child: DropdownButtonFormField<String>(
                  initialValue: classFilter.isEmpty ? '' : classFilter,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
                  onChanged: (value) => onClassChanged(value ?? ''),
                ),
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
        child: Container(
          constraints: const BoxConstraints(minWidth: 78, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      baseColor.withValues(alpha: .22),
                      baseColor.withValues(alpha: .08),
                    ],
                  )
                : null,
            color: selected ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? baseColor : scheme.outlineVariant,
              width: selected ? 1.4 : .7,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: .10),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: selected ? baseColor : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? baseColor : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CountChip({required this.label, required this.percent, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = percent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 86, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: .22),
                      color.withValues(alpha: .08),
                    ],
                  )
                : null,
            color: selected ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 1.4 : .7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: selected ? color : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 86,
          height: 28,
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

const List<String> _admissionDateKeys = <String>[
  'Admission Date',
  'Admission date',
  'admissionDate',
  'admission_date',
  'Date of Admission',
];

class _StudentRow extends StatelessWidget {
  final ComparisonRow row;
  final bool hasRemark;
  final String statusText;
  final Color statusColor;
  final String rteText;
  final String remark;
  final VoidCallback onRemarkTap;

  const _StudentRow({
    required this.row,
    required this.hasRemark,
    required this.statusText,
    required this.statusColor,
    required this.rteText,
    required this.remark,
    required this.onRemarkTap,
  });

  void _openDetails(BuildContext context, String side) {
    showDialog<void>(
      context: context,
      builder: (_) => _ComparisonDetailsDialog(row: row, side: side),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = row.psp;
    final u = row.udise;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: .25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
            color: statusColor.withValues(alpha: .06),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${row.score}%',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(width: 7),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SR: ${p?.srNo.trim().isNotEmpty == true ? p!.srNo : '—'}',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                    Text(
                      'Admission: ${_rawValue(p?.raw, _admissionDateKeys) ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: rteText == 'RTE' ? Colors.orange.withValues(alpha: .14) : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    rteText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: rteText == 'RTE' ? Colors.orange.shade800 : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (remark.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        remark,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 7.5, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: hasRemark ? 'Edit remark' : 'Add remark',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemarkTap,
                  icon: Icon(
                    hasRemark ? Icons.edit_note_rounded : Icons.add_comment_outlined,
                    size: 18,
                    color: hasRemark ? Colors.deepPurple.shade600 : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            color: scheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('FIELD', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 3,
                  child: _ClickableHeader(
                    title: 'PSP',
                    subtitle: 'Correct Data',
                    color: scheme.primary,
                    onTap: () => _openDetails(context, 'PSP'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: _ClickableHeader(
                    title: 'UDISE',
                    subtitle: 'Current Data',
                    color: Colors.green.shade700,
                    onTap: () => _openDetails(context, 'UDISE'),
                  ),
                ),
              ],
            ),
          ),
          _ComparisonFieldRow(
            label: 'Name',
            psp: p?.studentName,
            udise: u?.studentName,
            mismatch: row.diffs.contains('NAME_MISMATCH'),
          ),
          _ComparisonFieldRow(label: 'Father', psp: p?.fatherName, udise: u?.fatherName, mismatch: row.diffs.contains('FATHER_MISMATCH')),
          _ComparisonFieldRow(label: 'Mother', psp: p?.motherName, udise: u?.motherName, mismatch: row.diffs.contains('MOTHER_MISMATCH')),
          _ComparisonFieldRow(label: 'DOB', psp: p?.dob, udise: u?.dob, mismatch: row.diffs.contains('DOB_MISMATCH')),
          _ComparisonFieldRow(label: 'Class', psp: p?.studyingClass, udise: u?.classDesc.isNotEmpty == true ? u?.classDesc : u?.classId, mismatch: row.diffs.contains('CLASS_MISMATCH')),
          _ComparisonFieldRow(label: 'Gender', psp: p?.gender, udise: _genderLabel(u?.gender), mismatch: row.diffs.contains('GENDER_MISMATCH')),
          _ComparisonFieldRow(label: 'Category', psp: p?.categoryNorm, udise: u?.categoryNorm, mismatch: row.diffs.contains('CATEGORY_MISMATCH')),
          _ComparisonFieldRow(label: 'Religion', psp: p?.religionNormValue, udise: u?.religionNormValue, mismatch: row.diffs.contains('RELIGION_MISMATCH')),
          _ComparisonFieldRow(label: 'NIC ID / PEN', psp: p == null ? null : (p.srNo.isEmpty ? p.nicId : '${p.nicId} | SR: ${p.srNo}'), udise: u?.studentCodeNat),
          _ComparisonFieldRow(label: 'Mobile', psp: p?.mobile, udise: u?.mobile, mismatch: row.diffs.contains('MOBILE_MISMATCH')),
          _AadhaarPreviewRow(row: row),
        ],
      ),
    );
  }

  static String? _rawValue(Map<String, dynamic>? raw, List<String> keys) {
    if (raw == null) return null;
    for (final key in keys) {
      final value = raw[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String _genderLabel(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v == '1' || v == 'MALE' || v == 'M') return 'MALE';
    if (v == '2' || v == 'FEMALE' || v == 'F') return 'FEMALE';
    return value ?? '—';
  }
}

class _ClickableHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ClickableHeader({required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 11, color: color),
              const SizedBox(width: 3),
              Text(title, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: 3),
              Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: color))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonDetailsDialog extends StatelessWidget {
  final ComparisonRow row;
  final String side;

  const _ComparisonDetailsDialog({required this.row, required this.side});

  String _value(dynamic value) {
    if (value == null) return '—';
    if (value is Map || value is List) {
      try { return const JsonEncoder.withIndent('  ').convert(value); } catch (_) {}
    }
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  String _label(String key) {
    final value = key.replaceAll('_', ' ').replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1) ?? ''} ${m.group(2) ?? ''}',
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.split(' ').map((v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPsp = side == 'PSP';
    final accent = isPsp ? scheme.primary : Colors.green.shade700;
    final raw = isPsp ? (row.psp?.raw ?? const <String, dynamic>{}) : (row.udise?.raw ?? const <String, dynamic>{});
    final keys = raw.keys.toList();
    final name = isPsp ? row.psp?.studentName : row.udise?.studentName;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: SizedBox(
        width: 900,
        height: MediaQuery.sizeOf(context).height * .90,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 7, 8),
              decoration: BoxDecoration(color: accent.withValues(alpha: .07), border: Border(bottom: BorderSide(color: accent.withValues(alpha: .25)))),
              child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(7)),
                  child: Text(side, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name?.trim().isNotEmpty == true ? name! : 'Student Details', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('${row.score}%  •  ${_statusLabel(row.type)}', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: accent)),
                ])),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 5), child: Align(alignment: Alignment.centerLeft, child: Text('All $side source fields', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent)))),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 7, mainAxisSpacing: 7, childAspectRatio: 3.8),
                itemCount: keys.length,
                itemBuilder: (_, i) {
                  final key = keys[i];
                  final mismatch = _isMismatchField(key);
                  final fieldColor = mismatch ? scheme.error : scheme.onSurfaceVariant;
                  final valueColor = mismatch ? scheme.error : scheme.onSurface;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 6),
                    decoration: BoxDecoration(
                      color: mismatch
                          ? scheme.errorContainer.withValues(alpha: .32)
                          : scheme.surfaceContainerHighest.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: mismatch
                            ? scheme.error.withValues(alpha: .55)
                            : scheme.outlineVariant,
                        width: mismatch ? 1.1 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label(key).toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: fieldColor,
                                ),
                              ),
                            ),
                            if (mismatch)
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: scheme.error,
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _value(raw[key]),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                color: valueColor,
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
          ],
        ),
      ),
    );
  }

  bool _isMismatchField(String key) {
    final k = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    bool anyOf(Set<String> keys, String diff) =>
        keys.contains(k) && row.diffs.contains(diff);

    return anyOf(
          {'studentname', 'name'},
          'NAME_MISMATCH',
        ) ||
        anyOf(
          {'fathername', 'father'},
          'FATHER_MISMATCH',
        ) ||
        anyOf(
          {'mothername', 'mother'},
          'MOTHER_MISMATCH',
        ) ||
        anyOf(
          {'dob', 'dateofbirth'},
          'DOB_MISMATCH',
        ) ||
        anyOf(
          {'mobilenumber', 'primarymobile', 'mobile', 'phonenumber'},
          'MOBILE_MISMATCH',
        ) ||
        anyOf(
          {'gender'},
          'GENDER_MISMATCH',
        ) ||
        anyOf(
          {'studyinginclass', 'classid', 'classdesc'},
          'CLASS_MISMATCH',
        ) ||
        anyOf(
          {'socialcategory', 'socialcategorydesc', 'soccatid'},
          'CATEGORY_MISMATCH',
        ) ||
        anyOf(
          {'religion', 'minorityid', 'minoritydesc'},
          'RELIGION_MISMATCH',
        ) ||
        anyOf(
          {'aadharnumber', 'aadhaarnumber', 'uuid'},
          'AADHAAR_MISMATCH',
        );
  }

  String _statusLabel(MatchType type) {
    switch (type) {
      case MatchType.matched: return 'MATCHED';
      case MatchType.mismatch: return 'MISMATCH';
      case MatchType.possibleMatch: return 'REVIEW';
      case MatchType.notInUdise: return 'PSP ONLY';
      case MatchType.notInPsp: return 'UDISE ONLY';
    }
  }
}

class _AadhaarPreviewRow extends StatelessWidget {
  final ComparisonRow row;

  const _AadhaarPreviewRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pLast4 = row.psp?.aadhaarLast4.trim() ?? '';
    final uLast4 = row.udise?.uuidLast4.trim() ?? '';
    final p = pLast4.isEmpty ? 'Not Found' : '****$pLast4';
    final u = uLast4.isEmpty ? 'Not Found' : '****$uLast4';
    final status = row.udise?.uuidStatus.trim() ?? '';
    final verified = status == '1';
    final hasStatus = status == '0' || status == '1' || status == '2';
    final mismatch = row.diffs.contains('AADHAAR_MISMATCH');

    final valueStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: mismatch ? FontWeight.w800 : FontWeight.w600,
      color: mismatch ? scheme.error : scheme.onSurface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Aadhaar',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              p,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle,
                      ),
                    ),
                    if (hasStatus) ...[
                      const SizedBox(width: 4),
                      Text(
                        verified ? '✓' : '✗',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: verified ? Colors.green.shade700 : scheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
                if (row.udise?.nameAsUuid.trim().isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      row.udise!.nameAsUuid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSurface);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant))),
        Expanded(flex: 3, child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: mismatch ? style.copyWith(fontWeight: FontWeight.w800, color: scheme.error) : style)),
        Expanded(flex: 3, child: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis, style: mismatch ? style.copyWith(fontWeight: FontWeight.w800, color: scheme.error) : style)),
      ]));
  }
}
