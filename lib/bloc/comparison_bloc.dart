import 'dart:async';
import 'dart:typed_data';

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
  final String filter;
  final String classFilter;
  final String search;
  final bool searchActive;
  final Map<String, Map<String, dynamic>> remarks;
  final String? error;

  const ComparisonState({
    this.status = ComparisonStatus.initial,
    this.rows = const [],
    this.filter = 'ALL',
    this.classFilter = '',
    this.search = '',
    this.searchActive = false,
    this.remarks = const {},
    this.error,
  });

  Set<String> get remarkKeys => remarks.keys.toSet();

  bool hasRemark(ComparisonRow row) {
    final p = (row.psp?.nicId ?? '').trim().toUpperCase();
    final u = (row.udise?.studentCodeNat ?? '').trim().toUpperCase();
    return remarks.containsKey('\$p|\$u');
  }

  List<ComparisonRow> get filteredRows {
    final q = search.trim().toLowerCase();
    return rows.where((row) {
      if (filter == 'REMARKED' && !hasRemark(row)) return false;
      if (filter == 'RTE' && !_isRte(row)) return false;
      if (filter == 'MATCHED' && row.type != MatchType.matched) return false;
      if (filter == 'MISMATCH' && row.type != MatchType.mismatch) return false;
      if (filter == 'PSP_ONLY' && row.type != MatchType.notInUdise) return false;
      if (filter == 'UDISE_ONLY' && row.type != MatchType.notInPsp) return false;
      if (filter.startsWith('DIFF:') &&
          !row.diffs.contains(filter.substring(5))) {
        return false;
      }
      if (classFilter.isNotEmpty &&
          (row.psp?.classCanonValue ?? '') != classFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        final values = [
          row.psp?.studentName,
          row.psp?.srNo,
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
        if (!values.any((v) => (v ?? '').toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  Set<String> get classes => rows
      .map((row) => row.psp?.classCanonValue ?? '')
      .where((value) => value.isNotEmpty)
      .toSet();

  int countType(MatchType type) => rows.where((row) => row.type == type).length;
  int countDiff(String diff) => rows.where((row) => row.diffs.contains(diff)).length;
  int get pspCount => rows.where((row) => row.psp != null).length;
  int get matchedPspCount => rows.where((row) => row.psp != null && row.type == MatchType.matched).length;
  int get mismatchPspCount => rows.where((row) => row.psp != null && row.type == MatchType.mismatch).length;
  int get rteCount => rows.where(_isRte).length;
  int get remarkCount => rows.where(hasRemark).length;

  static bool _isRte(ComparisonRow row) {
    final value = row.psp?.raw['Getting Free Education']?.toString().trim().toLowerCase() ?? '';
    return value == 'yes' || value == 'y' || value == 'true' || value == '1';
  }

  ComparisonState copyWith({
    ComparisonStatus? status,
    List<ComparisonRow>? rows,
    String? filter,
    String? classFilter,
    String? search,
    bool? searchActive,
    Map<String, Map<String, dynamic>>? remarks,
    String? error,
    bool clearError = false,
  }) => ComparisonState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    filter: filter ?? this.filter,
    classFilter: classFilter ?? this.classFilter,
    search: search ?? this.search,
    searchActive: searchActive ?? this.searchActive,
    remarks: remarks ?? this.remarks,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [status, rows, filter, classFilter, search, searchActive, remarks, error];
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
final class ComparisonSqliteImportRequested extends ComparisonEvent {
  final List<int> bytes;
  final Completer<({int pspCount, int udiseCount, int remarkCount})> completer;
  const ComparisonSqliteImportRequested({required this.bytes, required this.completer});
  @override List<Object?> get props => [bytes];
}
final class ComparisonLegacyRemarksImportRequested extends ComparisonEvent {
  final List<int> bytes;
  final Completer<int> completer;
  const ComparisonLegacyRemarksImportRequested({required this.bytes, required this.completer});
  @override List<Object?> get props => [bytes];
}
final class ComparisonDatabaseExportRequested extends ComparisonEvent {
  final Completer<Uint8List> completer;
  const ComparisonDatabaseExportRequested(this.completer);
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
    on<ComparisonFilterChanged>((e, emit) => emit(state.copyWith(filter: e.value)));
    on<ComparisonDiffFilterToggled>(_onDiffFilter);
    on<ComparisonClassFilterChanged>((e, emit) => emit(state.copyWith(classFilter: e.value)));
    on<ComparisonSearchChanged>((e, emit) => emit(state.copyWith(search: e.value)));
    on<ComparisonSearchActivityChanged>((e, emit) => emit(state.copyWith(searchActive: e.value)));
    on<ComparisonErrorChanged>((e, emit) => emit(state.copyWith(status: ComparisonStatus.failure, error: e.message)));
    on<ComparisonJsonImportRequested>(_onJsonImport);
    on<ComparisonSqliteImportRequested>(_onSqliteImport);
    on<ComparisonLegacyRemarksImportRequested>(_onLegacyRemarksImport);
    on<ComparisonDatabaseExportRequested>(_onDatabaseExport);
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
      if (generation != _loadGeneration || emit.isDone) return;

      final source = await _repository.getAllRemarks();
      final remarks = <String, Map<String, dynamic>>{};
      for (final row in source) {
        final p = row['psp_nic']?.toString().trim().toUpperCase() ?? '';
        final u = row['udise_pen']?.toString().trim().toUpperCase() ?? '';
        if (p.isNotEmpty || u.isNotEmpty) remarks['\$p|\$u'] = Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row));
      }
      emit(state.copyWith(status: ComparisonStatus.ready, rows: List<ComparisonRow>.unmodifiable(rows), remarks: Map<String, Map<String, dynamic>>.unmodifiable(remarks)));
      event.completer?.complete();
    } catch (e, st) {
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.completeError(e, st);
      if (generation == _loadGeneration && !emit.isDone) emit(state.copyWith(status: ComparisonStatus.failure, error: 'Unable to load saved data: \$e'));
    }
  }

  void _onDiffFilter(ComparisonDiffFilterToggled event, Emitter<ComparisonState> emit) {
    emit(state.copyWith(filter: state.filter == 'DIFF:\${event.diff}' ? 'ALL' : 'DIFF:\${event.diff}'));
  }

  Future<void> _onJsonImport(ComparisonJsonImportRequested event, Emitter<ComparisonState> emit) async {
    try {
      if (event.psp) await _repository.replacePspRows(event.rows); else await _repository.replaceUdiseRows(event.rows);
      if (!event.completer.isCompleted) event.completer.complete();
      add(const ComparisonLoadRequested());
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(status: ComparisonStatus.failure, error: 'JSON import failed: \$e'));
    }
  }

  Future<void> _onSqliteImport(ComparisonSqliteImportRequested event, Emitter<ComparisonState> emit) async {
    try {
      final result = await _repository.importSqlite(event.bytes);
      if (!event.completer.isCompleted) event.completer.complete(result);
      add(const ComparisonLoadRequested());
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(status: ComparisonStatus.failure, error: 'SQLite import failed: \$e'));
    }
  }

  Future<void> _onLegacyRemarksImport(ComparisonLegacyRemarksImportRequested event, Emitter<ComparisonState> emit) async {
    try {
      final result = await _repository.importLegacyRemarks(event.bytes);
      if (!event.completer.isCompleted) event.completer.complete(result);
      add(const ComparisonLoadRequested());
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(status: ComparisonStatus.failure, error: 'Legacy remarks import failed: \$e'));
    }
  }

  Future<void> _onDatabaseExport(ComparisonDatabaseExportRequested event, Emitter<ComparisonState> emit) async {
    try {
      if (!event.completer.isCompleted) event.completer.complete(await _repository.exportDatabase());
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
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
      emit(state.copyWith(error: 'Remark update failed: \$e'));
    }
  }

  Future<void> _onRemarkDeleted(ComparisonRemarkDeleted event, Emitter<ComparisonState> emit) async {
    try {
      await _repository.deleteRemark(pspNic: event.row.psp?.nicId, udisePen: event.row.udise?.studentCodeNat);
      await _refreshRemarks(emit);
      if (!event.completer.isCompleted) event.completer.complete();
    } catch (e, st) {
      if (!event.completer.isCompleted) event.completer.completeError(e, st);
      emit(state.copyWith(error: 'Remark deletion failed: \$e'));
    }
  }

  Future<void> _refreshRemarks(Emitter<ComparisonState> emit) async {
    final source = await _repository.getAllRemarks();
    final remarks = <String, Map<String, dynamic>>{};
    for (final row in source) {
      final p = row['psp_nic']?.toString().trim().toUpperCase() ?? '';
      final u = row['udise_pen']?.toString().trim().toUpperCase() ?? '';
      if (p.isNotEmpty || u.isNotEmpty) remarks['\$p|\$u'] = Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row));
    }
    emit(state.copyWith(remarks: Map<String, Map<String, dynamic>>.unmodifiable(remarks)));
  }

  Future<Map<String, dynamic>?> getActiveSchoolProfile() => _schoolRepository.getActiveProfile();

  Future<void> load({List<ComparisonRow> initialRows = const []}) {
    final c = Completer<void>(); add(ComparisonLoadRequested(initialRows: initialRows, completer: c)); return c.future;
  }
  void setFilter(String value) => add(ComparisonFilterChanged(value));
  void toggleDiffFilter(String diff) => add(ComparisonDiffFilterToggled(diff));
  void setClassFilter(String value) => add(ComparisonClassFilterChanged(value));
  void setSearch(String value) => add(ComparisonSearchChanged(value));
  void setSearchActive(bool value) => add(ComparisonSearchActivityChanged(value));
  void setError(String message) => add(ComparisonErrorChanged(message));
  Future<void> importJsonRows({required bool psp, required List<Map<String, dynamic>> rows}) {
    final c = Completer<void>(); add(ComparisonJsonImportRequested(psp: psp, rows: rows, completer: c)); return c.future;
  }
  Future<({int pspCount, int udiseCount, int remarkCount})> importSqlite(List<int> bytes) {
    final c = Completer<({int pspCount, int udiseCount, int remarkCount})>(); add(ComparisonSqliteImportRequested(bytes: bytes, completer: c)); return c.future;
  }
  Future<int> importLegacyRemarks(List<int> bytes) {
    final c = Completer<int>(); add(ComparisonLegacyRemarksImportRequested(bytes: bytes, completer: c)); return c.future;
  }
  Future<Uint8List> exportDatabase() {
    final c = Completer<Uint8List>(); add(ComparisonDatabaseExportRequested(c)); return c.future;
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
