import 'package:flutter_test/flutter_test.dart';
import 'package:student_comparison/screens/comparison_screen.dart';

void main() {
  test('PSP filename uses normalized uppercase school code', () {
    expect(
      expectedSourceJsonFileName(psp: true, code: 'p12345'),
      'psp_p12345.json',
    );
    expect(
      expectedSourceJsonFileName(psp: true, code: 'P12345'),
      'psp_P12345.json',
    );
  });

  test('UDISE filename preserves leading zeroes', () {
    expect(
      expectedSourceJsonFileName(psp: false, code: '01234567890'),
      'udise_01234567890.json',
    );
  });
}
