import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/print_repository.dart';
import '../matching/models.dart';
import '../printing/native_print_service.dart';

class PrintSettingsState extends Equatable {
  final PrintSettings settings;
  final bool saving;
  final String? error;

  const PrintSettingsState({
    required this.settings,
    this.saving = false,
    this.error,
  });

  String get paper => settings.paper;
  String get orientation => settings.orientation;
  int get marginTop => settings.marginTop;
  int get marginRight => settings.marginRight;
  int get marginBottom => settings.marginBottom;
  int get marginLeft => settings.marginLeft;
  int get cellVerticalPadding => settings.cellVerticalPadding;
  int get cellHorizontalPadding => settings.cellHorizontalPadding;
  double get fontSize => settings.fontSize;
  bool get autoFit => settings.autoFit;
  bool get repeatHeader => settings.repeatHeader;
  bool get pageNumber => settings.pageNumber;

  PrintSettingsState copyWith({
    PrintSettings? settings,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => PrintSettingsState(
    settings: settings ?? this.settings,
    saving: saving ?? this.saving,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [settings, saving, error];
}

sealed class PrintSettingsEvent extends Equatable {
  const PrintSettingsEvent();
  @override List<Object?> get props => [];
}
final class PrintPaperChanged extends PrintSettingsEvent {
  final String value;
  const PrintPaperChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintOrientationChanged extends PrintSettingsEvent {
  final String value;
  const PrintOrientationChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintMarginTopChanged extends PrintSettingsEvent {
  final int value;
  const PrintMarginTopChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintMarginRightChanged extends PrintSettingsEvent {
  final int value;
  const PrintMarginRightChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintMarginBottomChanged extends PrintSettingsEvent {
  final int value;
  const PrintMarginBottomChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintMarginLeftChanged extends PrintSettingsEvent {
  final int value;
  const PrintMarginLeftChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintCellVerticalPaddingChanged extends PrintSettingsEvent {
  final int value;
  const PrintCellVerticalPaddingChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintCellHorizontalPaddingChanged extends PrintSettingsEvent {
  final int value;
  const PrintCellHorizontalPaddingChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintFontSizeChanged extends PrintSettingsEvent {
  final double value;
  const PrintFontSizeChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintAutoFitChanged extends PrintSettingsEvent {
  final bool value;
  const PrintAutoFitChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintRepeatHeaderChanged extends PrintSettingsEvent {
  final bool value;
  const PrintRepeatHeaderChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintPageNumberChanged extends PrintSettingsEvent {
  final bool value;
  const PrintPageNumberChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintSettingsPersistRequested extends PrintSettingsEvent {
  final Completer<void> completer;
  const PrintSettingsPersistRequested(this.completer);
}
class PrintSettingsBloc extends Bloc<PrintSettingsEvent, PrintSettingsState> {
  final PrintRepository _repository;
  PrintSettingsBloc({required PrintRepository repository, required PrintSettings initial})
      : _repository = repository,
        super(PrintSettingsState(settings: initial)) {
    on<PrintPaperChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(paper: e.value))));
    on<PrintOrientationChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(orientation: e.value))));
    on<PrintMarginTopChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(marginTop: e.value.clamp(0, 50).toInt()))));
    on<PrintMarginRightChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(marginRight: e.value.clamp(0, 50).toInt()))));
    on<PrintMarginBottomChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(marginBottom: e.value.clamp(0, 50).toInt()))));
    on<PrintMarginLeftChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(marginLeft: e.value.clamp(0, 50).toInt()))));
    on<PrintCellVerticalPaddingChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(cellVerticalPadding: e.value.clamp(0, 10).toInt()))));
    on<PrintCellHorizontalPaddingChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(cellHorizontalPadding: e.value.clamp(0, 10).toInt()))));
    on<PrintFontSizeChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(fontSize: e.value))));
    on<PrintAutoFitChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(autoFit: e.value))));
    on<PrintRepeatHeaderChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(repeatHeader: e.value))));
    on<PrintPageNumberChanged>((e, emit) => emit(state.copyWith(settings: state.settings.copyWith(pageNumber: e.value))));
    on<PrintSettingsPersistRequested>(_onPersist);
  }

  Future<void> _onPersist(PrintSettingsPersistRequested event, Emitter<PrintSettingsState> emit) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.saveSettings(state.settings);
      if (!event.completer.isCompleted) event.completer.complete();
      emit(state.copyWith(saving: false));
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(saving: false, error: 'Could not save print settings: $e'));
    }
  }

  void setPaper(String? value) { if (value != null) add(PrintPaperChanged(value)); }
  void setOrientation(String? value) { if (value != null) add(PrintOrientationChanged(value)); }
  void setMarginTop(int value) => add(PrintMarginTopChanged(value));
  void setMarginRight(int value) => add(PrintMarginRightChanged(value));
  void setMarginBottom(int value) => add(PrintMarginBottomChanged(value));
  void setMarginLeft(int value) => add(PrintMarginLeftChanged(value));
  void setCellVerticalPadding(int value) => add(PrintCellVerticalPaddingChanged(value));
  void setCellHorizontalPadding(int value) => add(PrintCellHorizontalPaddingChanged(value));
  void setFontSize(double value) => add(PrintFontSizeChanged(value));
  void setAutoFit(bool value) => add(PrintAutoFitChanged(value));
  void setRepeatHeader(bool value) => add(PrintRepeatHeaderChanged(value));
  void setPageNumber(bool value) => add(PrintPageNumberChanged(value));
  Future<void> persist() { final c = Completer<void>(); add(PrintSettingsPersistRequested(c)); return c.future; }
}

class PrintReportState extends Equatable {
  final List<ComparisonRow> rows;
  final String source;
  final String scope;
  final String selectedClass;
  final List<MapEntry<String, String>> entries;
  final List<String> classes;
  final List<String> fields;
  final Map<String, String> customHeaders;
  final bool loadingPreset;
  final bool printing;
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
    this.printing = false,
    this.error,
  });

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

  PrintReportState copyWith({
    String? source,
    String? scope,
    String? selectedClass,
    List<MapEntry<String, String>>? entries,
    List<String>? classes,
    List<String>? fields,
    Map<String, String>? customHeaders,
    bool? loadingPreset,
    bool? printing,
    String? error,
    bool clearError = false,
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
    printing: printing ?? this.printing,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [rows, source, scope, selectedClass, entries, classes, fields, customHeaders, loadingPreset, printing, error];
}

sealed class PrintReportEvent extends Equatable {
  const PrintReportEvent();
  @override List<Object?> get props => [];
}
final class PrintReportInitializeRequested extends PrintReportEvent {}
final class PrintReportSourceChanged extends PrintReportEvent {
  final String value;
  const PrintReportSourceChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintReportScopeChanged extends PrintReportEvent {
  final String value;
  const PrintReportScopeChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintReportClassChanged extends PrintReportEvent {
  final String value;
  const PrintReportClassChanged(this.value);
  @override List<Object?> get props => [value];
}
final class PrintReportSelectAll extends PrintReportEvent {}
final class PrintReportClearFields extends PrintReportEvent {}
final class PrintReportFieldToggled extends PrintReportEvent {
  final String key;
  final bool selected;
  const PrintReportFieldToggled(this.key, this.selected);
  @override List<Object?> get props => [key, selected];
}
final class PrintReportFieldsReordered extends PrintReportEvent {
  final int oldIndex;
  final int newIndex;
  const PrintReportFieldsReordered(this.oldIndex, this.newIndex);
  @override List<Object?> get props => [oldIndex, newIndex];
}
final class PrintReportHeaderChanged extends PrintReportEvent {
  final String key;
  final String value;
  const PrintReportHeaderChanged(this.key, this.value);
  @override List<Object?> get props => [key, value];
}
final class PrintReportPrintRequested extends PrintReportEvent {
  final String schoolName;
  final String pspCode;
  final String udiseCode;
  final PrintSettings settings;
  final Completer<void> completer;
  const PrintReportPrintRequested({required this.schoolName, required this.pspCode, required this.udiseCode, required this.settings, required this.completer});
  @override List<Object?> get props => [schoolName, pspCode, udiseCode, settings];
}

class PrintReportBloc extends Bloc<PrintReportEvent, PrintReportState> {
  final PrintRepository _repository;

  PrintReportBloc({required PrintRepository repository, required List<ComparisonRow> rows})
      : _repository = repository,
        super(PrintReportState(rows: List<ComparisonRow>.unmodifiable(rows))) {
    on<PrintReportInitializeRequested>(_onInitialize);
    on<PrintReportSourceChanged>(_onSource);
    on<PrintReportScopeChanged>((e, emit) => emit(state.copyWith(scope: e.value, selectedClass: e.value == 'CLASS' ? state.selectedClass : '')));
    on<PrintReportClassChanged>((e, emit) => emit(state.copyWith(selectedClass: e.value)));
    on<PrintReportSelectAll>((e, emit) => emit(state.copyWith(fields: List<String>.unmodifiable(state.entries.map((e) => e.key)))));
    on<PrintReportClearFields>((e, emit) => emit(state.copyWith(fields: const [])));
    on<PrintReportFieldToggled>(_onToggleField);
    on<PrintReportFieldsReordered>(_onReorder);
    on<PrintReportHeaderChanged>(_onHeader);
    on<PrintReportPrintRequested>(_onPrint);
  }

  String _normKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  String _label(String key) {
    final s = key.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return key;
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
  List<MapEntry<String, String>> _availableFields() {
    final out = <MapEntry<String, String>>[];
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
  void _rebuildMetadata(Emitter<PrintReportState> emit) {
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
  Future<void> _onInitialize(PrintReportInitializeRequested event, Emitter<PrintReportState> emit) async {
    _rebuildMetadata(emit);
    await _restorePreset(emit);
  }
  Future<void> _onSource(PrintReportSourceChanged event, Emitter<PrintReportState> emit) async {
    if (event.value == state.source) return;
    emit(state.copyWith(source: event.value, selectedClass: '', entries: const [], classes: const [], fields: const [], customHeaders: const {}, loadingPreset: true));
    _rebuildMetadata(emit);
    await _restorePreset(emit);
  }
  Future<void> _restorePreset(Emitter<PrintReportState> emit) async {
    try {
      final preset = await _repository.loadColumnPreferences(source: state.source);
      if (preset == null) {
        emit(state.copyWith(loadingPreset: false));
        return;
      }
      final byNormalized = <String, String>{for (final e in state.entries) _normKey(e.key): e.key};
      final savedFields = preset['fields'] as List<dynamic>? ?? const [];
      final savedHeaders = preset['headers'] as Map<dynamic, dynamic>? ?? const {};
      final restored = <String>[];
      for (final item in savedFields) {
        final actual = byNormalized[_normKey(item.toString())];
        if (actual != null && !restored.contains(actual)) restored.add(actual);
      }
      final headers = <String, String>{for (final e in state.entries) e.key: e.value};
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
  void _onToggleField(PrintReportFieldToggled event, Emitter<PrintReportState> emit) {
    final next = [...state.fields];
    if (event.selected && !next.contains(event.key)) next.add(event.key);
    if (!event.selected) next.remove(event.key);
    emit(state.copyWith(fields: List.unmodifiable(next)));
  }
  void _onReorder(PrintReportFieldsReordered event, Emitter<PrintReportState> emit) {
    final next = [...state.fields];
    var newIndex = event.newIndex;
    if (newIndex > event.oldIndex) newIndex--;
    final item = next.removeAt(event.oldIndex);
    next.insert(newIndex, item);
    emit(state.copyWith(fields: List.unmodifiable(next)));
  }
  void _onHeader(PrintReportHeaderChanged event, Emitter<PrintReportState> emit) {
    emit(state.copyWith(customHeaders: Map.unmodifiable({...state.customHeaders, event.key: event.value})));
  }
  List<MapEntry<String, String>> selectedColumns() {
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
    return state.printableRows.asMap().entries.map((entry) => <String>[
      '${entry.key + 1}',
      ...columns.map((c) => _valueFor(entry.value, c.key)),
    ]).toList(growable: false);
  }
  Future<void> _onPrint(PrintReportPrintRequested event, Emitter<PrintReportState> emit) async {
    if (!state.valid) {
      final error = StateError('Please select a class and at least one field.');
      if (!event.completer.isCompleted) event.completer.completeError(error);
      emit(state.copyWith(error: error.toString()));
      return;
    }
    emit(state.copyWith(printing: true, clearError: true));
    try {
      final columns = selectedColumns();
      final scopeLabel = state.scope == 'ALL' ? 'All' : 'Class: ${state.selectedClass}';
      final reportLabel = '${state.source} Report';
      final countLabel = 'count: ${state.printableRows.length}';
      await _repository.printTable(
        title: '$scopeLabel | $reportLabel | $countLabel',
        columns: <String>['S.No.', ...columns.map((e) => e.value)],
        rows: buildTable(),
        settings: event.settings,
      );
      await _repository.saveColumnPreferences(
        source: state.source,
        fields: state.fields,
        headers: state.customHeaders,
      );
      if (!event.completer.isCompleted) event.completer.complete();
      emit(state.copyWith(printing: false));
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(printing: false, error: 'Print failed: $e'));
    }
  }

  void initialize() => add(PrintReportInitializeRequested());
  void setSource(String value) => add(PrintReportSourceChanged(value));
  void setScope(String value) => add(PrintReportScopeChanged(value));
  void setClass(String value) => add(PrintReportClassChanged(value));
  void selectAll() => add(PrintReportSelectAll());
  void clearFields() => add(PrintReportClearFields());
  void toggleField(String key, bool selected) => add(PrintReportFieldToggled(key, selected));
  void reorder(int oldIndex, int newIndex) => add(PrintReportFieldsReordered(oldIndex, newIndex));
  void setHeader(String key, String value) => add(PrintReportHeaderChanged(key, value));
  Future<void> printReport({required String schoolName, required String pspCode, required String udiseCode, required PrintSettings settings}) {
    final c = Completer<void>();
    add(PrintReportPrintRequested(schoolName: schoolName, pspCode: pspCode, udiseCode: udiseCode, settings: settings, completer: c));
    return c.future;
  }
}
