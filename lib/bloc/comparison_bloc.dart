import 'dart:async'; // CI validation

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/comparison_repository.dart';
import '../data/repositories/school_repository.dart';
import '../matching/matching_engine.dart';
import '../matching/models.dart';

enum ComparisonStatus { initial, loading, ready, failure }

class ComparisonState extends Equatable {
  final ComparisonStatus status;
  final List<ComparisonRow> rows;
  final List<ComparisonRow> filteredRows;
  final Set<String> classes;
  final Map<MatchType, int> typeCounts;
  final Map<String, int> diffCounts;
  final int pspCount;
  final int matchedPspCount;
  final int mismatchPspCount;
  final int rteCount;
  final int remarkCount;
  final String filter;
  final String classFilter;
  final String sourceFilter;
  final Set<String> statusFilters;
  final Set<String> diffFilters;
  final Set<String> apaarStatusFilters;
  final Set<String> aadhaarStatusFilters;
  final String search;
  final bool searchActive;
  final Map<String, Map<String, dynamic>> remarks;
  final String? error;

  const ComparisonState({
    this.status = ComparisonStatus.initial,
    this.rows = const [],
    this.filteredRows = const [],
    this.classes = const {},
    this.typeCounts = const {},
    this.diffCounts = const {},
    this.pspCount = 0,
    this.matchedPspCount = 0,
    this.mismatchPspCount = 0,
    this.rteCount = 0,
    this.remarkCount = 0,
    this.filter = 'ALL',
    this.classFilter = '',
    this.sourceFilter = 'ALL',
    this.statusFilters = const {},
    this.diffFilters = const {},
    this.apaarStatusFilters = const {},
    this.aadhaarStatusFilters = const {},
    this.search = '',
    this.searchActive = false,
    this.remarks = const {},
    this.error,
  });

  bool hasRemark(ComparisonRow row) {
    final p = (row.psp?.nicId ?? '').trim().toUpperCase();
    final u = (row.udise?.studentCodeNat ?? '').trim().toUpperCase();
    return remarks.containsKey('$p|$u');
  }

  Set<String> get remarkKeys => remarks.keys.toSet();

  int countType(MatchType type) => typeCounts[type] ?? 0;

  int countDiff(String diff) => diffCounts[diff] ?? 0;

  static bool _isRte(ComparisonRow row) {
    final value = row.psp?.raw['Getting Free Education']?.toString().trim().toLowerCase() ?? '';
    return value == 'yes' || value == 'y' || value == 'true' || value == '1';
  }

  static String _apaarStatusKey(UdiseStudent? student) {
    if (student == null) return '__MISSING__';
    final raw = student.raw;
    final desc = raw['apaarIdStatusDesc']?.toString().trim() ?? '';
    final id = raw['apaarId']?.toString().trim() ?? '';
    if (desc.isNotEmpty) return desc.toUpperCase();
    if (id.isNotEmpty) return 'GENERATED';
    return '__MISSING__';
  }
  static String _aadhaarStatusKey(UdiseStudent? student) {
    if (student == null) return '__MISSING__';
    final status = student.raw['uuidStatus']?.toString().trim() ?? '';
    return status.isEmpty ? '__MISSING__' : status;
  }
  static ComparisonState derive({
    required List<ComparisonRow> rows,
    required String filter,
    required String classFilter,
    String sourceFilter = 'ALL',
    Set<String> statusFilters = const {},
    Set<String> diffFilters = const {},
    Set<String> apaarStatusFilters = const {},
    Set<String> aadhaarStatusFilters = const {},
    required String search,
    required bool searchActive,
    required Map<String, Map<String, dynamic>> remarks,
    ComparisonStatus status = ComparisonStatus.ready,
    String? error,
  }) {
    final immutableRows = List<ComparisonRow>.unmodifiable(rows);
    final immutableRemarks = Map<String, Map<String, dynamic>>.unmodifiable(remarks);
    final q = search.trim().toLowerCase();

    bool matches(ComparisonRow row) {
      final hasPsp = row.psp != null;
      final hasUdise = row.udise != null;
      if (sourceFilter == 'PSP' && !hasPsp) return false;
      if (sourceFilter == 'UDISE' && !hasUdise) return false;
      if (sourceFilter == 'PSP_ONLY' && row.type != MatchType.notInUdise) return false;
      if (sourceFilter == 'UDISE_ONLY' && row.type != MatchType.notInPsp) return false;
      if (statusFilters.isNotEmpty) {
        final statusMatch = statusFilters.any((value) {
          switch (value) {
            case 'MATCHED': return row.type == MatchType.matched;
            case 'MISMATCH': return row.type == MatchType.mismatch;
            case 'PSP_ONLY': return row.type == MatchType.notInUdise;
            case 'UDISE_ONLY': return row.type == MatchType.notInPsp;
            case 'REMARKED': return immutableRemarks.containsKey(_remarkKey(row));
            case 'RTE': return _isRte(row);
            default: return false;
          }
        });
        if (!statusMatch) return false;
      }
      if (diffFilters.isNotEmpty && !diffFilters.any((diff) => row.diffs.contains(diff))) return false;
      if (apaarStatusFilters.isNotEmpty && (!hasUdise || !apaarStatusFilters.contains(_apaarStatusKey(row.udise)))) return false;
      if (aadhaarStatusFilters.isNotEmpty && (!hasUdise || !aadhaarStatusFilters.contains(_aadhaarStatusKey(row.udise)))) return false;
      if (classFilter.isNotEmpty) {
        final cls = hasUdise ? (row.udise?.classIdCanon ?? row.udise?.classDescCanon ?? '') : (row.psp?.classCanonValue ?? '');
        if (cls != classFilter) return false;
      }
      if (statusFilters.isEmpty && diffFilters.isEmpty) {
        if (filter == 'REMARKED' && !immutableRemarks.containsKey(_remarkKey(row))) return false;
        if (filter == 'RTE' && !_isRte(row)) return false;
        if (filter == 'MATCHED' && row.type != MatchType.matched) return false;
        if (filter == 'MISMATCH' && row.type != MatchType.mismatch) return false;
        if (filter == 'PSP_ONLY' && row.type != MatchType.notInUdise) return false;
        if (filter == 'UDISE_ONLY' && row.type != MatchType.notInPsp) return false;
        if (filter.startsWith('DIFF:') && !row.diffs.contains(filter.substring(5))) return false;
      }
      if (q.isEmpty) return true;

      final values = <String?>[
        row.psp?.studentName, row.psp?.srNo, row.psp?.nicId,
        row.psp?.fatherName, row.psp?.motherName, row.psp?.mobile,
        row.udise?.studentName, row.udise?.studentCodeNat, row.udise?.studentId,
        row.udise?.fatherName, row.udise?.motherName, row.udise?.mobile,
      ];
      return values.any((value) => (value ?? '').toLowerCase().contains(q));
    }

    final visible = immutableRows.where(matches).toList(growable: false);
    final classSet = <String>{};
    final typeMap = <MatchType, int>{};
    final diffMap = <String, int>{};
    var psp = 0;
    var matched = 0;
    var mismatch = 0;
    var rte = 0;
    var remarked = 0;

    for (final row in immutableRows) {
      final cls = row.psp?.classCanonValue ?? '';
      if (cls.isNotEmpty) classSet.add(cls);
      typeMap[row.type] = (typeMap[row.type] ?? 0) + 1;
      for (final diff in row.diffs) {
        diffMap[diff] = (diffMap[diff] ?? 0) + 1;
      }
      if (row.psp != null) {
        psp++;
        if (row.type == MatchType.matched) matched++;
        if (row.type == MatchType.mismatch) mismatch++;
      }
      if (_isRte(row)) rte++;
      if (immutableRemarks.containsKey(_remarkKey(row))) remarked++;
    }

    return ComparisonState(
      status: status,
      rows: immutableRows,
      filteredRows: List<ComparisonRow>.unmodifiable(visible),
      classes: Set<String>.unmodifiable(classSet),
      typeCounts: Map<MatchType, int>.unmodifiable(typeMap),
      diffCounts: Map<String, int>.unmodifiable(diffMap),
      pspCount: psp,
      matchedPspCount: matched,
      mismatchPspCount: mismatch,
      rteCount: rte,
      remarkCount: remarked,
      filter: filter,
      classFilter: classFilter,
      sourceFilter: sourceFilter,
      statusFilters: Set<String>.unmodifiable(statusFilters),
      diffFilters: Set<String>.unmodifiable(diffFilters),
      apaarStatusFilters: Set<String>.unmodifiable(apaarStatusFilters),
      aadhaarStatusFilters: Set<String>.unmodifiable(aadhaarStatusFilters),
      search: search,
      searchActive: searchActive,
      remarks: immutableRemarks,
      error: error,
    );
  }

  static String _remarkKey(ComparisonRow row) {
    final p = (row.psp?.nicId ?? '').trim().toUpperCase();
    final u = (row.udise?.studentCodeNat ?? '').trim().toUpperCase();
    return '$p|$u';
  }

  ComparisonState copyWith({
    ComparisonStatus? status,
    List<ComparisonRow>? rows,
    List<ComparisonRow>? filteredRows,
    Set<String>? classes,
    Map<MatchType, int>? typeCounts,
    Map<String, int>? diffCounts,
    int? pspCount,
    int? matchedPspCount,
    int? mismatchPspCount,
    int? rteCount,
    int? remarkCount,
    String? filter,
    String? classFilter,
    String? sourceFilter,
    Set<String>? statusFilters,
    Set<String>? diffFilters,
    Set<String>? apaarStatusFilters,
    Set<String>? aadhaarStatusFilters,
    String? search,
    bool? searchActive,
    Map<String, Map<String, dynamic>>? remarks,
    String? error,
    bool clearError = false,
  }) => ComparisonState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    filteredRows: filteredRows ?? this.filteredRows,
    classes: classes ?? this.classes,
    typeCounts: typeCounts ?? this.typeCounts,
    diffCounts: diffCounts ?? this.diffCounts,
    pspCount: pspCount ?? this.pspCount,
    matchedPspCount: matchedPspCount ?? this.matchedPspCount,
    mismatchPspCount: mismatchPspCount ?? this.mismatchPspCount,
    rteCount: rteCount ?? this.rteCount,
    remarkCount: remarkCount ?? this.remarkCount,
    filter: filter ?? this.filter,
    classFilter: classFilter ?? this.classFilter,
    sourceFilter: sourceFilter ?? this.sourceFilter,
    statusFilters: statusFilters ?? this.statusFilters,
    diffFilters: diffFilters ?? this.diffFilters,
    apaarStatusFilters: apaarStatusFilters ?? this.apaarStatusFilters,
    aadhaarStatusFilters: aadhaarStatusFilters ?? this.aadhaarStatusFilters,
    search: search ?? this.search,
    searchActive: searchActive ?? this.searchActive,
    remarks: remarks ?? this.remarks,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status, rows, filteredRows, classes, typeCounts, diffCounts,
    pspCount, matchedPspCount, mismatchPspCount, rteCount, remarkCount,
    filter, classFilter, sourceFilter, statusFilters, diffFilters, apaarStatusFilters, aadhaarStatusFilters, search, searchActive, remarks, error,
  ];
}



List<ComparisonRow> _buildComparisonRowsInBackground(
  Map<String, List<Map<String, dynamic>>> input,
) {
  final psp = (input['psp'] ?? const <Map<String, dynamic>>[])
      .map(PspStudent.fromJson).toList(growable: false);
  final udise = (input['udise'] ?? const <Map<String, dynamic>>[])
      .map(UdiseStudent.fromJson).toList(growable: false);
  return runMatchingEngine(psp, udise);
}

sealed class ComparisonEvent extends Equatable {
  const ComparisonEvent();
  @override List<Object?> get props => [];
}

final class ComparisonLoadRequested extends ComparisonEvent {
  final List<ComparisonRow> initialRows;
  final Completer<void>? completer;
  const ComparisonLoadRequested({this.initialRows = const [], this.completer});
  @override List<Object?> get props => [initialRows];
}

final class ComparisonFilterChanged extends ComparisonEvent {
  final String value;
  const ComparisonFilterChanged(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonDiffFilterToggled extends ComparisonEvent {
  final String diff;
  const ComparisonDiffFilterToggled(this.diff);
  @override List<Object?> get props => [diff];
}
final class ComparisonClassFilterChanged extends ComparisonEvent {
  final String value;
  const ComparisonClassFilterChanged(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonSourceFilterChanged extends ComparisonEvent {
  final String value;
  const ComparisonSourceFilterChanged(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonStatusFilterToggled extends ComparisonEvent {
  final String value;
  const ComparisonStatusFilterToggled(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonDiffFiltersChanged extends ComparisonEvent {
  final Set<String> values;
  const ComparisonDiffFiltersChanged(this.values);
  @override List<Object?> get props => [values];
}
final class ComparisonApaarStatusFilterToggled extends ComparisonEvent {
  final String value;
  const ComparisonApaarStatusFilterToggled(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonAadhaarStatusFilterToggled extends ComparisonEvent {
  final String value;
  const ComparisonAadhaarStatusFilterToggled(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonSearchChanged extends ComparisonEvent {
  final String value;
  const ComparisonSearchChanged(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonErrorChanged extends ComparisonEvent {
  final String message;
  const ComparisonErrorChanged(this.message);
  @override List<Object?> get props => [message];
}

final class ComparisonSearchActivityChanged extends ComparisonEvent {
  final bool value;
  const ComparisonSearchActivityChanged(this.value);
  @override List<Object?> get props => [value];
}
final class ComparisonJsonImportRequested extends ComparisonEvent {
  final bool psp;
  final List<Map<String, dynamic>> rows;
  final Completer<void> completer;
  const ComparisonJsonImportRequested({required this.psp, required this.rows, required this.completer});
  @override List<Object?> get props => [psp, rows];
}
final class ComparisonLegacyRemarksImportRequested extends ComparisonEvent {
  final List<int> bytes;
  final Completer<int> completer;
  const ComparisonLegacyRemarksImportRequested({required this.bytes, required this.completer});
  @override List<Object?> get props => [bytes];
}
final class ComparisonSourceRowsRequested extends ComparisonEvent {
  final bool psp;
  final Completer<List<Map<String, dynamic>>> completer;
  const ComparisonSourceRowsRequested({required this.psp, required this.completer});
  @override List<Object?> get props => [psp];
}
final class ComparisonRemarkSaved extends ComparisonEvent {
  final ComparisonRow row;
  final String remark;
  final Completer<void> completer;
  const ComparisonRemarkSaved({required this.row, required this.remark, required this.completer});
  @override List<Object?> get props => [row, remark];
}
final class ComparisonRemarkDeleted extends ComparisonEvent {
  final ComparisonRow row;
  final Completer<void> completer;
  const ComparisonRemarkDeleted({required this.row, required this.completer});
  @override List<Object?> get props => [row];
}

class ComparisonBloc extends Bloc<ComparisonEvent, ComparisonState> {
  final ComparisonRepository _repository;
  final SchoolRepository _schoolRepository;
  int _loadGeneration = 0;

  ComparisonBloc({required ComparisonRepository repository, required SchoolRepository schoolRepository})
      : _repository = repository, _schoolRepository = schoolRepository, super(const ComparisonState()) {
    on<ComparisonLoadRequested>(_onLoad);
    on<ComparisonFilterChanged>(_onFilter);
    on<ComparisonDiffFilterToggled>(_onDiffFilter);
    on<ComparisonClassFilterChanged>(_onClassFilter);
    on<ComparisonSourceFilterChanged>(_onSourceFilter);
    on<ComparisonStatusFilterToggled>(_onStatusFilterToggle);
    on<ComparisonDiffFiltersChanged>(_onDiffFiltersChanged);
    on<ComparisonApaarStatusFilterToggled>(_onApaarStatusToggle);
    on<ComparisonAadhaarStatusFilterToggled>(_onAadhaarStatusToggle);
    on<ComparisonSearchChanged>(_onSearch);
    on<ComparisonSearchActivityChanged>(
      (e, emit) => emit(state.copyWith(searchActive: e.value)),
    );
    on<ComparisonErrorChanged>((e, emit) => emit(state.copyWith(status: ComparisonStatus.failure, error: e.message)));
    on<ComparisonJsonImportRequested>(_onJsonImport);
    on<ComparisonLegacyRemarksImportRequested>(_onLegacyRemarksImport);
    on<ComparisonSourceRowsRequested>(_onSourceRows);
    on<ComparisonRemarkSaved>(_onRemarkSaved);
    on<ComparisonRemarkDeleted>(_onRemarkDeleted);
  }

  Future<void> _onLoad(ComparisonLoadRequested event, Emitter<ComparisonState> emit) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(
      status: ComparisonStatus.loading,
      rows: event.initialRows.isEmpty ? state.rows : List<ComparisonRow>.unmodifiable(event.initialRows),
      clearError: true,
    ));
    try {
      final pspRows = await _repository.loadPspRows();
      final udiseRows = await _repository.loadUdiseRows();
      final rows = await compute(_buildComparisonRowsInBackground, <String, List<Map<String, dynamic>>>{'psp': pspRows, 'udise': udiseRows});
      if (generation != _loadGeneration || emit.isDone) {
        // A newer load superseded this request. Never leave a caller awaiting
        // load() forever just because its result became stale.
        if (event.completer != null && !event.completer!.isCompleted) {
          event.completer!.complete();
        }
        return;
      }

      final source = await _repository.getAllRemarks();
      final remarks = <String, Map<String, dynamic>>{};
      for (final row in source) {
        final p = row['psp_nic']?.toString().trim().toUpperCase() ?? '';
        final u = row['udise_pen']?.toString().trim().toUpperCase() ?? '';
        if (p.isNotEmpty || u.isNotEmpty) remarks['$p|$u'] = Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row));
      }
      final readyState = ComparisonState.derive(
        rows: rows,
        filter: state.filter,
        classFilter: state.classFilter,
        sourceFilter: state.sourceFilter,
        statusFilters: state.statusFilters,
        diffFilters: state.diffFilters,
        apaarStatusFilters: state.apaarStatusFilters,
        aadhaarStatusFilters: state.aadhaarStatusFilters,
        search: state.search,
        searchActive: state.searchActive,
        remarks: remarks,
        status: ComparisonStatus.ready,
      );
      emit(readyState);
      event.completer?.complete();
    } catch (e, st) {
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.completeError(e, st);
      if (generation == _loadGeneration && !emit.isDone) emit(state.copyWith(status: ComparisonStatus.failure, error: 'Unable to load saved data: $e'));
    }
  }

  ComparisonState _derive({
    String? filter,
    String? classFilter,
    String? sourceFilter,
    Set<String>? statusFilters,
    Set<String>? diffFilters,
    Set<String>? apaarStatusFilters,
    Set<String>? aadhaarStatusFilters,
    String? search,
    Map<String, Map<String, dynamic>>? remarks,
    String? error,
    bool clearError = false,
  }) {
    return ComparisonState.derive(
      rows: state.rows,
      filter: filter ?? state.filter,
      classFilter: classFilter ?? state.classFilter,
      sourceFilter: sourceFilter ?? state.sourceFilter,
      statusFilters: statusFilters ?? state.statusFilters,
      diffFilters: diffFilters ?? state.diffFilters,
      apaarStatusFilters: apaarStatusFilters ?? state.apaarStatusFilters,
      aadhaarStatusFilters: aadhaarStatusFilters ?? state.aadhaarStatusFilters,
      search: search ?? state.search,
      searchActive: state.searchActive,
      remarks: remarks ?? state.remarks,
      status: state.status,
      error: clearError ? null : (error ?? state.error),
    );
  }

  void _onFilter(
    ComparisonFilterChanged event,
    Emitter<ComparisonState> emit,
  ) {
    if (event.value == state.filter) return;
    emit(_derive(filter: event.value));
  }

  void _onDiffFilter(
    ComparisonDiffFilterToggled event,
    Emitter<ComparisonState> emit,
  ) {
    final next = state.filter == 'DIFF:${event.diff}'
        ? 'ALL'
        : 'DIFF:${event.diff}';
    emit(_derive(filter: next));
  }

  void _onClassFilter(
    ComparisonClassFilterChanged event,
    Emitter<ComparisonState> emit,
  ) {
    if (event.value == state.classFilter) return;
    emit(_derive(classFilter: event.value));
  }

  void _onSourceFilter(ComparisonSourceFilterChanged event, Emitter<ComparisonState> emit) => emit(_derive(sourceFilter: event.value));
  void _onStatusFilterToggle(ComparisonStatusFilterToggled event, Emitter<ComparisonState> emit) {
    // MATCHED and MISMATCH are mutually exclusive.
    // Tapping the active status clears it; selecting the other replaces it.
    final next = state.statusFilters.contains(event.value)
        ? <String>{}
        : <String>{event.value};
    emit(_derive(statusFilters: next, filter: 'ALL'));
  }
  void _onDiffFiltersChanged(ComparisonDiffFiltersChanged event, Emitter<ComparisonState> emit) => emit(_derive(diffFilters: event.values, filter: 'ALL'));
  void _onApaarStatusToggle(ComparisonApaarStatusFilterToggled event, Emitter<ComparisonState> emit) {
    // APAAR is a single-select filter: tap the active value to clear it,
    // otherwise replace the previous value with the newly selected value.
    final next = state.apaarStatusFilters.contains(event.value)
        ? <String>{}
        : <String>{event.value};
    emit(_derive(apaarStatusFilters: next));
  }

  void _onAadhaarStatusToggle(ComparisonAadhaarStatusFilterToggled event, Emitter<ComparisonState> emit) {
    // Aadhaar is a single-select filter: tap the active value to clear it,
    // otherwise replace the previous value with the newly selected value.
    final next = state.aadhaarStatusFilters.contains(event.value)
        ? <String>{}
        : <String>{event.value};
    emit(_derive(aadhaarStatusFilters: next));
  }
  void _onSearch(
    ComparisonSearchChanged event,
    Emitter<ComparisonState> emit,
  ) {
    if (event.value == state.search) return;
    emit(_derive(search: event.value));
  }

  Future<void> _onJsonImport(ComparisonJsonImportRequested event, Emitter<ComparisonState> emit) async {
    try {
      if (event.psp) {
        await _repository.replacePspRows(event.rows);
      } else {
        await _repository.replaceUdiseRows(event.rows);
      }
      if (!event.completer.isCompleted) event.completer.complete();
      add(const ComparisonLoadRequested());
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(status: ComparisonStatus.failure, error: 'JSON import failed: $e'));
    }
  }

  Future<void> _onLegacyRemarksImport(ComparisonLegacyRemarksImportRequested event, Emitter<ComparisonState> emit) async {
    try {
      final result = await _repository.importLegacyRemarks(event.bytes);
      if (!event.completer.isCompleted) event.completer.complete(result);
      add(const ComparisonLoadRequested());
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(status: ComparisonStatus.failure, error: 'Legacy remarks import failed: $e'));
    }
  }

  Future<void> _onSourceRows(ComparisonSourceRowsRequested event, Emitter<ComparisonState> emit) async {
    try {
      final rows = event.psp ? await _repository.loadPspRows() : await _repository.loadUdiseRows();
      if (!event.completer.isCompleted) event.completer.complete(rows);
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
    }
  }

  Future<void> _onRemarkSaved(ComparisonRemarkSaved event, Emitter<ComparisonState> emit) async {
    try {
      if (event.remark.trim().isEmpty) {
        await _repository.deleteRemark(pspNic: event.row.psp?.nicId, udisePen: event.row.udise?.studentCodeNat);
      } else {
        await _repository.saveRemark(remark: event.remark.trim(), pspNic: event.row.psp?.nicId, udisePen: event.row.udise?.studentCodeNat);
      }
      await _refreshRemarks(emit);
      if (!event.completer.isCompleted) event.completer.complete();
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(error: 'Remark update failed: $e'));
    }
  }

  Future<void> _onRemarkDeleted(ComparisonRemarkDeleted event, Emitter<ComparisonState> emit) async {
    try {
      await _repository.deleteRemark(pspNic: event.row.psp?.nicId, udisePen: event.row.udise?.studentCodeNat);
      await _refreshRemarks(emit);
      if (!event.completer.isCompleted) event.completer.complete();
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(error: 'Remark deletion failed: $e'));
    }
  }

  Future<void> _refreshRemarks(Emitter<ComparisonState> emit) async {
    final source = await _repository.getAllRemarks();
    final remarks = <String, Map<String, dynamic>>{};
    for (final row in source) {
      final p = row['psp_nic']?.toString().trim().toUpperCase() ?? '';
      final u = row['udise_pen']?.toString().trim().toUpperCase() ?? '';
      if (p.isNotEmpty || u.isNotEmpty) remarks['$p|$u'] = Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row));
    }
    emit(_derive(remarks: remarks));
  }

  Future<Map<String, dynamic>?> getActiveSchoolProfile() => _schoolRepository.getActiveProfile();

  Future<void> load({List<ComparisonRow> initialRows = const []}) {
    final c = Completer<void>(); add(ComparisonLoadRequested(initialRows: initialRows, completer: c)); return c.future;
  }
  void setSourceFilter(String value) => add(ComparisonSourceFilterChanged(value));
  void toggleStatusFilter(String value) => add(ComparisonStatusFilterToggled(value));
  void setDiffFilters(Set<String> values) => add(ComparisonDiffFiltersChanged(values));
  void toggleApaarStatusFilter(String value) => add(ComparisonApaarStatusFilterToggled(value));
  void toggleAadhaarStatusFilter(String value) => add(ComparisonAadhaarStatusFilterToggled(value));
  Set<String> get apaarStatusOptions => state.rows.where((r) => r.udise != null).map((r) => ComparisonState._apaarStatusKey(r.udise)).toSet();
  Set<String> get aadhaarStatusOptions => state.rows.where((r) => r.udise != null).map((r) => ComparisonState._aadhaarStatusKey(r.udise)).toSet();
  String apaarStatusLabel(String key) => key == '__MISSING__' ? 'Not Available' : key == 'GENERATED' ? 'Generated' : key;
  String aadhaarStatusLabel(String key) { switch (key) { case '1': return 'Verified'; case '2': return 'Verification Failed'; case '0': return 'Not Verified'; default: return 'Not Available'; } }

  void setFilter(String value) => add(ComparisonFilterChanged(value));
  void toggleDiffFilter(String diff) => add(ComparisonDiffFilterToggled(diff));
  void setClassFilter(String value) => add(ComparisonClassFilterChanged(value));
  void setSearch(String value) => add(ComparisonSearchChanged(value));
  void setSearchActive(bool value) => add(ComparisonSearchActivityChanged(value));
  void setError(String message) => add(ComparisonErrorChanged(message));
  Future<void> importJsonRows({required bool psp, required List<Map<String, dynamic>> rows}) {
    final c = Completer<void>(); add(ComparisonJsonImportRequested(psp: psp, rows: rows, completer: c)); return c.future;
  }
  Future<int> importLegacyRemarks(List<int> bytes) {
    final c = Completer<int>(); add(ComparisonLegacyRemarksImportRequested(bytes: bytes, completer: c)); return c.future;
  }
  Future<List<Map<String, dynamic>>> loadSourceRows({required bool psp}) {
    final c = Completer<List<Map<String, dynamic>>>(); add(ComparisonSourceRowsRequested(psp: psp, completer: c)); return c.future;
  }
  Future<void> saveRemark({required ComparisonRow row, required String remark}) {
    final c = Completer<void>(); add(ComparisonRemarkSaved(row: row, remark: remark, completer: c)); return c.future;
  }
  Future<void> deleteRemark(ComparisonRow row) {
    final c = Completer<void>(); add(ComparisonRemarkDeleted(row: row, completer: c)); return c.future;
  }
}
