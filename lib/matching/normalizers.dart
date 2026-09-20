import 'dart:math' as math;

String clean(dynamic value) {
  return (value ?? '').toString().trim();
}

String norm(dynamic value) {
  var s = clean(value).toUpperCase();

  // Similar to JS NFKD normalization.
  s = s
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return s;
}

String digits(dynamic value) {
  return clean(value).replaceAll(RegExp(r'\D'), '');
}

String last4(dynamic value) {
  final d = digits(value);
  if (d.isEmpty) return '';
  return d.length <= 4 ? d : d.substring(d.length - 4);
}

String normalizeDob(dynamic value) {
  var s = clean(value);
  if (s.isEmpty) return '';

  s = s.replaceAll('.', '/').replaceAll('-', '/');

  final parts = s.split('/');
  if (parts.length != 3) return s;

  final day = parts[0].padLeft(2, '0');
  final month = parts[1].padLeft(2, '0');
  final year = parts[2];

  return '$day/$month/$year';
}

int? classNum(dynamic value) {
  final x = norm(value)
      .replaceFirst(RegExp(r'^(CLASS|GRADE)\s*'), '')
      .replaceAll('.', '')
      .trim();

  const map = <String, int>{
    'PREPRIMARY': 0,
    'NURSERY': 0,
    'KG': 0,
    'LKG': 0,
    'UKG': 0,

    'FIRST': 1,
    'SECOND': 2,
    'THIRD': 3,
    'FOURTH': 4,
    'FIFTH': 5,
    'SIXTH': 6,
    'SEVENTH': 7,

    // Class 8
    'EIGHT': 8,
    'EIGHTH': 8,
    'VIII': 8,

    'NINTH': 9,
    'TENTH': 10,
    'ELEVENTH': 11,
    'TWELFTH': 12,

    // Roman numerals
    'I': 1,
    'II': 2,
    'III': 3,
    'IV': 4,
    'V': 5,
    'VI': 6,
    'VII': 7,
    'IX': 9,
    'X': 10,
    'XI': 11,
    'XII': 12,
  };

  final numeric = double.tryParse(x);
  if (numeric != null &&
      numeric == numeric.truncateToDouble()) {
    return numeric.toInt();
  }

  final mapped = map[x];
  if (mapped != null) {
    return mapped;
  }

  final ordinal = RegExp(
    r'^(\d{1,2})(ST|ND|RD|TH)?$',
  ).firstMatch(x);

  if (ordinal != null) {
    return int.tryParse(ordinal.group(1)!);
  }

  return null;
}

String classCanon(dynamic value) {
  final n = classNum(value);
  return n == null ? norm(value) : n.toString();
}

String genderNorm(dynamic value) {
  final s = norm(value);

  if (s == '1' || s == 'MALE' || s == 'M') {
    return 'MALE';
  }

  if (s == '2' || s == 'FEMALE' || s == 'F') {
    return 'FEMALE';
  }

  return s;
}

String socialCatNorm(dynamic value) {
  final s = norm(value);

  switch (s) {
    case 'GENERAL':
    case '1':
      return 'GENERAL';

    case 'SC':
    case '2':
      return 'SC';

    case 'ST':
    case '3':
      return 'ST';

    case 'OBC':
    case '4':
      return 'OBC';

    case 'SBC':
    case '5':
      return 'SBC';

    default:
      return s;
  }
}

String religionNorm(dynamic value) {
  final s = norm(value);

  switch (s) {
    case 'MUSLIM':
    case '1':
      return 'MUSLIM';

    case 'CHRISTIAN':
    case '2':
      return 'CHRISTIAN';

    case 'SIKH':
    case '3':
      return 'SIKH';

    case 'BUDDHIST':
    case '4':
      return 'BUDDHIST';

    case 'PARSI':
    case '5':
      return 'PARSI';

    case 'JAIN':
    case '6':
      return 'JAIN';

    case 'HINDU':
    case 'NON MINORITY':
    case '7':
    case 'NA':
    case '':
      return 'HINDU';

    default:
      return s;
  }
}

double similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;

  var longer = a;
  var shorter = b;

  if (longer.length < shorter.length) {
    final tmp = longer;
    longer = shorter;
    shorter = tmp;
  }

  final lenA = longer.length;
  final lenB = shorter.length;

  var previous = List<int>.generate(lenB + 1, (i) => i);
  var current = List<int>.filled(lenB + 1, 0);

  for (var i = 1; i <= lenA; i++) {
    current[0] = i;

    for (var j = 1; j <= lenB; j++) {
      final cost = longer.codeUnitAt(i - 1) == shorter.codeUnitAt(j - 1)
          ? 0
          : 1;

      current[j] = math.min(
        math.min(
          current[j - 1] + 1,
          previous[j] + 1,
        ),
        previous[j - 1] + cost,
      );
    }

    final tmp = previous;
    previous = current;
    current = tmp;
  }

  return 1 - previous[lenB] / lenA;
}

bool nameCompatible(
  String a,
  String b, {
  String alias = '',
}) {
  final x = norm(a);
  final variants = <String>[
    norm(b),
    norm(alias),
  ].where((v) => v.isNotEmpty).toSet();

  if (x.isEmpty || variants.isEmpty) return false;

  final xTokens = x.split(' ');

  for (final variant in variants) {
    if (x == variant) return true;

    final yTokens = variant.split(' ');

    if (xTokens.length <= yTokens.length) {
      final allContained = xTokens.every(
        (token) => yTokens.any(
          (other) =>
              other == token ||
              (token.length >= 3 && other.contains(token)),
        ),
      );

      if (allContained) return true;
    }

    if (yTokens.length <= xTokens.length) {
      final allContained = yTokens.every(
        (token) => xTokens.any(
          (other) =>
              other == token ||
              (token.length >= 3 && other.contains(token)),
        ),
      );

      if (allContained) return true;
    }

    if (xTokens.length == 1 && yTokens.length == 1) {
      if (similarity(xTokens[0], yTokens[0]) >= 0.75) {
        return true;
      }
    }

    if (xTokens.length == yTokens.length) {
      final compatible = List.generate(
        xTokens.length,
        (i) => similarity(xTokens[i], yTokens[i]) >= 0.80,
      ).every((v) => v);

      if (compatible) return true;
    }
  }

  return false;
}
