import 'package:flutter/material.dart';
                                                                                        import '../matching/models.dart';

class ComparisonDashboardScreen extends StatefulWidget {
  final List<ComparisonRow> rows;
  final int pspCount;
  final int udiseCount;

  const ComparisonDashboardScreen({
    super.key,
    required this.rows,
    required this.pspCount,
    required this.udiseCount,
  });

  @override
  State<ComparisonDashboardScreen> createState() =>
      _ComparisonDashboardScreenState();
}

class _ComparisonDashboardScreenState
    extends State<ComparisonDashboardScreen> {                                            String _filter = 'ALL';
  String _classFilter = '';
  String _search = '';

  List<ComparisonRow> get _filteredRows {
    final q = _search.trim().toLowerCase();

    return widget.rows.where((row) {
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
    return widget.rows
        .where((row) => row.type == type)
        .length;
  }

  int _countDiff(String diff) {
    return widget.rows
        .where((row) => row.diffs.contains(diff))
        .length;
  }

  Set<String> get _classes {
    final result = <String>{};

    for (final row in widget.rows) {
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
        title: const Text(
          'Comparison',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${filtered.length}/${widget.rows.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _SummarySection(
            all: widget.rows.length,
            matched: _countType(MatchType.matched),
            mismatch: _countType(MatchType.mismatch),
            pspOnly: _countType(MatchType.notInUdise),
            udiseOnly: _countType(MatchType.notInPsp),
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
            padding: const EdgeInsets.fromLTRB(
              10,
              6,
              10,
              5,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    textInputAction:
                        TextInputAction.search,
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Search name, NIC, PEN, mobile...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _classFilter.isEmpty
                            ? null
                            : _classFilter,
                    isDense: true,
                    decoration:
                        InputDecoration(
                      labelText: 'Class',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All'),
                      ),
                      ...classes.map(
                        (value) =>
                            DropdownMenuItem(
                          value: value,
                          child: Text(
                            'Class $value',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _classFilter =
                            value ?? '';
                      });
                    },
                  ),
                ),
              ],
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
                      10,
                      2,
                      10,
                      16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      return _StudentRow(
                        row: filtered[index],
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
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary/status chips wrap to the next line instead of scrolling.
          Wrap(
            spacing: 6,
            runSpacing: 6,
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
            ],
          ),
          const SizedBox(height: 7),
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
    final scheme =
        Theme.of(context).colorScheme;

    final baseColor =
        color ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 82,
          height: 42,
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? baseColor.withValues(alpha: .16)
                : scheme.surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? baseColor
                  : scheme.outlineVariant,
              width: selected ? 1.2 : .6,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? baseColor
                      : scheme.onSurface,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: scheme.onSurfaceVariant,
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
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 102,
          height: 36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: selected ? 1.2 : .6,
              ),
            ),
            child: Center(
              child: Text(
                '$label $value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
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
  final String statusText;
  final Color statusColor;

  const _StudentRow({
    required this.row,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme =
        Theme.of(context).colorScheme;

    final name =
        row.psp?.studentName ??
        row.udise?.studentName ??
        'Unknown';

    final pspName =
        row.psp?.studentName ?? '—';

    final udiseName =
        row.udise?.studentName ?? '—';

    final pspId =
        row.psp?.nicId ?? '—';

    final pen =
        row.udise?.studentCodeNat ?? '—';

    final className =
        row.psp?.classCanonValue ??
        row.udise?.classDescCanon ??
        row.udise?.classIdCanon ??
        '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(
        bottom: 6,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(11),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.68,
              child: _StudentDetails(row: row),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 55,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius:
                      BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration:
                              BoxDecoration(
                            color: statusColor
                                .withValues(
                              alpha: .12,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              6,
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'PSP: $pspName  •  NIC: $pspId',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color:
                            scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'UDISE: $udiseName  •  PEN: $pen  •  Class: $className',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color:
                            scheme.onSurfaceVariant,
                      ),
                    ),
                    if (row.diffs.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 4,
                        ),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: row.diffs
                              .take(5)
                              .map(
                                (diff) =>
                                    _MiniBadge(
                                  text: diff
                                      .replaceAll(
                                        '_',
                                        ' ',
                                      ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;

  const _MiniBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Theme.of(context)
              .colorScheme
              .onErrorContainer,
        ),
      ),
    );
  }
}

class _StudentDetails extends StatelessWidget {
  final ComparisonRow row;

  const _StudentDetails({
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final p = row.psp;
    final u = row.udise;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p?.studentName ?? u?.studentName ?? 'Student',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            _ComparisonTable(row: row),
            if (row.diffs.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Differences',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: row.diffs
                    .map(
                      (e) => _MiniBadge(
                        text: e.replaceAll('_', ' '),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final ComparisonRow row;

  const _ComparisonTable({required this.row});

  bool _isDiff(String key) => row.diffs.contains(key);

  String _pspValue(String key) {
    final p = row.psp;
    if (p == null) return '—';

    switch (key) {
      case 'NIC / PEN':
        return p.nicId.isEmpty ? '—' : p.nicId;
      case 'Name':
        return p.studentName.isEmpty ? '—' : p.studentName;
      case 'Father':
        return p.fatherName.isEmpty ? '—' : p.fatherName;
      case 'Mother':
        return p.motherName.isEmpty ? '—' : p.motherName;
      case 'DOB':
        return p.dob.isEmpty ? '—' : p.dob;
      case 'Gender':
        return p.gender.isEmpty ? '—' : p.gender;
      case 'Class':
        return p.studyingClass.isEmpty ? '—' : p.studyingClass;
      case 'Mobile':
        return p.mobile.isEmpty ? '—' : p.mobile;
      case 'Aadhaar':
        return p.aadhaarLast4.isEmpty ? '—' : '•••• ${p.aadhaarLast4}';
      case 'Category':
        return p.socialCategory.isEmpty ? '—' : p.socialCategory;
      case 'Religion':
        return p.religion.isEmpty ? '—' : p.religion;
      default:
        return '—';
    }
  }

  String _classText(UdiseStudent u) {
    final n = u.classDescCanon;
    const names = <String, String>{
      '0': 'Pre-primary',
      '1': 'First',
      '2': 'Second',
      '3': 'Third',
      '4': 'Fourth',
      '5': 'Fifth',
      '6': 'Sixth',
      '7': 'Seventh',
      '8': 'Eighth',
      '9': 'Ninth',
      '10': 'Tenth',
      '11': 'Eleventh',
      '12': 'Twelfth',
    };

    if (names.containsKey(n)) return names[n]!;

    final id = u.classIdCanon;
    return names[id] ?? (u.classDesc.isNotEmpty ? u.classDesc : '—');
  }

  String _udiseValue(String key) {
    final u = row.udise;
    if (u == null) return '—';

    switch (key) {
      case 'NIC / PEN':
        return u.studentCodeNat.isEmpty ? '—' : u.studentCodeNat;
      case 'Name':
        return u.studentName.isEmpty ? '—' : u.studentName;
      case 'Father':
        return u.fatherName.isEmpty ? '—' : u.fatherName;
      case 'Mother':
        return u.motherName.isEmpty ? '—' : u.motherName;
      case 'DOB':
        return u.dob.isEmpty ? '—' : u.dob;
      case 'Gender':
        return u.gender.isEmpty ? '—' : u.gender;
      case 'Class':
        return _classText(u);
      case 'Mobile':
        return u.mobile.isEmpty ? '—' : u.mobile;
      case 'Aadhaar':
        return u.uuidLast4.isEmpty ? '—' : '•••• ${u.uuidLast4}';
      case 'Category':
        return u.categoryNorm.isEmpty ? '—' : u.categoryNorm;
      case 'Religion':
        return u.religionNormValue.isEmpty ? '—' : u.religionNormValue;
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const fields = [
      'NIC / PEN',
      'Name',
      'Father',
      'Mother',
      'DOB',
      'Gender',
      'Class',
      'Mobile',
      'Aadhaar',
      'Category',
      'Religion',
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 6,
              ),
              color: scheme.surfaceContainerHighest,
              child: const Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      'FIELD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'PSP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'UDISE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...fields.map((field) {
              final diffKey = switch (field) {
                'Name' => 'NAME_MISMATCH',
                'Father' => 'FATHER_MISMATCH',
                'Mother' => 'MOTHER_MISMATCH',
                'DOB' => 'DOB_MISMATCH',
                'Gender' => 'GENDER_MISMATCH',
                'Class' => 'CLASS_MISMATCH',
                'Mobile' => 'MOBILE_MISMATCH',
                'Aadhaar' => 'AADHAAR_MISMATCH',
                'Category' => 'CATEGORY_MISMATCH',
                'Religion' => 'RELIGION_MISMATCH',
                _ => null,
              };

              final different =
                  diffKey != null && _isDiff(diffKey);

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 68,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          field,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _ValueCell(
                        value: _pspValue(field),
                        mismatch: different,
                      ),
                    ),
                    Expanded(
                      child: _ValueCell(
                        value: _udiseValue(field),
                        mismatch: different,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final String value;
  final bool mismatch;

  const _ValueCell({
    required this.value,
    required this.mismatch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: mismatch ? scheme.errorContainer.withValues(alpha: .55) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        softWrap: true,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: mismatch ? FontWeight.w700 : FontWeight.w500,
          color: mismatch ? scheme.onErrorContainer : scheme.onSurface,
        ),
      ),
    );
  }
}
