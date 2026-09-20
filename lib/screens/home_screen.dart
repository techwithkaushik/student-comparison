import 'dart:convert';

import 'comparison_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

  String? _error;

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
      
      setState(() {
        _psp = students;
        _pspFileName = file.name;
      });
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
      
      setState(() {
        _udise = students;
        _udiseFileName = file.name;
      });
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

  void _compare() {
    if (_psp.isEmpty || _udise.isEmpty) return;

    final rows = runMatchingEngine(_psp, _udise);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComparisonDashboardScreen(
          rows: rows,
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
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
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: canCompare ? _compare : null,
                icon: const Icon(
                  Icons.compare_arrows_rounded,
                  size: 20,
                ),
                label: const Text(
                  'COMPARE STUDENTS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ),
          ],
        ),
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
