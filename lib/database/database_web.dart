import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

class SqliteImportResult {
  final int pspCount;
  final int udiseCount;
  final int remarkCount;
  final List<String> sourceTables;

  const SqliteImportResult({
    required this.pspCount,
    required this.udiseCount,
    required this.remarkCount,
    required this.sourceTables,
  });
}

/// Browser implementation. Sembast Web persists data in IndexedDB, on the
/// current browser/device. It never uploads student data to GitHub or a server.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String _dbName = 'student_comparison_browser_v1';

  static final StoreRef<int, Map<String, Object?>> _pspStore =
      intMapStoreFactory.store('psp_students');
  static final StoreRef<int, Map<String, Object?>> _udiseStore =
      intMapStoreFactory.store('udise_students');
  static final StoreRef<String, Map<String, Object?>> _remarksStore =
      stringMapStoreFactory.store('student_remarks');

  Database? _db;

  Future<Database> get database async {
    return _db ??= await databaseFactoryWeb.openDatabase(_dbName);
  }

  Future<void> replacePspRows(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final nic = _text(row['Student NIC ID']);
      if (nic.isNotEmpty) uniqueRows[nic] = row;
    }
    await db.transaction((txn) async {
      await _pspStore.delete(txn);
      for (final row in uniqueRows.values) {
        await _pspStore.add(txn, <String, Object?>{
          'raw_json': jsonEncode(row),
        });
      }
    });
  }

  Future<void> replaceUdiseRows(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final studentId = _text(row['studentId']);
      if (studentId.isEmpty) continue;
      final pen = _text(row['studentCodeNat']);
      final key = pen.isEmpty ? '__NO_PEN__:$studentId' : pen;
      uniqueRows[key] = row;
    }
    await db.transaction((txn) async {
      await _udiseStore.delete(txn);
      for (final row in uniqueRows.values) {
        await _udiseStore.add(txn, <String, Object?>{
          'raw_json': jsonEncode(row),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadPspRows() async =>
      _loadRows(await database, _pspStore);

  Future<List<Map<String, dynamic>>> loadUdiseRows() async =>
      _loadRows(await database, _udiseStore);

  Future<List<Map<String, dynamic>>> _loadRows(
    Database db,
    StoreRef<int, Map<String, Object?>> store,
  ) async {
    final records = await store.find(db);
    final rows = <Map<String, dynamic>>[];
    for (final record in records) {
      final raw = record.value['raw_json']?.toString() ?? '';
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) rows.add(Map<String, dynamic>.from(decoded));
      } on FormatException {
        // Ignore only the damaged browser record; other records remain usable.
      }
    }
    return rows;
  }

  Future<Uint8List> exportDatabaseBytes() async {
    throw UnsupportedError(
      'SQLite file export is available in the Android app. '
      'On the web, export PSP/UDISE JSON or comparison CSV instead.',
    );
  }

  Future<SqliteImportResult> importSqliteBytes(List<int> bytes) async {
    throw UnsupportedError(
      'Import the PSP and UDISE JSON files in the web app. '
      'SQLite database-file import is available in the Android app.',
    );
  }

  String _remarkKey(String pspNic, String udisePen) =>
      jsonEncode([pspNic.trim().toUpperCase(), udisePen.trim().toUpperCase()]);

  Future<Map<String, dynamic>?> getRemark({
    String? pspNic,
    String? udisePen,
  }) async {
    final db = await database;
    final value = await _remarksStore
        .record(_remarkKey(pspNic ?? '', udisePen ?? ''))
        .get(db);
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<void> saveRemark({
    required String remark,
    String? pspNic,
    String? udisePen,
  }) async {
    final psp = pspNic ?? '';
    final pen = udisePen ?? '';
    if (psp.isEmpty && pen.isEmpty) {
      throw ArgumentError('At least one of pspNic or udisePen is required.');
    }

    final db = await database;
    final record = _remarksStore.record(_remarkKey(psp, pen));
    final previous = await record.get(db);
    final now = DateTime.now().toIso8601String();
    await record.put(db, <String, Object?>{
      'psp_nic': psp,
      'udise_pen': pen,
      'remark': remark,
      'created_at': previous?['created_at']?.toString() ?? now,
      'updated_at': now,
    });
  }

  Future<void> deleteRemark({
    String? pspNic,
    String? udisePen,
  }) async {
    final db = await database;
    await _remarksStore
        .record(_remarkKey(pspNic ?? '', udisePen ?? ''))
        .delete(db);
  }

  Future<List<Map<String, dynamic>>> getAllRemarks() async {
    final db = await database;
    final records = await _remarksStore.find(db);
    return records
        .map((record) => Map<String, dynamic>.from(record.value))
        .toList();
  }

  Future<int> pspCount() async => (await loadPspRows()).length;

  Future<int> udiseCount() async => (await loadUdiseRows()).length;

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}
