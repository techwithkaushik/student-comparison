
import 'database.dart';

class UdiseRepository {
  final AppDatabase _database;

  UdiseRepository({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  Future<void> replaceImport(List<Map<String, dynamic>> rows) {
    return _database.replaceUdiseRows(rows);
  }

  Future<int> count() {
    return _database.udiseCount();
  }
}
