import '../../database/database.dart';

class SchoolRepository {
  final AppDatabase _database;

  SchoolRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  Future<List<Map<String, dynamic>>> getProfiles() =>
      _database.getSchoolProfiles();

  Future<void> saveProfile({
    String? id,
    required String schoolName,
    required String pspCode,
    required String udiseCode,
  }) =>
      _database.saveSchoolProfile(
        id: id,
        schoolName: schoolName,
        pspCode: pspCode,
        udiseCode: udiseCode,
      );

  Future<void> deleteProfile(String profileId) =>
      _database.deleteSchoolProfile(profileId);

  Future<void> setActiveProfile(String profileId) =>
      _database.setActiveSchoolProfile(profileId);

  Future<Map<String, dynamic>?> getActiveProfile() =>
      _database.getActiveSchoolProfile();
}
