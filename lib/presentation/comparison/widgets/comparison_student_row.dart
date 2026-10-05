import 'package:flutter/material.dart';

import '../../matching/models.dart';
import 'comparison_details_dialog.dart';

const List<String> _admissionDateKeys = <String>[
  'Admission Date',
  'Admission date',
  'admissionDate',
  'admission_date',
  'Date of Admission',
];

class ComparisonStudentRow extends StatelessWidget {
  final ComparisonRow row;
  final bool hasRemark;
  final String statusText;
  final Color statusColor;
  final String rteText;
  final String remark;
  final VoidCallback onRemarkTap;

  const ComparisonStudentRow({
    super.key,
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
      builder: (_) => ComparisonDetailsDialog(row: row, side: side),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = row.psp;
    final u = row.udise;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      // Flat rows avoid per-card shadows and expensive offscreen clipping.
      elevation: 0,
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: .22), width: .7),
      ),
      child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
            color: statusColor.withValues(alpha: .06),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText == 'MATCHED'
                            ? 'Matched'
                            : statusText == 'MISMATCH'
                                ? 'Mismatch'
                                : statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        '${row.score}%',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SR: ${p?.srNo.trim().isNotEmpty == true ? p!.srNo : '—'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          decoration: BoxDecoration(
                            color: rteText == 'RTE'
                                ? Colors.orange.withValues(alpha: .14)
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            rteText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: rteText == 'RTE'
                                  ? Colors.orange.shade800
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Admission: ${_rawValue(p?.raw, _admissionDateKeys) ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                  tooltip: hasRemark ? 'Edit' : 'Add',
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
                  child: Text('FIELD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 3,
                  child: ComparisonClickableHeader(
                    title: 'PSP',
                    subtitle: 'Correct Data',
                    color: scheme.primary,
                    onTap: () => _openDetails(context, 'PSP'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: ComparisonClickableHeader(
                    title: 'UDISE',
                    subtitle: 'Current Data',
                    color: Colors.green.shade700,
                    onTap: () => _openDetails(context, 'UDISE'),
                  ),
                ),
              ],
            ),
          ),
          // Show all comparison fields directly; no collapsed preview section.
          ComparisonFieldRow(
            label: 'Name',
            psp: p?.studentName,
            udise: u?.studentName,
            mismatch: row.diffs.contains('NAME_MISMATCH'),
          ),
          ComparisonFieldRow(label: 'DOB', psp: p?.dob, udise: u?.dob, mismatch: row.diffs.contains('DOB_MISMATCH')),
          ComparisonFieldRow(label: 'Class', psp: p?.studyingClass, udise: u?.classDesc.isNotEmpty == true ? u?.classDesc : u?.classId, mismatch: row.diffs.contains('CLASS_MISMATCH')),
          PenApaarFieldRow(
            psp: p?.nicId,
            pen: u?.studentCodeNat,
            apaarId: _rawValue(
              u?.raw,
              const ['apaarId', 'APAAR ID', 'APAAR Id', 'apaar_id'],
            ),
          ),
          ComparisonFieldRow(label: 'Father', psp: p?.fatherName, udise: u?.fatherName, mismatch: row.diffs.contains('FATHER_MISMATCH')),
          ComparisonFieldRow(label: 'Mother', psp: p?.motherName, udise: u?.motherName, mismatch: row.diffs.contains('MOTHER_MISMATCH')),
          ComparisonFieldRow(label: 'Gender', psp: p?.gender, udise: _genderLabel(u?.gender), mismatch: row.diffs.contains('GENDER_MISMATCH')),
          ComparisonFieldRow(label: 'Category', psp: p?.categoryNorm, udise: u?.categoryNorm, mismatch: row.diffs.contains('CATEGORY_MISMATCH')),
          ComparisonFieldRow(label: 'Religion', psp: p?.religionNormValue, udise: u?.religionNormValue, mismatch: row.diffs.contains('RELIGION_MISMATCH')),
          ComparisonFieldRow(label: 'Mobile', psp: p?.mobile, udise: u?.mobile, mismatch: row.diffs.contains('MOBILE_MISMATCH')),
          AadhaarPreviewRow(row: row),
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

class PenApaarFieldRow extends StatelessWidget {
  final String? psp;
  final String? pen;
  final String? apaarId;

  const PenApaarFieldRow({
    required this.psp,
    required this.pen,
    required this.apaarId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = (psp ?? '').trim().isEmpty ? '—' : psp!.trim();
    final penValue = (pen ?? '').trim().isEmpty ? '—' : pen!.trim();
    final apaarValue = (apaarId ?? '').trim();
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'NIC ID / PEN',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  penValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
                if (apaarValue.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    apaarValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AadhaarPreviewRow extends StatelessWidget {
  final ComparisonRow row;

  const AadhaarPreviewRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pLast4 = row.psp?.aadhaarLast4.trim() ?? '';
    final uLast4 = row.udise?.uuidLast4.trim() ?? '';
    final p = row.psp == null
        ? '—'
        : (pLast4.isEmpty ? 'Not Found' : '****$pLast4');
    final u = row.udise == null
        ? '—'
        : (uLast4.isEmpty ? 'Not Found' : '****$uLast4');
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
                          fontSize: 10,
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
                        fontSize: 8,
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

class ComparisonFieldRow extends StatelessWidget {
  final String label; final String? psp; final String? udise; final bool mismatch;
  const ComparisonFieldRow({required this.label, required this.psp, required this.udise, this.mismatch = false});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = (psp ?? '').trim().isEmpty ? '—' : psp!.trim();
    final u = (udise ?? '').trim().isEmpty ? '—' : udise!.trim();
    final style = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.onSurface);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant))),
        Expanded(flex: 3, child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: mismatch ? style.copyWith(fontWeight: FontWeight.w800, color: scheme.error) : style)),
        Expanded(flex: 3, child: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis, style: mismatch ? style.copyWith(fontWeight: FontWeight.w800, color: scheme.error) : style)),
      ]));
  }
}
