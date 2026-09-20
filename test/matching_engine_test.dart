import 'package:flutter_test/flutter_test.dart';

import 'package:student_comparison/matching/matching_engine.dart';
import 'package:student_comparison/matching/models.dart';

PspStudent psp({
  String nic = 'P001',
  String aadhaar = '1234',
  String name = 'Rahul Kumar',
  String father = 'Ramesh Kumar',
  String mother = 'Sita Devi',
  String dob = '01/01/2015',
  String gender = 'Male',
  String studentClass = 'First',
  String mobile = '9876543210',
  String category = 'GENERAL',
  String religion = 'HINDU',
}) {
  return PspStudent(
    nicId: nic,
    srNo: '1',
    aadhaarLast4: aadhaar,
    studentName: name,
    fatherName: father,
    motherName: mother,
    dob: dob,
    gender: gender,
    studyingClass: studentClass,
    mobile: mobile,
    socialCategory: category,
    religion: religion,
  );
}

UdiseStudent udise({
  String id = 'U001',
  String pen = 'PEN001',
  String aadhaar = '1234',
  String name = 'Rahul Kumar',
  String father = 'Ramesh Kumar',
  String mother = 'Sita Devi',
  String dob = '01/01/2015',
  String gender = 'Male',
  String classId = '1',
  String classDesc = 'I',
  String mobile = '9876543210',
  String category = '1',
  String religion = '7',
}) {
  return UdiseStudent(
    studentId: id,
    studentCodeNat: pen,
    uuidLast4: aadhaar,
    uuidStatus: '1',
    nameAsUuid: name,
    studentName: name,
    fatherName: father,
    motherName: mother,
    dob: dob,
    gender: gender,
    classId: classId,
    classDesc: classDesc,
    mobile: mobile,
    socialCategory: category,
    religion: religion,
  );
}

void main() {
  group('Matching Engine', () {
    test('exact student should match', () {
      final rows = runMatchingEngine(
        [
          psp(),
        ],
        [
          udise(),
        ],
      );

      expect(rows.length, 1);
      expect(rows.first.type, MatchType.matched);
      expect(rows.first.psp?.nicId, 'P001');
      expect(rows.first.udise?.studentCodeNat, 'PEN001');
    });

    test('class mismatch should NOT prevent identity matching', () {
      final rows = runMatchingEngine(
        [
          psp(
            studentClass: 'First',
          ),
        ],
        [
          udise(
            classId: '2',
            classDesc: 'II',
          ),
        ],
      );

      expect(rows.length, 1);

      expect(
        rows.first.type,
        MatchType.mismatch,
      );

      expect(
        rows.first.diffs,
        contains('CLASS_MISMATCH'),
      );
    });

    test('class Eight, VIII and 8 should normalize to the same class', () {
      final p = psp(
        studentClass: 'Eight',
      );
    
      final u1 = udise(
        classId: 'VIII',
        classDesc: 'VIII',
      );
    
      final u2 = udise(
        classId: '8',
        classDesc: '8',
      );
    
      expect(p.classCanonValue, '8');
    
      expect(
        u1.classIdCanon,
        '8',
      );
    
      expect(
        u1.classDescCanon,
        '8',
      );
    
      expect(
        u2.classIdCanon,
        '8',
      );
    
      expect(
        u2.classDescCanon,
        '8',
      );
    
      expect(
        p.classCanonValue,
        u1.classDescCanon,
      );
    
      expect(
        p.classCanonValue,
        u2.classIdCanon,
      );
    });
    
    test('Aadhaar mismatch should not by itself make identity mismatch', () {
      final rows = runMatchingEngine(
        [
          psp(
            aadhaar: '1234',
          ),
        ],
        [
          udise(
            aadhaar: '5678',
          ),
        ],
      );

      expect(rows.length, 1);

      expect(
        rows.first.type,
        MatchType.matched,
      );

      expect(
        rows.first.diffs,
        contains('AADHAAR_MISMATCH'),
      );
    });

    test('mobile mismatch should not by itself make identity mismatch', () {
      final rows = runMatchingEngine(
        [
          psp(
            mobile: '9876543210',
          ),
        ],
        [
          udise(
            mobile: '9123456780',
          ),
        ],
      );

      expect(rows.length, 1);

      expect(
        rows.first.type,
        MatchType.matched,
      );

      expect(
        rows.first.diffs,
        contains('MOBILE_MISMATCH'),
      );
    });

    test('PSP student missing from UDISE should be PSP only', () {
      final rows = runMatchingEngine(
        [
          psp(
            nic: 'PSP_ONLY',
            name: 'Student Only PSP',
          ),
        ],
        [],
      );

      expect(rows.length, 1);
      expect(
        rows.first.type,
        MatchType.notInUdise,
      );

      expect(
        rows.first.diffs,
        contains('PSP_BUT_NOT_IN_UDISE'),
      );
    });

    test('UDISE student missing from PSP should be UDISE only', () {
      final rows = runMatchingEngine(
        [],
        [
          udise(
            id: 'UDISE_ONLY',
            pen: 'PEN_ONLY',
            name: 'Student Only UDISE',
          ),
        ],
      );

      expect(rows.length, 1);
      expect(
        rows.first.type,
        MatchType.notInPsp,
      );

      expect(
        rows.first.diffs,
        contains('UDISE_BUT_NOT_IN_PSP'),
      );
    });

    test('multiple students should match one-to-one', () {
      final rows = runMatchingEngine(
        [
          psp(
            nic: 'P001',
            name: 'Rahul Kumar',
            aadhaar: '1111',
            mobile: '9000000001',
          ),
          psp(
            nic: 'P002',
            name: 'Amit Kumar',
            aadhaar: '2222',
            mobile: '9000000002',
          ),
        ],
        [
          udise(
            id: 'U001',
            pen: 'PEN001',
            name: 'Rahul Kumar',
            aadhaar: '1111',
            mobile: '9000000001',
          ),
          udise(
            id: 'U002',
            pen: 'PEN002',
            name: 'Amit Kumar',
            aadhaar: '2222',
            mobile: '9000000002',
          ),
        ],
      );

      expect(rows.length, 2);

      expect(
        rows.where((r) => r.type == MatchType.matched).length,
        2,
      );

      final pspIds = rows
          .where((r) => r.psp != null)
          .map((r) => r.psp!.nicId)
          .toSet();

      final udiseIds = rows
          .where((r) => r.udise != null)
          .map((r) => r.udise!.studentCodeNat)
          .toSet();

      expect(
        pspIds,
        {'P001', 'P002'},
      );

      expect(
        udiseIds,
        {'PEN001', 'PEN002'},
      );
    });

    test('same student with wrong UDISE class should still be paired', () {
      final rows = runMatchingEngine(
        [
          psp(
            nic: 'P001',
            name: 'Aanya Sharma',
            aadhaar: '5283',
            studentClass: 'First',
          ),
        ],
        [
          udise(
            id: 'U001',
            pen: 'PEN001',
            name: 'Aanya Sharma',
            aadhaar: '5283',
            classId: '2',
            classDesc: 'II',
          ),
        ],
      );

      expect(rows.length, 1);
      expect(rows.first.psp?.nicId, 'P001');
      expect(rows.first.udise?.studentCodeNat, 'PEN001');

      expect(
        rows.first.diffs,
        contains('CLASS_MISMATCH'),
      );
    });

    test('both Aadhaar values missing should produce Aadhaar not found', () {
      final rows = runMatchingEngine(
        [
          psp(
            aadhaar: '',
          ),
        ],
        [
          udise(
            aadhaar: '',
          ),
        ],
      );

      expect(rows.length, 1);

      expect(
        rows.first.diffs,
        contains('AADHAAR_NOT_FOUND'),
      );
    });
  });
}
