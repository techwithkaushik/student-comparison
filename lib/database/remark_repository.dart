import 'database.dart';

class RemarkRepository {
  final AppDatabase _database;

  RemarkRepository({
    AppDatabase? database,
  }) : _database = database ?? AppDatabase.instance;

  Future<Map<String, dynamic>?> get({
    String? pspNic,
    String? udisePen,
  }) {
    return _database.getRemark(
      pspNic: pspNic,
      udisePen: udisePen,
    );
  }

  Future<void> save({
    required String remark,
    String? pspNic,
    String? udisePen,
  }) {
    return _database.saveRemark(
      remark: remark,
      pspNic: pspNic,
      udisePen: udisePen,
    );
  }

  Future<void> delete({
    String? pspNic,
    String? udisePen,
  }) {
    return _database.deleteRemark(
      pspNic: pspNic,
      udisePen: udisePen,
    );
  }

  Future<List<Map<String, dynamic>>> all() {
    return _database.getAllRemarks();
  }
}
