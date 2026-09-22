import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../database/remark_repository.dart';
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
      for (final r in rows) {
        final p = r['psp_nic']?.toString() ?? '';
        final u = r['udise_pen']?.toString() ?? '';
        if (p.isNotEmpty || u.isNotEmpty) {
          keys.add('${_key(p)}|${_key(u)}');
        }
      }
      if (!mounted) return;
      setState(() {
        _remarkKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (_) {
      // Keep the comparison list usable even if the remark table cannot be read.
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
            all: _rows.length,
            matched: _countType(MatchType.matched),
            mismatch: _countType(MatchType.mismatch),
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
                        statusColor:
                            _statusColor(
                          context,
                          filtered[index],
                        ),
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
              _StatChip(
                label: 'Matched',
                value: matched,
                color: Colors.green,
                selected: selected == 'MATCHED',
                onTap: () => onSelected('MATCHED'),
              ),
              _StatChip(
                label: 'Mismatch',
                value: mismatch,
                color: Colors.red,
                selected: selected == 'MISMATCH',
                onTap: () => onSelected('MISMATCH'),
              ),
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

  const _StudentRow({
    required this.row,
    required this.hasRemark,
    required this.statusText,
    required this.statusColor,
  });

  void _open(BuildContext context, _StudentSource source) {
    final student = source == _StudentSource.psp ? row.psp : row.udise;
    if (student == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SourceStudentDetails(row: row, source: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                if (hasRemark)
                  const Icon(Icons.sticky_note_2_rounded,
                      size: 15, color: Colors.deepPurple),
                const SizedBox(width: 5),
                Text(
                  '${row.score}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SourcePreviewPanel(
                  source: _StudentSource.psp,
                  row: row,
                  onTap: () => _open(context, _StudentSource.psp),
                ),
              ),
              Container(width: 1, color: scheme.outlineVariant),
              Expanded(
                child: _SourcePreviewPanel(
                  source: _StudentSource.udise,
                  row: row,
                  onTap: () => _open(context, _StudentSource.udise),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StudentSource { psp, udise }

class _SourcePreviewPanel extends StatelessWidget {
  final _StudentSource source;
  final ComparisonRow row;
  final VoidCallback onTap;

  const _SourcePreviewPanel({
    required this.source,
    required this.row,
    required this.onTap,
  });

  bool get _isPsp => source == _StudentSource.psp;

  Map<String, dynamic> get _raw =>
      (_isPsp ? row.psp?.raw : row.udise?.raw) ?? const <String, dynamic>{};

  String _v(String key) {
    final value = _raw[key];
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString();
  }

  String _first(List<String> keys) {
    for (final key in keys) {
      final value = _v(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _maskAadhaar(String value) {
    if (value.isEmpty) return '';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) return '•••• ${digits.substring(digits.length - 4)}';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exists = _isPsp ? row.psp != null : row.udise != null;
    final primary = _isPsp ? _first(['Student Name']) : _first(['studentName']);
    final father = _isPsp ? _first(['Father Name']) : _first(['fatherName']);
    final mother = _isPsp ? _first(['Mother Name']) : _first(['motherName']);
    final dob = _isPsp ? _first(['DOB']) : _first(['dob']);
    final gender = _isPsp ? _first(['Gender']) : _first(['gender']);
    final className = _isPsp
        ? _first(['Studying in Class'])
        : _first(['classDesc', 'classId']);
    final category = _isPsp
        ? _first(['Social Category'])
        : _first(['socialCategoryDesc', 'socCatId']);
    final religion = _isPsp
        ? _first(['Religion'])
        : _first(['minorityDesc', 'minorityId']);
    final id = _isPsp
        ? _first(['Student NIC ID'])
        : _first(['studentCodeNat']);
    final secondaryId = _isPsp
        ? _first(['SR No.'])
        : _first(['studentId']);
    final mobile = _isPsp
        ? _first(['Mobile Number'])
        : _first(['primaryMobile']);
    final aadhaar = _isPsp ? _first(['Aadhar Number']) : _first(['uuid']);
    final aadhaarStatus = _isPsp ? '' : _first(['uuidStatus']);
    final nameAsAadhaar = _isPsp ? '' : _first(['nameAsUuid']);
    final accent = _isPsp ? scheme.primary : Colors.green.shade700;
    final surface = _isPsp
        ? scheme.primaryContainer.withValues(alpha: .25)
        : Colors.green.withValues(alpha: .07);

    return Material(
      color: surface,
      child: InkWell(
        onTap: exists ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 7, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isPsp ? 'PSP — Correct Data' : 'UDISE — Current Data',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  if (exists)
                    Icon(Icons.open_in_new_rounded, size: 14, color: accent),
                ],
              ),
              const SizedBox(height: 5),
              if (!exists)
                Text(
                  _isPsp ? 'PSP record not available' : 'UDISE record not available',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                _PreviewName(value: primary),
                _PreviewLine(label: 'Father', value: father),
                _PreviewLine(label: 'Mother', value: mother),
                _PreviewLine(label: 'DOB', value: dob),
                _PreviewLine(label: 'Class', value: className),
                _PreviewLine(label: 'Gender', value: gender),
                _PreviewLine(label: 'Category', value: category),
                _PreviewLine(label: 'Religion', value: religion),
                _PreviewLine(label: _isPsp ? 'NIC ID' : 'PEN', value: id),
                _PreviewLine(
                  label: _isPsp ? 'SR' : 'Student ID',
                  value: secondaryId,
                ),
                _PreviewLine(label: 'Mobile', value: mobile),
                if (aadhaar.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 3,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AADHAAR ${_maskAadhaar(aadhaar)}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        if (!_isPsp && aadhaarStatus.isNotEmpty)
                          Text(
                            '✓',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (!_isPsp && nameAsAadhaar.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Name in Aadhaar: $nameAsAadhaar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Tap to view all fields',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewName extends StatelessWidget {
  final String value;
  const _PreviewName({required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        value.isEmpty ? '—' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 9.2,
          height: 1.28,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  const _MiniBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _SourceStudentDetails extends StatefulWidget {
  final ComparisonRow row;
  final _StudentSource source;

  const _SourceStudentDetails({
    required this.row,
    required this.source,
  });

  @override
  State<_SourceStudentDetails> createState() => _SourceStudentDetailsState();
}

class _SourceStudentDetailsState extends State<_SourceStudentDetails> {
  final _remarkRepository = RemarkRepository();
  String _remark = '';
  bool _loadingRemark = true;
  bool _savingRemark = false;

  bool get _isPsp => widget.source == _StudentSource.psp;

  Map<String, dynamic> get _raw =>
      (_isPsp ? widget.row.psp?.raw : widget.row.udise?.raw) ??
      const <String, dynamic>{};

  String get _name => _isPsp
      ? (widget.row.psp?.studentName ?? 'PSP Student')
      : (widget.row.udise?.studentName ?? 'UDISE Student');

  String get _sourceTitle =>
      _isPsp ? 'PSP Student Details' : 'UDISE Student Details';

  Color _accent(BuildContext context) =>
      _isPsp ? Theme.of(context).colorScheme.primary : Colors.green.shade700;

  @override
  void initState() {
    super.initState();
    _loadRemark();
  }

  Future<void> _loadRemark() async {
    try {
      final saved = await _remarkRepository.get(
        pspNic: widget.row.psp?.nicId,
        udisePen: widget.row.udise?.studentCodeNat,
      );
      if (!mounted) return;
      setState(() {
        _remark = saved?['remark']?.toString() ?? '';
        _loadingRemark = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRemark = false);
    }
  }

  String _display(dynamic value) {
    if (value == null) return '—';
    if (value is String && value.trim().isEmpty) return '—';
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  List<String> get _fields {
    final result = _raw.keys.map((e) => e.toString()).toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<void> _editRemark() async {
    final controller = TextEditingController(text: _remark);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit Remark',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Enter remark...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim(),
              ),
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('SAVE'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final pspNic = widget.row.psp?.nicId ?? '';
    final udisePen = widget.row.udise?.studentCodeNat ?? '';
    setState(() => _savingRemark = true);

    try {
      if (value.isEmpty) {
        await _remarkRepository.delete(pspNic: pspNic, udisePen: udisePen);
      } else {
        await _remarkRepository.save(
          pspNic: pspNic,
          udisePen: udisePen,
          remark: value,
        );
      }
      if (!mounted) return;
      setState(() {
        _remark = value;
        _savingRemark = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.isEmpty ? 'Remark removed' : 'Remark saved'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingRemark = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save remark: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sourceTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              padding: const EdgeInsets.fromLTRB(11, 9, 7, 9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: .22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remark',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (_loadingRemark)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            _remark.isEmpty ? 'No remark saved' : _remark,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: _remark.isEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: _remark.isEmpty
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit remark',
                    onPressed: _savingRemark ? null : _editRemark,
                    icon: _savingRemark
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.edit_rounded, size: 20, color: accent),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 2, 11, 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isPsp ? 'PSP' : 'UDISE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: _fields.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final key = _fields[index];
                  final value = _display(_raw[key]);
                  return Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          key,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SelectableText(
                          value,
                          style: const TextStyle(fontSize: 12, height: 1.25),
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
}
