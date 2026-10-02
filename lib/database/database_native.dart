import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';

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

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'student_comparison.db';
  static const _dbVersion = 4;
  static const _publicFolder = '/storage/emulated/0/StudentComparison';

  Database? _db;
  String? _activeProfileId;

  Future<Database> get database async {
    if (_db != null) return _db!;

    _db = await openDatabase(
      await _persistentDatabasePath(),
      version: _dbVersion,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) await _upgradeToV3(db);
        if (oldVersion < 4) await _upgradeToV4(db);
      },
    );

    await _migrateOldProfilesOnce();
    return _db!;
  }

  Future<String> _persistentDatabasePath() async {
    if (Platform.isAndroid) {
      final permission = await Permission.storage.request();
      if (!permission.isGranted && !permission.isLimited) {
        throw Exception('Storage permission is required to access the database.');
      }
      final directory = Directory(_publicFolder);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return p.join(directory.path, _dbName);
    }
    return p.join(await getDatabasesPath(), _dbName);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE school_profiles (
        id TEXT PRIMARY KEY,
        school_name TEXT NOT NULL,
        psp_code TEXT NOT NULL UNIQUE,
        udise_code TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE psp_students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_profile_id TEXT NOT NULL,
        school_psp_id TEXT NOT NULL,
        nic_id TEXT NOT NULL,
        sr_no TEXT,
        aadhaar_last4 TEXT,
        student_name TEXT,
        father_name TEXT,
        mother_name TEXT,
        dob TEXT,
        gender TEXT,
        studying_class TEXT,
        mobile TEXT,
        social_category TEXT,
        religion TEXT,
        raw_json TEXT NOT NULL,
        UNIQUE(school_psp_id, nic_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE udise_students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_profile_id TEXT NOT NULL,
        school_udise_code TEXT NOT NULL,
        student_id TEXT NOT NULL,
        pen TEXT NOT NULL,
        uuid_last4 TEXT,
        uuid_status TEXT,
        name_as_uuid TEXT,
        student_name TEXT,
        father_name TEXT,
        mother_name TEXT,
        dob TEXT,
        gender TEXT,
        class_id TEXT,
        class_desc TEXT,
        mobile TEXT,
        social_category TEXT,
        religion TEXT,
        raw_json TEXT NOT NULL,
        UNIQUE(school_udise_code, pen)
      )
    ''');

    await db.execute('''
      CREATE TABLE student_remarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_psp_id TEXT NOT NULL,
        school_udise_code TEXT NOT NULL,
        psp_nic TEXT NOT NULL DEFAULT '',
        udise_pen TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(school_psp_id, school_udise_code, psp_nic, udise_pen)
      )
    ''');

    await _createIndexes(db);
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_psp_school ON psp_students(school_psp_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_psp_name ON psp_students(school_psp_id, student_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_psp_class ON psp_students(school_psp_id, studying_class)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udise_school ON udise_students(school_udise_code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udise_name ON udise_students(school_udise_code, student_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udise_class ON udise_students(school_udise_code, class_id, class_desc)',
    );
  }

  static Future<void> _upgradeToV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS school_profiles (
        id TEXT PRIMARY KEY,
        school_name TEXT NOT NULL,
        psp_code TEXT NOT NULL UNIQUE,
        udise_code TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    final pspExists = await _tableExists(db, 'psp_students');
    if (pspExists) {
      await db.execute('''
        CREATE TABLE psp_students_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_psp_id TEXT NOT NULL DEFAULT '',
          nic_id TEXT NOT NULL,
          sr_no TEXT,
          aadhaar_last4 TEXT,
          student_name TEXT,
          father_name TEXT,
          mother_name TEXT,
          dob TEXT,
          gender TEXT,
          studying_class TEXT,
          mobile TEXT,
          social_category TEXT,
          religion TEXT,
          raw_json TEXT NOT NULL,
          UNIQUE(school_psp_id, nic_id)
        )
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO psp_students_new
        (id, school_psp_id, nic_id, sr_no, aadhaar_last4, student_name,
         father_name, mother_name, dob, gender, studying_class, mobile,
         social_category, religion, raw_json)
        SELECT id, '', nic_id, sr_no, aadhaar_last4, student_name,
               father_name, mother_name, dob, gender, studying_class, mobile,
               social_category, religion, raw_json
        FROM psp_students
      ''');
      await db.execute('DROP TABLE psp_students');
      await db.execute('ALTER TABLE psp_students_new RENAME TO psp_students');
    }

    final udiseExists = await _tableExists(db, 'udise_students');
    if (udiseExists) {
      await db.execute('''
        CREATE TABLE udise_students_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          school_udise_code TEXT NOT NULL DEFAULT '',
          student_id TEXT NOT NULL,
          pen TEXT NOT NULL,
          uuid_last4 TEXT,
          uuid_status TEXT,
          name_as_uuid TEXT,
          student_name TEXT,
          father_name TEXT,
          mother_name TEXT,
          dob TEXT,
          gender TEXT,
          class_id TEXT,
          class_desc TEXT,
          mobile TEXT,
          social_category TEXT,
          religion TEXT,
          raw_json TEXT NOT NULL,
          UNIQUE(school_udise_code, pen)
        )
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO udise_students_new
        (id, school_udise_code, student_id, pen, uuid_last4, uuid_status,
         name_as_uuid, student_name, father_name, mother_name, dob, gender,
         class_id, class_desc, mobile, social_category, religion, raw_json)
        SELECT id, '', student_id, pen, uuid_last4, uuid_status, name_as_uuid,
               student_name, father_name, mother_name, dob, gender, class_id,
               class_desc, mobile, social_category, religion, raw_json
        FROM udise_students
      ''');
      await db.execute('DROP TABLE udise_students');
      await db.execute('ALTER TABLE udise_students_new RENAME TO udise_students');
    }

    await db.execute('''
      CREATE TABLE student_remarks_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_psp_id TEXT NOT NULL DEFAULT '',
        school_udise_code TEXT NOT NULL DEFAULT '',
        psp_nic TEXT NOT NULL DEFAULT '',
        udise_pen TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(school_psp_id, school_udise_code, psp_nic, udise_pen)
      )
    ''');
    if (await _tableExists(db, 'student_remarks')) {
      await db.execute('''
        INSERT OR IGNORE INTO student_remarks_new
        (id, school_psp_id, school_udise_code, psp_nic, udise_pen, remark,
         created_at, updated_at)
        SELECT id, '', '', psp_nic, udise_pen, remark, created_at, updated_at
        FROM student_remarks
      ''');
      await db.execute('DROP TABLE student_remarks');
    }
    await db.execute('ALTER TABLE student_remarks_new RENAME TO student_remarks');
    await _createIndexes(db);
  }

  static Future<void> _upgradeToV4(Database db) async {
    if (await _tableExists(db, 'psp_students')) {
      final columns = await _columnNames(db, 'psp_students');
      if (!columns.contains('school_profile_id')) {
        await db.execute(
          "ALTER TABLE psp_students ADD COLUMN school_profile_id TEXT NOT NULL DEFAULT ''",
        );
      }
    }
    if (await _tableExists(db, 'udise_students')) {
      final columns = await _columnNames(db, 'udise_students');
      if (!columns.contains('school_profile_id')) {
        await db.execute(
          "ALTER TABLE udise_students ADD COLUMN school_profile_id TEXT NOT NULL DEFAULT ''",
        );
      }
    }
    if (await _tableExists(db, 'psp_students')) {
      await db.execute('''
        UPDATE psp_students
        SET school_profile_id = (
          SELECT id FROM school_profiles
          WHERE LOWER(psp_code) = LOWER(psp_students.school_psp_id)
          LIMIT 1
        )
        WHERE school_profile_id = ''
      ''');
    }
    if (await _tableExists(db, 'udise_students')) {
      await db.execute('''
        UPDATE udise_students
        SET school_profile_id = (
          SELECT id FROM school_profiles
          WHERE LOWER(udise_code) = LOWER(udise_students.school_udise_code)
          LIMIT 1
        )
        WHERE school_profile_id = ''
      ''');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_psp_profile ON psp_students(school_profile_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_udise_profile ON udise_students(school_profile_id)',
    );
  }

  Future<String> _profileIdForCodes(String psp, String udise) async {
    final rows = await _db!.query(
      'school_profiles',
      columns: ['id'],
      where: 'LOWER(psp_code) = LOWER(?) AND LOWER(udise_code) = LOWER(?)',
      whereArgs: [psp, udise],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('School profile not found for PSP/UDISE mapping.');
    }
    return _text(rows.first['id']);
  }

  static Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getSchoolProfiles() async {
    final db = await database;
    final rows = await db.query(
      'school_profiles',
      orderBy: 'school_name COLLATE NOCASE ASC',
    );

    // Keep the database schema snake_case internally, but expose a stable
    // camelCase profile model to the UI. Without this mapping, the edit form
    // receives empty PSP/UDISE values and an existing profile cannot be saved.
    return rows
        .map(
          (row) => <String, dynamic>{
            'id': _text(row['id']),
            'schoolName': _text(row['school_name']),
            'pspCode': _text(row['psp_code']),
            'udiseCode': _text(row['udise_code']),
            'createdAt': _text(row['created_at']),
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getActiveSchoolProfile() async {
    final profiles = await getSchoolProfiles();
    if (_activeProfileId != null) {
      for (final profile in profiles) {
        if (profile['id']?.toString() == _activeProfileId) return profile;
      }
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  Future<void> setActiveSchoolProfile(String profileId) async {
    final profiles = await getSchoolProfiles();
    if (!profiles.any((p) => p['id']?.toString() == profileId)) {
      throw ArgumentError('School profile not found.');
    }
    _activeProfileId = profileId;
  }

  Future<Map<String, dynamic>> saveSchoolProfile({
    String? id,
    required String schoolName,
    required String pspCode,
    required String udiseCode,
  }) async {
    final db = await database;
    final name = schoolName.trim();
    final psp = pspCode.trim().toUpperCase();
    final udise = udiseCode.trim();

    if (name.isEmpty || psp.isEmpty || udise.isEmpty) {
      throw ArgumentError('School name, PSP code and UDISE code are required.');
    }

    final profileId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final duplicate = await db.rawQuery(
      '''
      SELECT id FROM school_profiles
      WHERE id <> ? AND
      (LOWER(psp_code) = LOWER(?) OR LOWER(udise_code) = LOWER(?))
      LIMIT 1
      ''',
      [profileId, psp, udise],
    );
    if (duplicate.isNotEmpty) {
      throw ArgumentError('A profile with this PSP or UDISE code already exists.');
    }

    final oldRows = await db.query(
      'school_profiles',
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    final old = oldRows.isEmpty ? null : oldRows.first;

    await db.transaction((txn) async {
      if (old == null) {
        await txn.insert('school_profiles', {
          'id': profileId,
          'school_name': name,
          'psp_code': psp,
          'udise_code': udise,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        final oldPsp = _text(old['psp_code']);
        final oldUdise = _text(old['udise_code']);
        await txn.update(
          'school_profiles',
          {
            'school_name': name,
            'psp_code': psp,
            'udise_code': udise,
          },
          where: 'id = ?',
          whereArgs: [profileId],
        );
        if (oldPsp != psp) {
          await txn.update(
            'psp_students',
            {'school_profile_id': profileId, 'school_psp_id': psp},
            where: 'school_psp_id = ?',
            whereArgs: [oldPsp],
          );
          await txn.update(
            'student_remarks',
            {'school_psp_id': psp},
            where: 'school_psp_id = ?',
            whereArgs: [oldPsp],
          );
        }
        if (oldUdise != udise) {
          await txn.update(
            'udise_students',
            {'school_profile_id': profileId, 'school_udise_code': udise},
            where: 'school_udise_code = ?',
            whereArgs: [oldUdise],
          );
          await txn.update(
            'student_remarks',
            {'school_udise_code': udise},
            where: 'school_udise_code = ?',
            whereArgs: [oldUdise],
          );
        }
      }
    });

    return {
      'id': profileId,
      'schoolName': name,
      'pspCode': psp,
      'udiseCode': udise,
      'createdAt': old?['created_at']?.toString() ??
          DateTime.now().toIso8601String(),
    };
  }

  Future<void> deleteSchoolProfile(String profileId) async {
    final db = await database;
    final rows = await db.query(
      'school_profiles',
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final psp = _text(rows.first['psp_code']);
    final udise = _text(rows.first['udise_code']);
    await db.transaction((txn) async {
      await txn.delete(
        'student_remarks',
        where: 'school_psp_id = ? AND school_udise_code = ?',
        whereArgs: [psp, udise],
      );
      await txn.delete(
        'psp_students',
        where: 'school_profile_id = ? OR school_psp_id = ?',
        whereArgs: [profileId, psp],
      );
      await txn.delete(
        'udise_students',
        where: 'school_profile_id = ? OR school_udise_code = ?',
        whereArgs: [profileId, udise],
      );
      await txn.delete(
        'school_profiles',
        where: 'id = ?',
        whereArgs: [profileId],
      );
    });
    if (_activeProfileId == profileId) _activeProfileId = null;
  }

  Future<Map<String, dynamic>> _requireActiveProfile() async {
    final profile = await getActiveSchoolProfile();
    if (profile == null) {
      throw StateError(
        'Please create and select a school profile before importing data.',
      );
    }
    _activeProfileId = profile['id']?.toString();
    return profile;
  }

  Future<void> replacePspRows(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final schoolProfileId = _text(profile['id']);
    final schoolPspId = _text(profile['pspCode']);

    await db.transaction((txn) async {
      await txn.delete(
        'psp_students',
        where: 'school_profile_id = ?',
        whereArgs: [schoolProfileId],
      );

      final batch = txn.batch();
      for (final row in rows) {
        final nic = _text(row['Student NIC ID']);
        if (nic.isEmpty) continue;
        final stored = Map<String, dynamic>.from(row);
        stored['schoolPspId'] = schoolPspId;

        batch.insert(
          'psp_students',
          {
            'school_profile_id': schoolProfileId,
            'school_psp_id': schoolPspId,
            'nic_id': nic,
            'sr_no': _text(row['SR No.']),
            'aadhaar_last4': _last4(row['Aadhar Number']),
            'student_name': _text(row['Student Name']),
            'father_name': _text(row['Father Name']),
            'mother_name': _text(row['Mother Name']),
            'dob': _text(row['DOB']),
            'gender': _text(row['Gender']),
            'studying_class': _text(row['Studying in Class']),
            'mobile': _text(row['Mobile Number']),
            'social_category': _text(row['Social Category']),
            'religion': _text(row['Religion']),
            'raw_json': jsonEncode(stored),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceUdiseRows(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final schoolProfileId = _text(profile['id']);
    final schoolUdiseCode = _text(profile['udiseCode']);

    await db.transaction((txn) async {
      await txn.delete(
        'udise_students',
        where: 'school_profile_id = ?',
        whereArgs: [schoolProfileId],
      );

      final batch = txn.batch();
      for (final row in rows) {
        final studentId = _text(row['studentId']);
        if (studentId.isEmpty) continue;
        final pen = _text(row['studentCodeNat']);
        final penKey = pen.isEmpty ? '__NO_PEN__:$studentId' : pen;
        final socialDesc = _text(row['socialCategoryDesc']);
        final minorityDesc = _text(row['minorityDesc']);

        final stored = Map<String, dynamic>.from(row);
        stored['schoolUdiseCode'] = schoolUdiseCode;

        batch.insert(
          'udise_students',
          {
            'school_profile_id': schoolProfileId,
            'school_udise_code': schoolUdiseCode,
            'student_id': studentId,
            'pen': penKey,
            'uuid_last4': _udiseAadhaarLast4(row['uuid']),
            'uuid_status': _text(row['uuidStatus']),
            'name_as_uuid': _text(row['nameAsUuid']),
            'student_name': _text(row['studentName']),
            'father_name': _text(row['fatherName']),
            'mother_name': _text(row['motherName']),
            'dob': _text(row['dob']),
            'gender': _text(row['gender']),
            'class_id': _text(row['classId']),
            'class_desc': _text(row['classDesc']),
            'mobile': _text(row['primaryMobile']),
            'social_category': socialDesc.isNotEmpty
                ? socialDesc
                : _text(row['socCatId']),
            'religion': minorityDesc.isNotEmpty
                ? minorityDesc
                : _text(row['minorityId']),
            'raw_json': jsonEncode(stored),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Uint8List> exportDatabaseBytes() async {
    final dbPath = await _persistentDatabasePath();
    final file = File(dbPath);
    if (!await file.exists()) throw Exception('Database file not found.');
    return file.readAsBytes();
  }

  Future<List<Map<String, dynamic>>> loadPspRows() async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final rows = await db.query(
      'psp_students',
      where: 'school_profile_id = ?',
      whereArgs: [_text(profile['id'])],
      orderBy: 'id ASC',
    );
    return _decodeRawRows(rows);
  }

  Future<List<Map<String, dynamic>>> loadUdiseRows() async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final rows = await db.query(
      'udise_students',
      where: 'school_profile_id = ?',
      whereArgs: [_text(profile['id'])],
      orderBy: 'id ASC',
    );
    return _decodeRawRows(rows);
  }

  static List<Map<String, dynamic>> _decodeRawRows(
    List<Map<String, Object?>> records,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final record in records) {
      final raw = record['raw_json']?.toString() ?? '';
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) rows.add(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    return rows;
  }

  Future<SqliteImportResult> importSqliteBytes(List<int> bytes) async {
    final target = await _requireActiveProfile();
    final tempPath = p.join(
      await getDatabasesPath(),
      'student_import_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    Database? source;
    try {
      source = await openDatabase(tempPath, readOnly: true);
      final tableRows = await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tables = tableRows
          .map((r) => r['name']?.toString() ?? '')
          .where((x) => x.isNotEmpty)
          .toSet();

      const required = {
        'school_profiles',
        'psp_students',
        'udise_students',
      };
      final missing = required.where((name) => !tables.contains(name)).toList();
      if (missing.isNotEmpty) {
        throw Exception(
          'Database import rejected: school-aware database required. Missing: ${missing.join(', ')}',
        );
      }

      final targetPsp = _text(target['psp_code']);
      final targetUdise = _text(target['udise_code']);
      final sourceProfile = await source.query(
        'school_profiles',
        where: 'LOWER(psp_code) = LOWER(?) AND LOWER(udise_code) = LOWER(?)',
        whereArgs: [targetPsp, targetUdise],
        limit: 1,
      );
      if (sourceProfile.isEmpty) {
        throw Exception(
          'Database import rejected: this database belongs to another school.',
        );
      }

      final pspColumns = await _columnNames(source, 'psp_students');
      final udiseColumns = await _columnNames(source, 'udise_students');
      if (!pspColumns.contains('school_psp_id') ||
          !udiseColumns.contains('school_udise_code')) {
        throw Exception(
          'Database import rejected: school mapping columns are missing.',
        );
      }

      final pspSourceRows = await source.query(
        'psp_students',
        where: 'school_psp_id = ?',
        whereArgs: [targetPsp],
      );
      final udiseSourceRows = await source.query(
        'udise_students',
        where: 'school_udise_code = ?',
        whereArgs: [targetUdise],
      );

      if (pspSourceRows.isEmpty && udiseSourceRows.isEmpty) {
        throw Exception(
          'Database import rejected: no data for the selected school.',
        );
      }

      if (pspSourceRows.isNotEmpty) {
        await replacePspRows(
          pspSourceRows.map(_sourcePspToJson).toList(),
        );
      }
      if (udiseSourceRows.isNotEmpty) {
        await replaceUdiseRows(
          udiseSourceRows.map(_sourceUdiseToJson).toList(),
        );
      }

      var importedRemarks = 0;
      if (tables.contains('student_remarks')) {
        final columns = await _columnNames(source, 'student_remarks');
        if (columns.contains('school_psp_id') &&
            columns.contains('school_udise_code')) {
          final remarks = await source.query(
            'student_remarks',
            where: 'school_psp_id = ? AND school_udise_code = ?',
            whereArgs: [targetPsp, targetUdise],
          );
          for (final row in remarks) {
            final remark = _text(row['remark']);
            if (remark.isEmpty) continue;
            await saveRemark(
              pspNic: _text(row['psp_nic']),
              udisePen: _text(row['udise_pen']),
              remark: remark,
            );
            importedRemarks++;
          }
        }
      }

      return SqliteImportResult(
        pspCount: pspSourceRows.length,
        udiseCount: udiseSourceRows.length,
        remarkCount: importedRemarks,
        sourceTables: tables.toList()..sort(),
      );
    } finally {
      await source?.close();
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  static Future<Set<String>> _columnNames(
    Database db,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  static Map<String, dynamic> _sourcePspToJson(
    Map<String, Object?> row,
  ) {
    final raw = _text(row['raw_json']);
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {
      'Student NIC ID': row['nic_id'],
      'SR No.': row['sr_no'],
      'Aadhar Number': row['aadhaar_last4'],
      'Student Name': row['student_name'],
      'Father Name': row['father_name'],
      'Mother Name': row['mother_name'],
      'DOB': row['dob'],
      'Gender': row['gender'],
      'Studying in Class': row['studying_class'],
      'Mobile Number': row['mobile'],
      'Social Category': row['social_category'],
      'Religion': row['religion'],
    };
  }

  static Map<String, dynamic> _sourceUdiseToJson(
    Map<String, Object?> row,
  ) {
    final raw = _text(row['raw_json']);
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {
      'studentId': row['student_id'],
      'studentCodeNat': row['pen'],
      'uuid': row['uuid_last4'],
      'uuidStatus': row['uuid_status'],
      'nameAsUuid': row['name_as_uuid'],
      'studentName': row['student_name'],
      'fatherName': row['father_name'],
      'motherName': row['mother_name'],
      'dob': row['dob'],
      'gender': row['gender'],
      'classId': row['class_id'],
      'classDesc': row['class_desc'],
      'primaryMobile': row['mobile'],
      'socialCategoryDesc': row['social_category'],
      'minorityDesc': row['religion'],
    };
  }

  Future<Map<String, dynamic>?> getRemark({
    String? pspNic,
    String? udisePen,
  }) async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final rows = await db.query(
      'student_remarks',
      where: 'school_psp_id = ? AND school_udise_code = ? AND psp_nic = ? AND udise_pen = ?',
      whereArgs: [
        _text(profile['pspCode']),
        _text(profile['udiseCode']),
        pspNic ?? '',
        udisePen ?? '',
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveRemark({
    required String remark,
    String? pspNic,
    String? udisePen,
  }) async {
    if ((pspNic ?? '').isEmpty && (udisePen ?? '').isEmpty) {
      throw ArgumentError('At least one student identifier is required.');
    }
    final db = await database;
    final profile = await _requireActiveProfile();
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'student_remarks',
      {
        'school_psp_id': _text(profile['pspCode']),
        'school_udise_code': _text(profile['udiseCode']),
        'psp_nic': pspNic ?? '',
        'udise_pen': udisePen ?? '',
        'remark': remark,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRemark({
    String? pspNic,
    String? udisePen,
  }) async {
    final db = await database;
    final profile = await _requireActiveProfile();
    await db.delete(
      'student_remarks',
      where: 'school_psp_id = ? AND school_udise_code = ? AND psp_nic = ? AND udise_pen = ?',
      whereArgs: [
        _text(profile['pspCode']),
        _text(profile['udiseCode']),
        pspNic ?? '',
        udisePen ?? '',
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getAllRemarks() async {
    final db = await database;
    final profile = await _requireActiveProfile();
    return db.query(
      'student_remarks',
      where: 'school_psp_id = ? AND school_udise_code = ?',
      whereArgs: [
        _text(profile['pspCode']),
        _text(profile['udiseCode']),
      ],
      orderBy: 'updated_at DESC',
    );
  }

  Future<int> pspCount() async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM psp_students WHERE school_profile_id = ?',
      [_text(profile['id'])],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> udiseCount() async {
    final db = await database;
    final profile = await _requireActiveProfile();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM udise_students WHERE school_profile_id = ?',
      [_text(profile['id'])],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> _migrateOldProfilesOnce() async {
    final jsonPath = p.join(_publicFolder, 'school_profiles.json');
    final file = File(jsonPath);
    if (!await file.exists() || _db == null) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        final profiles = decoded.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        );

        for (final old in profiles) {
          final name = _text(old['schoolName']);
          final psp = _text(old['pspCode']);
          final udise = _text(old['udiseCode']);
          final id = _text(old['id']);

          // Remove the former placeholder/legacy profile completely.
          if (name.isEmpty || psp.isEmpty || udise.isEmpty || id.isEmpty) {
            continue;
          }

          final exists = await _db!.query(
            'school_profiles',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (exists.isEmpty) {
            try {
              await _db!.insert('school_profiles', {
                'id': id,
                'school_name': name,
                'psp_code': psp,
                'udise_code': udise,
                'created_at': _text(old['createdAt']).isEmpty
                    ? DateTime.now().toIso8601String()
                    : _text(old['createdAt']),
              });
            } catch (_) {}
          }

          // Migrate the old per-school SQLite database into the new single DB.
          if (Platform.isAndroid) {
            final oldDbFile = File(
              p.join(_publicFolder, 'student_comparison_$id.db'),
            );
            if (await oldDbFile.exists()) {
              await _importLegacySchoolDatabase(
                oldDbFile,
                schoolPspId: psp,
                schoolUdiseCode: udise,
              );
              try {
                await oldDbFile.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {
      // A broken legacy JSON file must never prevent the app from opening.
    }

    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> _importLegacySchoolDatabase(
    File oldDbFile, {
    required String schoolPspId,
    required String schoolUdiseCode,
  }) async {
    Database? oldDb;
    try {
      oldDb = await openDatabase(oldDbFile.path, readOnly: true);
      final names = (await oldDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      ))
          .map((row) => row['name']?.toString() ?? '')
          .toSet();

      if (names.contains('psp_students')) {
        final rows = await oldDb.query('psp_students');
        final batch = _db!.batch();
        for (final row in rows) {
          final nic = _text(row['nic_id']);
          final raw = _text(row['raw_json']);
          if (nic.isEmpty || raw.isEmpty) continue;
          batch.insert(
            'psp_students',
            {
              'school_profile_id': await _profileIdForCodes(schoolPspId, schoolUdiseCode),
              'school_psp_id': schoolPspId,
              'nic_id': nic,
              'sr_no': row['sr_no'],
              'aadhaar_last4': row['aadhaar_last4'],
              'student_name': row['student_name'],
              'father_name': row['father_name'],
              'mother_name': row['mother_name'],
              'dob': row['dob'],
              'gender': row['gender'],
              'studying_class': row['studying_class'],
              'mobile': row['mobile'],
              'social_category': row['social_category'],
              'religion': row['religion'],
              'raw_json': raw,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      if (names.contains('udise_students')) {
        final rows = await oldDb.query('udise_students');
        final batch = _db!.batch();
        for (final row in rows) {
          final studentId = _text(row['student_id']);
          final pen = _text(row['pen']);
          final raw = _text(row['raw_json']);
          if (studentId.isEmpty || raw.isEmpty) continue;
          batch.insert(
            'udise_students',
            {
              'school_profile_id': await _profileIdForCodes(schoolPspId, schoolUdiseCode),
              'school_udise_code': schoolUdiseCode,
              'student_id': studentId,
              'pen': pen.isEmpty ? '__NO_PEN__:$studentId' : pen,
              'uuid_last4': row['uuid_last4'],
              'uuid_status': row['uuid_status'],
              'name_as_uuid': row['name_as_uuid'],
              'student_name': row['student_name'],
              'father_name': row['father_name'],
              'mother_name': row['mother_name'],
              'dob': row['dob'],
              'gender': row['gender'],
              'class_id': row['class_id'],
              'class_desc': row['class_desc'],
              'mobile': row['mobile'],
              'social_category': row['social_category'],
              'religion': row['religion'],
              'raw_json': raw,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      if (names.contains('student_remarks')) {
        final rows = await oldDb.query('student_remarks');
        final batch = _db!.batch();
        for (final row in rows) {
          final pspNic = _text(row['psp_nic']);
          final udisePen = _text(row['udise_pen']);
          if (pspNic.isEmpty && udisePen.isEmpty) continue;
          batch.insert(
            'student_remarks',
            {
              'school_psp_id': schoolPspId,
              'school_udise_code': schoolUdiseCode,
              'psp_nic': pspNic,
              'udise_pen': udisePen,
              'remark': _text(row['remark']),
              'created_at': _text(row['created_at']).isEmpty
                  ? DateTime.now().toIso8601String()
                  : _text(row['created_at']),
              'updated_at': _text(row['updated_at']).isEmpty
                  ? DateTime.now().toIso8601String()
                  : _text(row['updated_at']),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    } finally {
      await oldDb?.close();
    }
  }

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String _last4(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'\\D'), '');
    if (digits.length < 4) return '';
    return digits.substring(digits.length - 4);
  }

  static String _udiseAadhaarLast4(dynamic value) {
    final last = _last4(value);
    return last == '9999' ? '' : last;
  }
}
