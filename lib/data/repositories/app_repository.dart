import 'dart:typed_data';

import '../../database/database.dart';

class AppRepository {
  final AppDatabase _database;

  AppRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  Future<void> initialize() async {
    await _database.database;
  }

  Future<void> restoreDatabase(List<int> bytes) =>
      _database.replaceDatabaseBytes(bytes);

  Future<Uint8List> exportDatabase() => _database.exportDatabaseBytes();
}
