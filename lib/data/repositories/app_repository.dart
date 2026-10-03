import '../../database/database.dart';

class AppRepository {
  final AppDatabase _database;

  AppRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  Future<void> initialize() async {
    await _database.database;
  }
}
