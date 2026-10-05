import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../matching/models.dart';

class ComparisonClickableHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ComparisonClickableHeader({super.key, required this.title, required this.subtitle, required this.color, required this.onTap});

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
              Icon(Icons.open_in_new_rounded, size: 12, color: color),
              const SizedBox(width: 3),
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: 3),
              Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color))),
            ],
          ),
        ),
      ),
    );
  }
}

class ComparisonDetailsDialog extends StatelessWidget {
  final ComparisonRow row;
  final String side;

  const ComparisonDetailsDialog({super.key, required this.row, required this.side});

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
              child: SelectionArea(
                // Keep one selection registrar for all source fields in the
                // dialog instead of making every field independently selectable.
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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

