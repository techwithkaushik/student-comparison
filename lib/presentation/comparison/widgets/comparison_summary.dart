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
    const compact = EdgeInsets.symmetric(horizontal: 5, vertical: 0);
    const chipMargin = EdgeInsets.all(2.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Wrap(
              spacing: 0,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: chipMargin,
                  child: _Choice(
                    'All',
                    Icons.select_all_rounded,
                    sourceFilter == 'ALL',
                    () => onSourceChanged('ALL'),
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _Choice(
                    'PSP',
                    Icons.description_rounded,
                    sourceFilter == 'PSP',
                    () => onSourceChanged('PSP'),
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _Choice(
                    'UDISE',
                    Icons.school_rounded,
                    sourceFilter == 'UDISE',
                    () => onSourceChanged('UDISE'),
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _Choice(
                    'PSP-ONLY',
                    Icons.person_add_rounded,
                    sourceFilter == 'PSP_ONLY',
                    () => onSourceChanged('PSP_ONLY'),
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _Choice(
                    'UDISE-ONLY',
                    Icons.person_search_rounded,
                    sourceFilter == 'UDISE_ONLY',
                    () => onSourceChanged('UDISE_ONLY'),
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _ClassChip(
                    classFilter: classFilter,
                    classes: classes,
                    onChanged: onClassChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(1),
                  child: IconButton(
                    tooltip: 'Print',
                    visualDensity: VisualDensity.compact,
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(padding: chipMargin, child: _FilterChip(
                  'MATCHED',
                  Icons.check_circle_rounded,
                  statusFilters.contains('MATCHED'),
                  () => onStatusToggle('MATCHED'),
                  padding: compact,
                )),
                Padding(padding: chipMargin, child: _FilterChip(
                  'MISMATCH',
                  Icons.error_rounded,
                  statusFilters.contains('MISMATCH'),
                  () => onStatusToggle('MISMATCH'),
                  padding: compact,
                )),
              ],
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: chipMargin,
                  child: _FilterChip(
                    'RTE',
                  Icons.verified_rounded,
                  statusFilters.contains('RTE'),
                  () => onStatusToggle('RTE'),
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _StatusDropdownChip(
                    label: 'Aadhaar',
                    icon: Icons.fingerprint_rounded,
                    options: aadhaarStatusOptions,
                    selected: aadhaarStatusFilters,
                    labelFor: aadhaarStatusLabel,
                    onChanged: onAadhaarToggle,
                    padding: compact,
                  ),
                ),
                Padding(
                  padding: chipMargin,
                  child: _StatusDropdownChip(
                    label: 'APAAR',
                    icon: Icons.badge_rounded,
                    options: apaarStatusOptions,
                    selected: apaarStatusFilters,
                    labelFor: apaarStatusLabel,
                    onChanged: onApaarToggle,
                    padding: compact,
                  ),
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
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 3),
        Text(label),
      ],
    ),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    labelPadding: EdgeInsets.zero,
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
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 3),
        Text(label),
      ],
    ),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    labelPadding: EdgeInsets.zero,
    padding: padding,
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    side: selected ? BorderSide(color: Theme.of(context).colorScheme.primary) : null,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
  );
}

class _StatusDropdownChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Set<String> options;
  final Set<String> selected;
  final String Function(String) labelFor;
  final ValueChanged<String> onChanged;
  final EdgeInsets padding;

  const _StatusDropdownChip({
    required this.label,
    required this.icon,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final selectedKey = selected.isEmpty ? null : selected.first;
    final displayLabel = selectedKey == null
        ? label
        : '$label: ${labelFor(selectedKey)}';

    return PopupMenuButton<String>(
      tooltip: '$label status',
      onSelected: (key) {
        if (key == '__CLEAR__') {
          if (selectedKey != null) onChanged(selectedKey);
        } else {
          onChanged(key);
        }
      },
      itemBuilder: (_) => [
        if (selectedKey != null)
          const PopupMenuItem<String>(
            value: '__CLEAR__',
            child: Text('Clear'),
          ),
        ...options.map(
          (key) => PopupMenuItem<String>(
            value: key,
            child: Text(labelFor(key)),
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: padding,
        decoration: BoxDecoration(
          color: selectedKey == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.primaryContainer,
          border: Border.all(
            color: selectedKey == null
                ? Theme.of(context).colorScheme.outlineVariant
                : Theme.of(context).colorScheme.primary,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 3),
            Text(displayLabel),
            const SizedBox(width: 1),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
