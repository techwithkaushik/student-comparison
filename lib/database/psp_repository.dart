
import 'database.dart';

class PspRepository {
  final AppDatabase _database;

  PspRepository({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  Future<void> replaceImport(List<Map<String, dynamic>> rows) {
    return _database.replacePspRows(rows);
  }

  Future<int> count() {
    return _database.pspCount();
  }
}
