import 'package:flutter_test/flutter_test.dart';
import 'package:student_comparison/main.dart';

void main() {
  testWidgets('application compiles and can build the root widget', (tester) async {
    await tester.pumpWidget(const StudentComparisonApp());
    expect(find.byType(StudentComparisonApp), findsOneWidget);
  });
}
