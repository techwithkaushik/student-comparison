import 'package:flutter/material.dart';

class ComparisonSummarySection extends StatelessWidget {
  final String sourceFilter, classFilter;
  final Set<String> statusFilters, apaarStatusFilters, aadhaarStatusFilters;
  final List<String> classes;
  final Set<String> apaarStatusOptions, aadhaarStatusOptions;
  final String Function(String) apaarStatusLabel, aadhaarStatusLabel;
  final ValueChanged<String> onSourceChanged, onStatusToggle, onApaarToggle, onAadhaarToggle, onClassChanged;
  final VoidCallback onClearFilters, onPrint;

  const ComparisonSummarySection({
    super.key,
    required this.sourceFilter,
    required this.classFilter,
    required this.statusFilters,
    required this.apaarStatusFilters,
    required this.aadhaarStatusFilters,
    required this.classes,
    required this.apaarStatusOptions,
    required this.aadhaarStatusOptions,
    required this.apaarStatusLabel,
    required this.aadhaarStatusLabel,
    required this.onSourceChanged,
    required this.onStatusToggle,
    required this.onApaarToggle,
    required this.onAadhaarToggle,
    required this.onClassChanged,
    required this.onClearFilters,
    required this.onPrint,
  });

  int get activeFilterCount =>
      (sourceFilter == 'ALL' ? 0 : 1) +
      statusFilters.length +
      apaarStatusFilters.length +
      aadhaarStatusFilters.length +
      (classFilter.isEmpty ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final compact = const EdgeInsets.symmetric(horizontal: 7, vertical: 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Choice(
                  'All',
                  Icons.select_all_rounded,
                  sourceFilter == 'ALL',
                  () => onSourceChanged('ALL'),
                  padding: compact,
                ),
                _Choice(
                  'PSP',
                  Icons.description_rounded,
                  sourceFilter == 'PSP',
                  () => onSourceChanged('PSP'),
                  padding: compact,
                ),
                _Choice(
                  'UDISE',
                  Icons.school_rounded,
                  sourceFilter == 'UDISE',
                  () => onSourceChanged('UDISE'),
                  padding: compact,
                ),
                _Choice(
                  'PSP-ONLY',
                  Icons.person_add_rounded,
                  sourceFilter == 'PSP_ONLY',
                  () => onSourceChanged('PSP_ONLY'),
                  padding: compact,
                ),
                _Choice(
                  'UDISE-ONLY',
                  Icons.person_search_rounded,
                  sourceFilter == 'UDISE_ONLY',
                  () => onSourceChanged('UDISE_ONLY'),
                  padding: compact,
                ),
                const SizedBox(width: 5),
                _ClassChip(
                  classFilter: classFilter,
                  classes: classes,
                  onChanged: onClassChanged,
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Print',
                  visualDensity: VisualDensity.compact,
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_rounded, size: 21),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  'MATCHED',
                  Icons.check_circle_rounded,
                  statusFilters.contains('MATCHED'),
                  () => onStatusToggle('MATCHED'),
                  padding: compact,
                ),
                _FilterChip(
                  'MISMATCH',
                  Icons.error_rounded,
                  statusFilters.contains('MISMATCH'),
                  () => onStatusToggle('MISMATCH'),
                  padding: compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  'RTE',
                  Icons.verified_rounded,
                  statusFilters.contains('RTE'),
                  () => onStatusToggle('RTE'),
                  padding: compact,
                ),
                const SizedBox(width: 5),
                _StatusFilterChip(
                  label: 'Aadhaar',
                  icon: Icons.fingerprint_rounded,
                  selected: aadhaarStatusFilters.isNotEmpty,
                  count: aadhaarStatusFilters.length,
                  onTap: () => _showStatusSheet(
                    context,
                    title: 'Aadhaar Status',
                    options: aadhaarStatusOptions,
                    selected: aadhaarStatusFilters,
                    labelFor: aadhaarStatusLabel,
                    onToggle: onAadhaarToggle,
                  ),
                  padding: compact,
                ),
                const SizedBox(width: 5),
                _StatusFilterChip(
                  label: 'APAAR',
                  icon: Icons.badge_rounded,
                  selected: apaarStatusFilters.isNotEmpty,
                  count: apaarStatusFilters.length,
                  onTap: () => _showStatusSheet(
                    context,
                    title: 'APAAR Status',
                    options: apaarStatusOptions,
                    selected: apaarStatusFilters,
                    labelFor: apaarStatusLabel,
                    onToggle: onApaarToggle,
                  ),
                  padding: compact,
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(width: 5),
                  ActionChip(
                    label: const Text('Clear'),
                    onPressed: onClearFilters,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusSheet(
    BuildContext context, {
    required String title,
    required Set<String> options,
    required Set<String> selected,
    required String Function(String) labelFor,
    required ValueChanged<String> onToggle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final current = <String>{...selected};
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: options.map((key) => _FilterChip(
                    labelFor(key),
                    title == 'APAAR Status' ? Icons.badge_rounded : Icons.fingerprint_rounded,
                    current.contains(key),
                    () {
                      if (!current.add(key)) current.remove(key);
                      onToggle(key);
                      setSheetState(() {});
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  )).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String classFilter;
  final List<String> classes;
  final ValueChanged<String> onChanged;

  const _ClassChip({
    required this.classFilter,
    required this.classes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Class filter',
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('All classes')),
        ...classes.map((value) => PopupMenuItem(
          value: value,
          child: Text('Class $value'),
        )),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: classFilter.isEmpty
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.primaryContainer,
          border: Border.all(
            color: classFilter.isEmpty
                ? Theme.of(context).colorScheme.outlineVariant
                : Theme.of(context).colorScheme.primary,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_rounded, size: 16),
            const SizedBox(width: 5),
            Text(classFilter.isEmpty ? 'Class' : 'Class $classFilter'),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets padding;

  const _Choice(this.label, this.icon, this.selected, this.onTap, {required this.padding});

  @override
  Widget build(BuildContext context) => ChoiceChip(
    avatar: Icon(icon, size: 15),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    padding: padding,
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    side: selected ? BorderSide(color: Theme.of(context).colorScheme.primary) : null,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets padding;

  const _FilterChip(this.label, this.icon, this.selected, this.onTap, {required this.padding});

  @override
  Widget build(BuildContext context) => FilterChip(
    avatar: Icon(icon, size: 15),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    padding: padding,
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    side: selected ? BorderSide(color: Theme.of(context).colorScheme.primary) : null,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
  );
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  final EdgeInsets padding;

  const _StatusFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.onTap,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) => FilterChip(
    avatar: Icon(icon, size: 15),
    label: Text(count == 0 ? label : '$label $count'),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    padding: padding,
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    side: selected ? BorderSide(color: Theme.of(context).colorScheme.primary) : null,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
  );
}
