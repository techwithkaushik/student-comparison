import 'dart:typed_data';

import '../../database/database.dart';

class ComparisonRepository {
  final AppDatabase _database;

  ComparisonRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  Future<List<Map<String, dynamic>>> loadPspRows() =>
      _database.loadPspRows();

  Future<List<Map<String, dynamic>>> loadUdiseRows() =>
      _database.loadUdiseRows();

  Future<void> replacePspRows(List<Map<String, dynamic>> rows) =>
      _database.replacePspRows(rows);

  Future<void> replaceUdiseRows(List<Map<String, dynamic>> rows) =>
      _database.replaceUdiseRows(rows);

  Future<({int pspCount, int udiseCount, int remarkCount})> importSqlite(
    List<int> bytes,
  ) async {
    final result = await _database.importSqliteBytes(bytes);
    return (
      pspCount: result.pspCount,
      udiseCount: result.udiseCount,
      remarkCount: result.remarkCount,
    );
  }

  Future<int> importLegacyRemarks(List<int> bytes) =>
      _database.importLegacyRemarksBytes(bytes);

  Future<Uint8List> exportDatabase() => _database.exportDatabaseBytes();

  Future<List<Map<String, dynamic>>> getAllRemarks() =>
      _database.getAllRemarks();

  Future<void> saveRemark({
    required String remark,
    String? pspNic,
    String? udisePen,
  }) =>
      _database.saveRemark(
        remark: remark,
        pspNic: pspNic,
        udisePen: udisePen,
      );

  Future<void> deleteRemark({
    String? pspNic,
    String? udisePen,
  }) =>
      _database.deleteRemark(
        pspNic: pspNic,
        udisePen: udisePen,
      );
}
