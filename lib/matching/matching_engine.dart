import 'models.dart';
import 'normalizers.dart';

String _aadhaarState(PspStudent p, UdiseStudent u) {
  final pa = p.aadhaarLast4.isNotEmpty;
  final ua = u.uuidLast4.isNotEmpty;

  if (!pa && !ua) return 'NOT_FOUND';
  if (pa != ua) return 'MISMATCH';

  return p.aadhaarLast4 == u.uuidLast4 ? 'MATCH' : 'MISMATCH';
}

List<String> compareStudents(PspStudent p, UdiseStudent u) {
  final diffs = <String>[];

  final aadhaar = _aadhaarState(p, u);

  if (aadhaar == 'MISMATCH') {
    diffs.add('AADHAAR_MISMATCH');
  }

  if (aadhaar == 'NOT_FOUND') {
    diffs.add('AADHAAR_NOT_FOUND');
  }

  if (p.nameNorm != u.nameNorm) {
    diffs.add('NAME_MISMATCH');
  }

  if (p.dobNorm != u.dobNorm) {
    diffs.add('DOB_MISMATCH');
  }

  if (p.fatherName.isNotEmpty &&
      u.fatherName.isNotEmpty &&
      p.fatherNorm != u.fatherNorm) {
    diffs.add('FATHER_MISMATCH');
  }

  if (p.motherName.isNotEmpty &&
      u.motherName.isNotEmpty &&
      p.motherNorm != u.motherNorm) {
    diffs.add('MOTHER_MISMATCH');
  }

  if (p.classCanonValue != u.classIdCanon &&
      p.classCanonValue != u.classDescCanon) {
    diffs.add('CLASS_MISMATCH');
  }

  if (p.gender.isNotEmpty &&
      u.gender.isNotEmpty &&
      p.genderNormValue != u.genderNormValue) {
    diffs.add('GENDER_MISMATCH');
  }

  final pm = p.mobileDigits;
  final um = u.mobileDigits;

  if (pm.isEmpty || um.isEmpty) {
    diffs.add('MOBILE_NOT_FOUND');
  } else if (pm != um) {
    diffs.add('MOBILE_MISMATCH');
  }

  if (p.categoryNorm != u.categoryNorm) {
    diffs.add('CATEGORY_MISMATCH');
  }

  if (p.religionNormValue != u.religionNormValue) {
    diffs.add('RELIGION_MISMATCH');
  }

  return diffs;
}

bool hasCoreIdentityMismatch(List<String> diffs) {
  return diffs.any(
    (d) =>
        d != 'AADHAAR_MISMATCH' &&
        d != 'AADHAAR_NOT_FOUND' &&
        d != 'MOBILE_MISMATCH' &&
        d != 'MOBILE_NOT_FOUND',
  );
}

int exactScore(PspStudent p, UdiseStudent u) {
  var score = 0;

  if (p.aadhaarLast4.isNotEmpty &&
      p.aadhaarLast4 == u.uuidLast4) {
    score += 5;
  }

  if (p.nameNorm == u.nameNorm) {
    score += 20;
  }

  if (p.dobNorm == u.dobNorm) {
    score += 20;
  }

  if (p.fatherName.isNotEmpty &&
      u.fatherName.isNotEmpty &&
      p.fatherNorm == u.fatherNorm) {
    score += 15;
  }

  if (p.motherName.isNotEmpty &&
      u.motherName.isNotEmpty &&
      p.motherNorm == u.motherNorm) {
    score += 10;
  }

  if (p.classCanonValue == u.classIdCanon ||
      p.classCanonValue == u.classDescCanon) {
    score += 10;
  }

  if (p.gender.isNotEmpty &&
      u.gender.isNotEmpty &&
      p.genderNormValue == u.genderNormValue) {
    score += 5;
  }

  if (p.mobileDigits.isNotEmpty &&
      u.mobileDigits.isNotEmpty &&
      p.mobileDigits == u.mobileDigits) {
    score += 5;
  }

  if (p.categoryNorm == u.categoryNorm) {
    score += 5;
  }

  if (p.religionNormValue == u.religionNormValue) {
    score += 5;
  }

  return score;
}

double _nameSimilarity(PspStudent p, UdiseStudent u) {
  final values = <double>[];

  if (u.nameNorm.isNotEmpty) {
    values.add(similarity(p.nameNorm, u.nameNorm));
  }

  if (u.nameUuidNorm.isNotEmpty) {
    values.add(similarity(p.nameNorm, u.nameUuidNorm));
  }

  if (values.isEmpty) return 0;

  return values.reduce((a, b) => a > b ? a : b);
}

MatchEvidence? evaluateEvidence(
  PspStudent p,
  UdiseStudent u,
) {
  final compatible = nameCompatible(
    p.studentName,
    u.studentName,
    alias: u.nameAsUuid,
  );

  if (!compatible) return null;

  final nameSim = _nameSimilarity(p, u);

  final nameExact =
      p.nameNorm == u.nameNorm ||
      (u.nameUuidNorm.isNotEmpty &&
          p.nameNorm == u.nameUuidNorm);

  final dobSame =
      p.dobNorm.isNotEmpty &&
      p.dobNorm == u.dobNorm;

  final mobileSame =
      p.mobileDigits.isNotEmpty &&
      p.mobileDigits == u.mobileDigits;

  final aadhaarSame =
      p.aadhaarLast4.isNotEmpty &&
      p.aadhaarLast4 == u.uuidLast4;

  final classSame =
      p.classCanonValue == u.classIdCanon ||
      p.classCanonValue == u.classDescCanon;

  final genderSame =
      p.genderNormValue.isNotEmpty &&
      p.genderNormValue == u.genderNormValue;

  final fatherSame =
      p.fatherNorm.isNotEmpty &&
      p.fatherNorm == u.fatherNorm;

  final motherSame =
      p.motherNorm.isNotEmpty &&
      p.motherNorm == u.motherNorm;

  final categorySame =
      p.categoryNorm == u.categoryNorm;

  final religionSame =
      p.religionNormValue == u.religionNormValue;

  return MatchEvidence(
    nameExact: nameExact,
    nameSim: nameSim,
    dobSame: dobSame,
    mobileSame: mobileSame,
    aadhaarSame: aadhaarSame,
    classSame: classSame,
    genderSame: genderSame,
    fatherSame: fatherSame,
    motherSame: motherSame,
    categorySame: categorySame,
    religionSame: religionSame,
  );
}

MatchEdge? evaluateMatch(
  int pspIndex,
  int udiseIndex,
  PspStudent p,
  UdiseStudent u,
) {
  final e = evaluateEvidence(p, u);

  if (e == null) return null;

  final parents =
      (e.fatherSame ? 1 : 0) +
      (e.motherSame ? 1 : 0);

  final support =
      (e.mobileSame ? 1 : 0) +
      (e.aadhaarSame ? 1 : 0) +
      (e.classSame ? 1 : 0) +
      (e.genderSame ? 1 : 0) +
      parents;

  var tier = 0;

  if (e.aadhaarSame &&
      (e.dobSame ||
          e.mobileSame ||
          e.classSame ||
          parents >= 1)) {
    tier = 3;
  }

  if (e.nameExact &&
      e.mobileSame &&
      e.classSame &&
      parents >= 1) {
    tier = 3;
  }

  if (e.nameSim >= 0.92 &&
      e.mobileSame &&
      (e.classSame || parents >= 1)) {
    tier = 3;
  }

  if (e.nameExact &&
      e.dobSame &&
      support >= 2) {
    tier = 3;
  }

  if (e.nameSim >= 0.88 &&
      e.dobSame &&
      support >= 2) {
    tier = 3;
  }

  if (tier < 3) {
    if (e.nameExact &&
        e.dobSame &&
        (parents >= 1 ||
            e.mobileSame ||
            e.classSame)) {
      tier = 2;
    } else if (e.nameSim >= 0.90 &&
        e.mobileSame &&
        (e.classSame || parents >= 1)) {
      tier = 2;
    } else if (e.nameSim >= 0.88 &&
        e.dobSame &&
        (e.mobileSame ||
            parents >= 1 ||
            e.classSame)) {
      tier = 2;
    }
  }

  if (tier < 2 &&
      ((e.nameSim >= 0.92 && e.dobSame) ||
          (e.nameSim >= 0.88 && support >= 2))) {
    tier = 1;
  }

  if (tier == 0) return null;

  final calculatedScore =
      (e.nameExact ? 35 : (e.nameSim * 30).round()) +
      (e.dobSame ? 25 : 0) +
      (e.aadhaarSame ? 20 : 0) +
      (e.mobileSame ? 10 : 0) +
      (e.classSame ? 5 : 0) +
      (e.fatherSame ? 4 : 0) +
      (e.motherSame ? 4 : 0) +
      (e.genderSame ? 2 : 0);

  return MatchEdge(
    pspIndex: pspIndex,
    udiseIndex: udiseIndex,
    evidence: e,
    tier: tier,
    score: calculatedScore,
  );
}

List<ComparisonRow> runMatchingEngine(
  List<PspStudent> psp,
  List<UdiseStudent> udise,
) {
  final udiseByAadhaar = <String, List<int>>{};
  final udiseByInitial = <String, List<int>>{};

  for (var ui = 0; ui < udise.length; ui++) {
    final u = udise[ui];

    if (u.uuidLast4.isNotEmpty) {
      udiseByAadhaar
          .putIfAbsent(u.uuidLast4, () => [])
          .add(ui);
    }

    final name = u.nameNorm;

    if (name.isNotEmpty) {
      final initial = name.substring(0, 1);

      udiseByInitial
          .putIfAbsent(initial, () => [])
          .add(ui);
    }
  }

  final edges = <MatchEdge>[];

  for (var pi = 0; pi < psp.length; pi++) {
    final p = psp[pi];
    final candidates = <int>{};

    if (p.aadhaarLast4.isNotEmpty) {
      candidates.addAll(
        udiseByAadhaar[p.aadhaarLast4] ?? const [],
      );
    }

    if (p.nameNorm.isNotEmpty) {
      final initial = p.nameNorm.substring(0, 1);

      candidates.addAll(
        udiseByInitial[initial] ?? const [],
      );
    }

    for (final ui in candidates) {
      final edge = evaluateMatch(
        pi,
        ui,
        p,
        udise[ui],
      );

      if (edge != null) {
        edges.add(edge);
      }
    }
  }

  edges.sort((a, b) {
    final tierCompare = b.tier.compareTo(a.tier);

    if (tierCompare != 0) {
      return tierCompare;
    }

    final scoreCompare = b.score.compareTo(a.score);

    if (scoreCompare != 0) {
      return scoreCompare;
    }

    return b.evidence.nameSim
        .compareTo(a.evidence.nameSim);
  });

  final usedPsp = <int>{};
  final usedUdise = <int>{};

  final rows = <ComparisonRow>[];

  for (final edge in edges) {
    if (usedPsp.contains(edge.pspIndex) ||
        usedUdise.contains(edge.udiseIndex)) {
      continue;
    }

    usedPsp.add(edge.pspIndex);
    usedUdise.add(edge.udiseIndex);

    final p = psp[edge.pspIndex];
    final u = udise[edge.udiseIndex];

    final diffs = compareStudents(p, u);

    final type =
        hasCoreIdentityMismatch(diffs)
            ? MatchType.mismatch
            : MatchType.matched;

    rows.add(
      ComparisonRow(
        psp: p,
        udise: u,
        type: type,
        diffs: diffs,
        score: exactScore(p, u),
        matchTier: edge.tier,
      ),
    );
  }

  final globallyMatchedPsp = <int>{};
  final globallyMatchedUdise = <int>{};

  for (final row in rows) {
    if (row.psp != null) {
      final index = psp.indexOf(row.psp!);
      if (index >= 0) {
        globallyMatchedPsp.add(index);
      }
    }

    if (row.udise != null) {
      final index = udise.indexOf(row.udise!);
      if (index >= 0) {
        globallyMatchedUdise.add(index);
      }
    }
  }

  for (var pi = 0; pi < psp.length; pi++) {
    if (globallyMatchedPsp.contains(pi)) continue;

    final p = psp[pi];
    final candidates = <MatchEdge>[];

    final candidateIndices = <int>{};

    if (p.aadhaarLast4.isNotEmpty) {
      candidateIndices.addAll(
        udiseByAadhaar[p.aadhaarLast4] ?? const [],
      );
    }

    if (p.nameNorm.isNotEmpty) {
      final initial = p.nameNorm.substring(0, 1);

      candidateIndices.addAll(
        udiseByInitial[initial] ?? const [],
      );
    }

    for (final ui in candidateIndices) {
      if (globallyMatchedUdise.contains(ui)) continue;

      final edge = evaluateMatch(
        pi,
        ui,
        p,
        udise[ui],
      );

      if (edge != null) {
        candidates.add(edge);
      }
    }

    candidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      return b.evidence.nameSim
          .compareTo(a.evidence.nameSim);
    });

    if (candidates.isNotEmpty) {
      final best = candidates.first;
      final secondScore =
          candidates.length > 1
              ? candidates[1].score
              : -1;

      if (best.score >= 70 &&
          (secondScore < 0 ||
              best.score - secondScore >= 12)) {
        final u = udise[best.udiseIndex];
        final diffs = compareStudents(p, u);

        rows.add(
          ComparisonRow(
            psp: p,
            udise: u,
            type: MatchType.possibleMatch,
            diffs: [
              'REVIEW_MATCH',
              ...diffs,
            ],
            score: exactScore(p, u),
            matchTier: best.tier,
          ),
        );

        globallyMatchedUdise.add(best.udiseIndex);
        continue;
      }
    }

    rows.add(
      ComparisonRow(
        psp: p,
        udise: null,
        type: MatchType.notInUdise,
        diffs: const [
          'PSP_BUT_NOT_IN_UDISE',
        ],
        score: 0,
        matchTier: 0,
      ),
    );
  }

  for (var ui = 0; ui < udise.length; ui++) {
    if (globallyMatchedUdise.contains(ui)) continue;

    rows.add(
      ComparisonRow(
        psp: null,
        udise: udise[ui],
        type: MatchType.notInPsp,
        diffs: const [
          'UDISE_BUT_NOT_IN_PSP',
        ],
        score: 0,
        matchTier: 0,
      ),
    );
  }

  rows.sort((a, b) {
    final aClass = a.psp?.classCanonValue ??
        a.udise?.classDescCanon ??
        a.udise?.classIdCanon ??
        '';

    final bClass = b.psp?.classCanonValue ??
        b.udise?.classDescCanon ??
        b.udise?.classIdCanon ??
        '';

    final classCompare = aClass.compareTo(bClass);

    if (classCompare != 0) {
      return classCompare;
    }

    final aName = norm(
      a.psp?.studentName ??
          a.udise?.studentName ??
          '',
    );

    final bName = norm(
      b.psp?.studentName ??
          b.udise?.studentName ??
          '',
    );

    return aName.compareTo(bName);
  });

  return rows;
}
