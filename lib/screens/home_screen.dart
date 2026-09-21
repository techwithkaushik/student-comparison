cat lib/screens/home_screen.dart
import 'dart:convert';

import 'comparison_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../matching/matching_engine.dart';
import '../matching/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PspStudent> _psp = [];
  List<UdiseStudent> _udise = [];

  String? _pspFileName;
  String? _udiseFileName;

  bool _loadingPsp = false;
  bool _loadingUdise = false;
  bool _restoring = true;
  List<ComparisonRow> _comparisonRows = [];

  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSavedData();
  }

  Future<void> _restoreSavedData() async {
    try {
      final db = AppDatabase.instance;

      final pspRows = await db.loadPspRows();
      final udiseRows = await db.loadUdiseRows();

      final pspStudents = pspRows
          .map(PspStudent.fromJson)
          .toList();

      final udiseStudents = udiseRows
          .map(UdiseStudent.fromJson)
          .toList();

      if (!mounted) return;

      setState(() {
        _psp = pspStudents;
        _udise = udiseStudents;
        _pspFileName =
            pspStudents.isEmpty ? null : 'Saved PSP data';
        _udiseFileName =
            udiseStudents.isEmpty ? null : 'Saved UDISE data';
        _restoring = false;
      });
      _refreshComparison();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _restoring = false;
        _error = 'Unable to restore saved data: $e';
      });
    }
  }

  void _refreshComparison() {
    if (_psp.isEmpty || _udise.isEmpty) {
      if (mounted && _comparisonRows.isNotEmpty) {
        setState(() {
          _comparisonRows = [];
        });
      }
      return;
    }

    final rows = runMatchingEngine(_psp, _udise);
    if (!mounted) return;
    setState(() {
      _comparisonRows = rows;
    });
  }

  Future<void> _pickSqlite() async {
    setState(() {
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        withData: true,
      );

      if (result == null) return;
      final file = result.files.single;
      if (file.bytes == null) {
        throw Exception('Unable to read selected SQLite file.');
      }

      final imported = await AppDatabase.instance.importSqliteBytes(
        file.bytes!,
      );
      final pspRows = await AppDatabase.instance.loadPspRows();
      final udiseRows = await AppDatabase.instance.loadUdiseRows();

      final pspStudents = pspRows.map(PspStudent.fromJson).toList();
      final udiseStudents = udiseRows.map(UdiseStudent.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _psp = pspStudents;
        _udise = udiseStudents;
        _pspFileName = imported.pspCount > 0
            ? '${file.name} • PSP'
            : null;
        _udiseFileName = imported.udiseCount > 0
            ? '${file.name} • UDISE'
            : null;
      });
      _refreshComparison();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SQLite imported: ${imported.pspCount} PSP, '
              '${imported.udiseCount} UDISE'
              '${imported.remarkCount > 0 ? ', ${imported.remarkCount} remarks' : ''}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'SQLite import failed: $e';
      });
    }
  }

  Future<void> _pickPsp() async {
    setState(() {
      _loadingPsp = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null) return;

      final file = result.files.single;

      if (file.bytes == null) {
        throw Exception('Unable to read selected PSP file.');
      }

      final text = utf8.decode(file.bytes!);
      final decoded = jsonDecode(text);

      final List<dynamic> rows;

      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['data'] is List) {
        rows = decoded['data'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded['result'] is List) {
        rows = decoded['result'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded['result'] is Map<String, dynamic> &&
          decoded['result']['data'] is List) {
        rows = decoded['result']['data'] as List;
      } else {
        throw Exception(
          'No PSP student records found. '
          'Expected JSON array, data[], result[], or result.data[].',
        );
      }

      final students = rows
          .whereType<Map>()
          .map(
            (row) => PspStudent.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();

      if (students.isEmpty) {
        throw Exception('No valid PSP student records found.');
      }

      final dbRows = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      await AppDatabase.instance.replacePspRows(dbRows);

      setState(() {
        _psp = students;
        _pspFileName = file.name;
      });
      _refreshComparison();
    } catch (e) {
      setState(() {
        _error = 'PSP import failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPsp = false;
        });
      }
    }
  }

  Future<void> _pickUdise() async {
    setState(() {
      _loadingUdise = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null) return;

      final file = result.files.single;

      if (file.bytes == null) {
        throw Exception('Unable to read selected UDISE file.');
      }

      final text = utf8.decode(file.bytes!);
      final decoded = jsonDecode(text);

      final List<dynamic> rows;

      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['data'] is List) {
        rows = decoded['data'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded['result'] is List) {
        rows = decoded['result'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded['result'] is Map<String, dynamic> &&
          decoded['result']['data'] is List) {
        rows = decoded['result']['data'] as List;
      } else {
        throw Exception(
          'No UDISE student records found. '
          'Expected JSON array, data[], result[], or result.data[].',
        );
      }

      final students = rows
          .whereType<Map>()
          .map(
            (row) => UdiseStudent.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();

      if (students.isEmpty) {
        throw Exception('No valid UDISE student records found.');
      }

      final dbRows = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      await AppDatabase.instance.replaceUdiseRows(dbRows);

      setState(() {
        _udise = students;
        _udiseFileName = file.name;
      });
      _refreshComparison();
    } catch (e) {
      setState(() {
        _error = 'UDISE import failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUdise = false;
        });
      }
    }
  }

  void _openFullResults() {
    if (_comparisonRows.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComparisonDashboardScreen(
          rows: _comparisonRows,
          pspCount: _psp.length,
          udiseCount: _udise.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCompare = _psp.isNotEmpty && _udise.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 52,
        title: const Text(
          'PSP vs UDISE',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Import',
            onSelected: (value) {
              switch (value) {
                case 'psp':
                  _pickPsp();
                  break;
                case 'udise':
                  _pickUdise();
                  break;
                case 'sqlite':
                  _pickSqlite();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'psp',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Import PSP JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'udise',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.school_outlined),
                  title: Text('Import UDISE JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'sqlite',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storage_rounded),
                  title: Text('Import SQLite database'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            if (_restoring)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            _FileCard(
              title: 'PSP JSON',
              icon: Icons.account_balance_outlined,
              fileName: _pspFileName,
              count: _psp.length,
              loading: _loadingPsp,
              onTap: _pickPsp,
            ),
            const SizedBox(height: 8),
            _FileCard(
              title: 'UDISE JSON',
              icon: Icons.school_outlined,
              fileName: _udiseFileName,
              count: _udise.length,
              loading: _loadingUdise,
              onTap: _pickUdise,
            ),
            const SizedBox(height: 10),
            _SummaryBar(
              pspCount: _psp.length,
              udiseCount: _udise.length,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (canCompare) ...[
              const SizedBox(height: 12),
              _HomeResultsPreview(
                rows: _comparisonRows,
                pspCount: _psp.length,
                udiseCount: _udise.length,
                onOpenFull: _openFullResults,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeResultsPreview extends StatelessWidget {
  final List<ComparisonRow> rows;
  final int pspCount;
  final int udiseCount;
  final VoidCallback onOpenFull;

  const _HomeResultsPreview({
    required this.rows,
    required this.pspCount,
    required this.udiseCount,
    required this.onOpenFull,
  });

  int _count(MatchType type) =>
      rows.where((r) => r.type == type).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matched = _count(MatchType.matched);
    final mismatch = _count(MatchType.mismatch);
    final pspOnly = _count(MatchType.notInUdise);
    final udiseOnly = _count(MatchType.notInPsp);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 20),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Comparison Results',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} rows',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniResultChip('Matched', matched, Colors.green),
                _MiniResultChip('Mismatch', mismatch, scheme.error),
                _MiniResultChip('PSP only', pspOnly, Colors.blue),
                _MiniResultChip('UDISE only', udiseOnly, Colors.blue),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('PSP  $pspCount', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Expanded(child: Text('UDISE  $udiseCount', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isNotEmpty)
              ...rows.take(8).map((row) => _PreviewRow(row: row)),
            if (rows.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '+ ${rows.length - 8} more records',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: onOpenFull,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('OPEN FULL RESULTS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniResultChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniResultChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label  $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final ComparisonRow row;

  const _PreviewRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = switch (row.type) {
      MatchType.matched => 'MATCHED',
      MatchType.mismatch => 'MISMATCH',
      MatchType.possibleMatch => 'REVIEW',
      MatchType.notInUdise => 'PSP ONLY',
      MatchType.notInPsp => 'UDISE ONLY',
    };
    final color = switch (row.type) {
      MatchType.matched => Colors.green,
      MatchType.mismatch => scheme.error,
      MatchType.possibleMatch => Colors.orange,
      MatchType.notInUdise || MatchType.notInPsp => Colors.blue,
    };
    final name = row.psp?.studentName.isNotEmpty == true
        ? row.psp!.studentName
        : row.udise?.studentName ?? 'Unknown student';
    final detail = row.diffs.isEmpty
        ? 'No field differences'
        : row.diffs.join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 72,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? fileName;
  final int count;
  final bool loading;
  final VoidCallback onTap;

  const _FileCard({
    required this.title,
    required this.icon,
    required this.fileName,
    required this.count,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loaded = fileName != null && count > 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loaded
                          ? '$fileName • $count students'
                          : 'Tap to select JSON file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  loaded
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  size: 21,
                  color: loaded
                      ? Colors.green
                      : scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int pspCount;
  final int udiseCount;

  const _SummaryBar({
    required this.pspCount,
    required this.udiseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CountItem(
              label: 'PSP',
              count: pspCount,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
          Expanded(
            child: _CountItem(
              label: 'UDISE',
              count: udiseCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  final String label;
  final int count;

  const _CountItem({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class ComparisonPreviewScreen extends StatelessWidget {
  final List<ComparisonRow> rows;
  final int pspCount;
  final int udiseCount;

  const ComparisonPreviewScreen({
    super.key,
    required this.rows,
    required this.pspCount,
    required this.udiseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparison'),
      ),
      body: Center(
        child: Text(
          '${rows.length} comparison rows',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}