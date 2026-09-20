import 'normalizers.dart';

class PspStudent {
  final String nicId;
  final String srNo;
  final String aadhaarLast4;
  final String studentName;
  final String fatherName;
  final String motherName;
  final String dob;
  final String gender;
  final String studyingClass;
  final String mobile;
  final String socialCategory;
  final String religion;

  const PspStudent({
    required this.nicId,
    required this.srNo,
    required this.aadhaarLast4,
    required this.studentName,
    required this.fatherName,
    required this.motherName,
    required this.dob,
    required this.gender,
    required this.studyingClass,
    required this.mobile,
    required this.socialCategory,
    required this.religion,
  });

  factory PspStudent.fromJson(Map<String, dynamic> r) {
    return PspStudent(
      nicId: clean(r['Student NIC ID']),
      srNo: clean(r['SR No.']),
      aadhaarLast4: last4(r['Aadhar Number']),
      studentName: clean(r['Student Name']),
      fatherName: clean(r['Father Name']),
      motherName: clean(r['Mother Name']),
      dob: clean(r['DOB']),
      gender: clean(r['Gender']),
      studyingClass: clean(r['Studying in Class']),
      mobile: clean(r['Mobile Number']),
      socialCategory: clean(r['Social Category']),
      religion: clean(r['Religion']),
    );
  }

  String get nameNorm => norm(studentName);
  String get fatherNorm => norm(fatherName);
  String get motherNorm => norm(motherName);
  String get dobNorm => normalizeDob(dob);
  String get genderNormValue => genderNorm(gender);
  String get mobileDigits => digits(mobile);
  String get classCanonValue => classCanon(studyingClass);
  String get categoryNorm => socialCatNorm(socialCategory);
  String get religionNormValue => religionNorm(religion);
}

class UdiseStudent {
  final String studentId;
  final String studentCodeNat;
  final String uuidLast4;
  final String uuidStatus;
  final String nameAsUuid;
  final String studentName;
  final String fatherName;
  final String motherName;
  final String dob;
  final String gender;
  final String classId;
  final String classDesc;
  final String mobile;
  final String socialCategory;
  final String religion;

  const UdiseStudent({
    required this.studentId,
    required this.studentCodeNat,
    required this.uuidLast4,
    required this.uuidStatus,
    required this.nameAsUuid,
    required this.studentName,
    required this.fatherName,
    required this.motherName,
    required this.dob,
    required this.gender,
    required this.classId,
    required this.classDesc,
    required this.mobile,
    required this.socialCategory,
    required this.religion,
  });

  factory UdiseStudent.fromJson(Map<String, dynamic> r) {
    final uuidRaw = clean(r['uuid']);
  
    String normalizeUuidLast4(String value) {
      if (value.isEmpty) return '';
  
      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length < 4) return '';
  
      final last = digitsOnly.substring(digitsOnly.length - 4);
  
      if (last == '9999') return '';
  
      return last;
    }
  
    final socialDesc = clean(r['socialCategoryDesc']);
    final minorityDesc = clean(r['minorityDesc']);
  
    return UdiseStudent(
      studentId: clean(r['studentId']),
      studentCodeNat: clean(r['studentCodeNat']),
      uuidLast4: normalizeUuidLast4(uuidRaw),
      uuidStatus: clean(r['uuidStatus']),
      nameAsUuid: clean(r['nameAsUuid']),
      studentName: clean(r['studentName']),
      fatherName: clean(r['fatherName']),
      motherName: clean(r['motherName']),
      dob: clean(r['dob']),
      gender: clean(r['gender']),
      classId: clean(r['classId']),
      classDesc: clean(r['classDesc']),
      mobile: clean(r['primaryMobile']),
      socialCategory:
          socialDesc.isNotEmpty ? socialDesc : clean(r['socCatId']),
      religion:
          minorityDesc.isNotEmpty ? minorityDesc : clean(r['minorityId']),
    );
  }
  
  String get nameNorm => norm(studentName);
  String get nameUuidNorm => norm(nameAsUuid);
  String get fatherNorm => norm(fatherName);
  String get motherNorm => norm(motherName);
  String get dobNorm => normalizeDob(dob);
  String get genderNormValue => genderNorm(gender);
  String get mobileDigits => digits(mobile);
  String get classIdCanon => classCanon(classId);
  String get classDescCanon => classCanon(classDesc);
  String get categoryNorm => socialCatNorm(socialCategory);
  String get religionNormValue => religionNorm(religion);
}

enum MatchType {
  matched,
  mismatch,
  possibleMatch,
  notInUdise,
  notInPsp,
}

class MatchEvidence {
  final bool nameExact;
  final double nameSim;
  final bool dobSame;
  final bool mobileSame;
  final bool aadhaarSame;
  final bool classSame;
  final bool genderSame;
  final bool fatherSame;
  final bool motherSame;
  final bool categorySame;
  final bool religionSame;

  const MatchEvidence({
    required this.nameExact,
    required this.nameSim,
    required this.dobSame,
    required this.mobileSame,
    required this.aadhaarSame,
    required this.classSame,
    required this.genderSame,
    required this.fatherSame,
    required this.motherSame,
    required this.categorySame,
    required this.religionSame,
  });
}

class MatchEdge {
  final int pspIndex;
  final int udiseIndex;
  final MatchEvidence evidence;
  final int tier;
  final int score;

  const MatchEdge({
    required this.pspIndex,
    required this.udiseIndex,
    required this.evidence,
    required this.tier,
    required this.score,
  });
}

class ComparisonRow {
  final PspStudent? psp;
  final UdiseStudent? udise;
  final MatchType type;
  final List<String> diffs;
  final int score;
  final int matchTier;

  const ComparisonRow({
    required this.psp,
    required this.udise,
    required this.type,
    required this.diffs,
    required this.score,
    required this.matchTier,
  });
}
