import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../database/database.dart';
import '../matching/matching_engine.dart';
import '../matching/models.dart';

enum ComparisonStatus { initial, loading, ready, failure }

class ComparisonState {
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
    return remarks.containsKey('$p|$u');
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

  int countType(MatchType type) =>
      rows.where((row) => row.type == type).length;

  int countDiff(String diff) =>
      rows.where((row) => row.diffs.contains(diff)).length;

  int get pspCount => rows.where((row) => row.psp != null).length;
  int get matchedPspCount =>
      rows.where((row) => row.psp != null && row.type == MatchType.matched).length;
  int get mismatchPspCount =>
      rows.where((row) => row.psp != null && row.type == MatchType.mismatch).length;
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
  }) {
    return ComparisonState(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      filter: filter ?? this.filter,
      classFilter: classFilter ?? this.classFilter,
      search: search ?? this.search,
      searchActive: searchActive ?? this.searchActive,
      remarks: remarks ?? this.remarks,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ComparisonCubit extends Cubit<ComparisonState> {
  final AppDatabase database;

  ComparisonCubit({AppDatabase? database})
      : database = database ?? AppDatabase.instance,
        super(const ComparisonState());

  Future<void> load({List<ComparisonRow> initialRows = const []}) async {
    if (initialRows.isNotEmpty) {
      emit(state.copyWith(
        status: ComparisonStatus.loading,
        rows: List<ComparisonRow>.from(initialRows),
        clearError: true,
      ));
    } else {
      emit(state.copyWith(status: ComparisonStatus.loading, clearError: true));
    }
    try {
      final pspRows = await database.loadPspRows();
      final udiseRows = await database.loadUdiseRows();
      final rows = runMatchingEngine(
        pspRows.map(PspStudent.fromJson).toList(),
        udiseRows.map(UdiseStudent.fromJson).toList(),
      );
      if (isClosed) return;
      emit(state.copyWith(status: ComparisonStatus.ready, rows: rows));
      await loadRemarks();
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: ComparisonStatus.failure,
        error: 'Unable to load saved data: $e',
      ));
    }
  }

  Future<void> loadRemarks() async {
    try {
      final source = await database.getAllRemarks();
      final remarks = <String, Map<String, dynamic>>{};
      for (final row in source) {
        final p = row['psp_nic']?.toString().trim().toUpperCase() ?? '';
        final u = row['udise_pen']?.toString().trim().toUpperCase() ?? '';
        if (p.isNotEmpty || u.isNotEmpty) remarks['$p|$u'] = Map<String, dynamic>.from(row);
      }
      if (!isClosed) emit(state.copyWith(remarks: remarks));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: 'Unable to load remarks: $e'));
    }
  }


  Future<Map<String, dynamic>?> getActiveSchoolProfile() =>
      database.getActiveSchoolProfile();

  Future<void> importJsonRows({
    required bool psp,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (psp) {
      await database.replacePspRows(rows);
    } else {
      await database.replaceUdiseRows(rows);
    }
    await load();
  }

  Future<({int pspCount, int udiseCount, int remarkCount})> importSqlite(
    List<int> bytes,
  ) async {
    final result = await database.importSqliteBytes(bytes);
    await load();
    return (
      pspCount: result.pspCount,
      udiseCount: result.udiseCount,
      remarkCount: result.remarkCount,
    );
  }

  Future<int> importLegacyRemarks(List<int> bytes) async {
    final imported = await database.importLegacyRemarksBytes(bytes);
    await loadRemarks();
    return imported;
  }

  Future<Uint8List> exportDatabase() => database.exportDatabaseBytes();

  Future<List<Map<String, dynamic>>> loadSourceRows({required bool psp}) =>
      psp ? database.loadPspRows() : database.loadUdiseRows();

  Future<void> refresh() => load();

  void setFilter(String value) {
    if (!isClosed) emit(state.copyWith(filter: value));
  }
  void toggleDiffFilter(String diff) {
    setFilter(state.filter == 'DIFF:$diff' ? 'ALL' : 'DIFF:$diff');
  }
  void setClassFilter(String value) {
    if (!isClosed) emit(state.copyWith(classFilter: value));
  }
  void setSearch(String value) {
    if (!isClosed) emit(state.copyWith(search: value));
  }
  void setSearchActive(bool value) {
    if (!isClosed) emit(state.copyWith(searchActive: value));
  }
  void setError(String message) {
    if (!isClosed) emit(state.copyWith(status: ComparisonStatus.failure, error: message));
  }

  Future<void> saveRemark({
    required ComparisonRow row,
    required String remark,
  }) async {
    if (remark.trim().isEmpty) {
      await database.deleteRemark(
        pspNic: row.psp?.nicId,
        udisePen: row.udise?.studentCodeNat,
      );
    } else {
      await database.saveRemark(
        remark: remark.trim(),
        pspNic: row.psp?.nicId,
        udisePen: row.udise?.studentCodeNat,
      );
    }
    await loadRemarks();
  }

  Future<void> deleteRemark(ComparisonRow row) async {
    await database.deleteRemark(
      pspNic: row.psp?.nicId,
      udisePen: row.udise?.studentCodeNat,
    );
    await loadRemarks();
  }
}
