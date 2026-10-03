import 'package:flutter_bloc/flutter_bloc.dart';
import '../matching/models.dart';
import '../printing/native_print_service.dart';

class PrintSettingsCubit extends Cubit<PrintSettings> {
  PrintSettingsCubit(super.initial);
  void setPaper(String? v) { if (v != null) emit(state.copyWith(paper: v)); }
  void setOrientation(String? v) { if (v != null) emit(state.copyWith(orientation: v)); }
  void setMargin(double v) => emit(state.copyWith(margin: v.round()));
  void setFontSize(double v) => emit(state.copyWith(fontSize: v));
  void setAutoFit(bool v) => emit(state.copyWith(autoFit: v));
  void setRepeatHeader(bool v) => emit(state.copyWith(repeatHeader: v));
  void setPageNumber(bool v) => emit(state.copyWith(pageNumber: v));
  Future<void> persist() => NativePrintService.saveSettings(state);

}

class PrintReportState {
  final List<ComparisonRow> rows;
  final String source;
  final String scope;
  final String selectedClass;
  final List<MapEntry<String,String>> entries;
  final List<String> classes;
  final List<String> fields;
  final Map<String,String> customHeaders;
  final bool loadingPreset;
  final String? error;

  const PrintReportState({
    required this.rows,
    this.source = 'PSP',
    this.scope = 'ALL',
    this.selectedClass = '',
    this.entries = const [],
    this.classes = const [],
    this.fields = const [],
    this.customHeaders = const {},
    this.loadingPreset = true,
    this.error,
  });

  PrintReportState copyWith({
    String? source, String? scope, String? selectedClass,
    List<MapEntry<String,String>>? entries, List<String>? classes,
    List<String>? fields, Map<String,String>? customHeaders,
    bool? loadingPreset, String? error, bool clearError = false,
  }) => PrintReportState(
    rows: rows,
    source: source ?? this.source,
    scope: scope ?? this.scope,
    selectedClass: selectedClass ?? this.selectedClass,
    entries: entries ?? this.entries,
    classes: classes ?? this.classes,
    fields: fields ?? this.fields,
    customHeaders: customHeaders ?? this.customHeaders,
    loadingPreset: loadingPreset ?? this.loadingPreset,
    error: clearError ? null : (error ?? this.error),
  );

  List<ComparisonRow> get sourceRows => rows.where((r) => source == 'PSP' ? r.psp != null : r.udise != null).toList(growable: false);

  List<ComparisonRow> get printableRows {
    if (scope != 'CLASS' || selectedClass.isEmpty) return sourceRows;
    return sourceRows.where((r) {
      final c = source == 'PSP'
          ? (r.psp?.classCanonValue ?? '')
          : (r.udise?.classDescCanon.isNotEmpty == true ? r.udise!.classDescCanon : r.udise?.classIdCanon ?? '');
      return c == selectedClass;
    }).toList(growable: false);
  }

  bool get valid => fields.isNotEmpty && (scope != 'CLASS' || selectedClass.isNotEmpty);
}

class PrintReportCubit extends Cubit<PrintReportState> {
  PrintReportCubit(List<ComparisonRow> rows)
      : super(PrintReportState(rows: List<ComparisonRow>.unmodifiable(rows))) {
    _rebuildSourceMetadata();
  }

  String _normKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _label(String key) {
    final s = key.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return key;
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  List<MapEntry<String,String>> _availableFields() {
    final out = <MapEntry<String,String>>[];
    final seen = <String>{};
    for (final row in state.sourceRows) {
      final raw = state.source == 'PSP' ? row.psp!.raw : row.udise!.raw;
      for (final key in raw.keys) {
        final trimmed = key.trim();
        if (trimmed.isEmpty || _normKey(trimmed) == 'sno') continue;
        if (seen.add(trimmed)) out.add(MapEntry(trimmed, _label(trimmed)));
      }
    }
    return out;
  }

  List<String> _availableClasses() {
    final values = <String>{};
    for (final row in state.sourceRows) {
      final value = state.source == 'PSP'
          ? (row.psp?.classCanonValue ?? '')
          : (row.udise?.classDescCanon.isNotEmpty == true ? row.udise!.classDescCanon : row.udise?.classIdCanon ?? '');
      if (value.isNotEmpty) values.add(value);
    }
    return values.toList()..sort();
  }

  void _rebuildSourceMetadata() {
    final entries = _availableFields();
    final classes = _availableClasses();
    emit(state.copyWith(
      entries: List.unmodifiable(entries),
      classes: List.unmodifiable(classes),
      fields: List.unmodifiable(entries.map((e) => e.key)),
      customHeaders: Map.unmodifiable({for (final e in entries) e.key: e.value}),
      loadingPreset: true,
      clearError: true,
    ));
  }

  Future<void> initialize() async => restoreColumnPreset();

  Future<void> setSource(String value) async {
    if (value == state.source) return;
    emit(state.copyWith(source: value, selectedClass: '', entries: const [], classes: const [], fields: const [], customHeaders: const {}, loadingPreset: true));
    _rebuildSourceMetadata();
    await restoreColumnPreset();
  }

  void setScope(String value) => emit(state.copyWith(scope: value, selectedClass: value == 'CLASS' ? state.selectedClass : ''));
  void setClass(String value) => emit(state.copyWith(selectedClass: value));
  void selectAll() => emit(state.copyWith(fields: List.unmodifiable(state.entries.map((e) => e.key))));
  void clearFields() => emit(state.copyWith(fields: const []));

  void toggleField(String key, bool selected) {
    final next = [...state.fields];
    if (selected && !next.contains(key)) next.add(key);
    if (!selected) next.remove(key);
    emit(state.copyWith(fields: List.unmodifiable(next)));
  }

  void reorder(int oldIndex, int newIndex) {
    final next = [...state.fields];
    if (newIndex > oldIndex) newIndex--;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    emit(state.copyWith(fields: List.unmodifiable(next)));
  }

  void setHeader(String key, String value) => emit(state.copyWith(customHeaders: Map.unmodifiable({...state.customHeaders, key: value})));

  Future<void> restoreColumnPreset() async {
    try {
      final preset = await NativePrintService.loadColumnPreferences(source: state.source);
      if (preset == null) {
        emit(state.copyWith(loadingPreset: false));
        return;
      }
      final byNormalized = <String,String>{for (final e in state.entries) _normKey(e.key): e.key};
      final savedFields = (preset['fields'] as List<dynamic>? ?? const []);
      final savedHeaders = (preset['headers'] as Map<dynamic,dynamic>? ?? const {});
      final restored = <String>[];
      for (final item in savedFields) {
        final actual = byNormalized[_normKey(item.toString())];
        if (actual != null && !restored.contains(actual)) restored.add(actual);
      }
      final headers = {for (final e in state.entries) e.key: e.value};
      for (final entry in savedHeaders.entries) {
        final actual = byNormalized[_normKey(entry.key.toString())];
        final header = entry.value?.toString() ?? '';
        if (actual != null && header.trim().isNotEmpty) headers[actual] = header;
      }
      emit(state.copyWith(fields: List.unmodifiable(restored), customHeaders: Map.unmodifiable(headers), loadingPreset: false));
    } catch (e) {
      emit(state.copyWith(loadingPreset: false, error: 'Could not restore print columns: $e'));
    }
  }

  List<MapEntry<String,String>> selectedColumns() {
    final byKey = {for (final e in state.entries) e.key: e.value};
    return state.fields.map((key) {
      final fallback = byKey[key] ?? _label(key);
      final header = (state.customHeaders[key] ?? fallback).trim();
      return MapEntry(key, header.isEmpty ? fallback : header);
    }).toList(growable: false);
  }

  String _valueFor(ComparisonRow row, String requested) {
    final raw = state.source == 'PSP' ? row.psp!.raw : row.udise!.raw;
    final target = _normKey(requested);
    for (final entry in raw.entries) {
      if (_normKey(entry.key) != target) continue;
      final value = entry.value?.toString().trim() ?? '';
      if (target == 'gettingfreeeducation') {
        final normalized = value.toLowerCase();
        return (normalized == 'yes' || normalized == 'y' || normalized == 'true' || normalized == '1') ? 'YES' : 'NO';
      }
      return value;
    }
    return '';
  }

  List<List<String>> buildTable() {
    final columns = selectedColumns();
    return state.printableRows.map((row) => columns.map((c) => _valueFor(row, c.key)).toList()).toList(growable: false);
  }

  Future<void> saveColumnPreferences() => NativePrintService.saveColumnPreferences(
    source: state.source, fields: state.fields, headers: state.customHeaders,
  );
  Future<void> printReport({
    required String schoolName,
    required String pspCode,
    required String udiseCode,
    required PrintSettings settings,
  }) async {
    if (!state.valid) throw StateError('Please select a class and at least one field.');
    final columns = selectedColumns();
    await NativePrintService.printTable(
      title: '($pspCode) ($udiseCode) $schoolName',
      subtitle: '${state.scope == 'ALL' ? 'All' : 'Class : ${state.selectedClass}'}    ${state.source} REPORT    Student Count : ${state.printableRows.length}',
      columns: columns.map((e) => e.value).toList(growable: false),
      rows: buildTable(),
      settings: settings,
    );
    await saveColumnPreferences();
  }

}
