import 'package:flutter_test/flutter_test.dart';
import 'package:student_comparison/bloc/comparison_bloc.dart';
import 'package:student_comparison/matching/models.dart';

void main() {
  group('ComparisonState', () {
    test('filters matched rows', () {
      final matched = ComparisonRow(
        type: MatchType.matched,
        score: 100,
        psp: null,
        udise: null,
        diffs: const [],
        matchTier: 1,
      );
      final mismatch = ComparisonRow(
        type: MatchType.mismatch,
        score: 80,
        psp: null,
        udise: null,
        diffs: const ['NAME_MISMATCH'],
        matchTier: 1,
      );

      final state = ComparisonState(
        rows: [matched, mismatch],
        filter: 'MATCHED',
      );

      expect(state.filteredRows, [matched]);
      expect(state.countType(MatchType.mismatch), 1);
      expect(state.countDiff('NAME_MISMATCH'), 1);
    });

    test('diff filter toggles through Cubit state', () {
      final cubit = ComparisonBloc();
      addTearDown(cubit.close);

      cubit.toggleDiffFilter('NAME_MISMATCH');
      expect(cubit.state.filter, 'DIFF:NAME_MISMATCH');

      cubit.toggleDiffFilter('NAME_MISMATCH');
      expect(cubit.state.filter, 'ALL');
    });
  });
}
