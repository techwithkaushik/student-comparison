import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final dbFile = p.join(dbPath, _dbName);

    _db = await openDatabase(
      dbFile,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );

    return _db!;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE psp_students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nic_id TEXT NOT NULL UNIQUE,
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
        raw_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE udise_students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        pen TEXT NOT NULL UNIQUE,
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
        raw_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE student_remarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        psp_nic TEXT NOT NULL DEFAULT '',
        udise_pen TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(psp_nic, udise_pen)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_psp_name ON psp_students(student_name)',
    );
    await db.execute(
      'CREATE INDEX idx_psp_father ON psp_students(father_name)',
    );
    await db.execute(
      'CREATE INDEX idx_psp_mother ON psp_students(mother_name)',
    );
    await db.execute(
      'CREATE INDEX idx_psp_mobile ON psp_students(mobile)',
    );
    await db.execute(
      'CREATE INDEX idx_psp_class ON psp_students(studying_class)',
    );

    await db.execute(
      'CREATE INDEX idx_udise_name ON udise_students(student_name)',
    );
    await db.execute(
      'CREATE INDEX idx_udise_father ON udise_students(father_name)',
    );
    await db.execute(
      'CREATE INDEX idx_udise_mother ON udise_students(mother_name)',
    );
    await db.execute(
      'CREATE INDEX idx_udise_mobile ON udise_students(mobile)',
    );
    await db.execute(
      'CREATE INDEX idx_udise_class ON udise_students(class_id, class_desc)',
    );
  }

  Future<void> replacePspRows(List<Map<String, dynamic>> rows) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('psp_students');

      final batch = txn.batch();

      for (final row in rows) {
        final nic = _text(row['Student NIC ID']);
        if (nic.isEmpty) continue;

        batch.insert(
          'psp_students',
          {
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
            'raw_json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceUdiseRows(List<Map<String, dynamic>> rows) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('udise_students');

      final batch = txn.batch();

      for (final row in rows) {
        final studentId = _text(row['studentId']);
        final pen = _text(row['studentCodeNat']);

        if (studentId.isEmpty || pen.isEmpty) continue;

        final socialDesc = _text(row['socialCategoryDesc']);
        final minorityDesc = _text(row['minorityDesc']);

        batch.insert(
          'udise_students',
          {
            'student_id': studentId,
            'pen': pen,
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
            'raw_json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }


  Future<List<Map<String, dynamic>>> loadPspRows() async {
    final db = await database;
    final records = await db.query(
      'psp_students',
      orderBy: 'id ASC',
    );

    final rows = <Map<String, dynamic>>[];

    for (final record in records) {
      final raw = record['raw_json']?.toString() ?? '';
      if (raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          rows.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> loadUdiseRows() async {
    final db = await database;
    final records = await db.query(
      'udise_students',
      orderBy: 'id ASC',
    );

    final rows = <Map<String, dynamic>>[];

    for (final record in records) {
      final raw = record['raw_json']?.toString() ?? '';
      if (raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          rows.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return rows;
  }



  Future<SqliteImportResult> importSqliteBytes(List<int> bytes) async {
    final dbPath = await getDatabasesPath();
    final tempPath = p.join(
      dbPath,
      'student_import_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    Database? source;
    try {
      source = await openDatabase(tempPath, readOnly: true);
      final tableRows = await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final tables = tableRows
          .map((r) => r['name']?.toString() ?? '')
          .where((x) => x.isNotEmpty)
          .toSet();

      final pspTable = tables.contains('psp_students')
          ? 'psp_students'
          : tables.contains('psp_student_data')
              ? 'psp_student_data'
              : null;
      final udiseTable = tables.contains('udise_students')
          ? 'udise_students'
          : tables.contains('udise_data')
              ? 'udise_data'
              : null;

      if (pspTable == null && udiseTable == null) {
        throw Exception(
          'SQLite file does not contain a supported PSP/UDISE table. '
          'Supported tables: psp_students, udise_students, '
          'psp_student_data, udise_data.',
        );
      }

      final pspRows = pspTable == null
          ? <Map<String, dynamic>>[]
          : await _readPspSourceRows(source, pspTable);
      final udiseRows = udiseTable == null
          ? <Map<String, dynamic>>[]
          : await _readUdiseSourceRows(source, udiseTable);

      if (pspRows.isEmpty && udiseRows.isEmpty) {
        throw Exception('SQLite file contains no usable student records.');
      }

      if (pspRows.isNotEmpty) {
        await replacePspRows(pspRows);
      }
      if (udiseRows.isNotEmpty) {
        await replaceUdiseRows(udiseRows);
      }

      var importedRemarks = 0;
      if (tables.contains('student_remarks')) {
        final remarks = await source.query('student_remarks');
        for (final row in remarks) {
          final pspNic = _text(row['psp_nic']);
          final pen = _text(row['udise_pen']);
          final remark = _text(row['remark']);
          if (pspNic.isEmpty && pen.isEmpty) continue;
          if (remark.isEmpty) continue;
          await saveRemark(
            pspNic: pspNic,
            udisePen: pen,
            remark: remark,
          );
          importedRemarks++;
        }
      }

      return SqliteImportResult(
        pspCount: pspRows.length,
        udiseCount: udiseRows.length,
        remarkCount: importedRemarks,
        sourceTables: tables.toList()..sort(),
      );
    } finally {
      await source?.close();
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _readPspSourceRows(
    Database source,
    String table,
  ) async {
    final rows = await source.query(table);
    if (table == 'psp_student_data') {
      return rows.map(Map<String, dynamic>.from).toList();
    }

    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final raw = _text(row['raw_json']);
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            out.add(Map<String, dynamic>.from(decoded));
            continue;
          }
        } catch (_) {}
      }

      out.add({
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
      });
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _readUdiseSourceRows(
    Database source,
    String table,
  ) async {
    final rows = await source.query(table);
    if (table == 'udise_data') {
      return rows.map(Map<String, dynamic>.from).toList();
    }

    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final raw = _text(row['raw_json']);
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            out.add(Map<String, dynamic>.from(decoded));
            continue;
          }
        } catch (_) {}
      }

      out.add({
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
      });
    }
    return out;
  }

  Future<Map<String, dynamic>?> getRemark({
    String? pspNic,
    String? udisePen,
  }) async {
    final db = await database;
    final rows = await db.query(
      'student_remarks',
      where: 'psp_nic = ? AND udise_pen = ?',
      whereArgs: [pspNic ?? '', udisePen ?? ''],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveRemark({
    required String remark,
    String? pspNic,
    String? udisePen,
  }) async {
    final psp = pspNic ?? '';
    final pen = udisePen ?? '';

    if (psp.isEmpty && pen.isEmpty) {
      throw ArgumentError(
        'At least one of pspNic or udisePen is required.',
      );
    }

    final db = await database;
    final now = DateTime.now().toIso8601String();

    final values = {
      'psp_nic': psp,
      'udise_pen': pen,
      'remark': remark,
      'created_at': now,
      'updated_at': now,
    };

    await db.insert(
      'student_remarks',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRemark({
    String? pspNic,
    String? udisePen,
  }) async {
    final db = await database;

    await db.delete(
      'student_remarks',
      where: 'psp_nic = ? AND udise_pen = ?',
      whereArgs: [pspNic ?? '', udisePen ?? ''],
    );
  }

  Future<List<Map<String, dynamic>>> getAllRemarks() async {
    final db = await database;
    return db.query(
      'student_remarks',
      orderBy: 'updated_at DESC',
    );
  }

  Future<int> pspCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM psp_students',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> udiseCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM udise_students',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String _last4(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return '';

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '';

    return digits.substring(digits.length - 4);
  }

  static String _udiseAadhaarLast4(dynamic value) {
    final last = _last4(value);
    return last == '9999' ? '' : last;
  }
}
