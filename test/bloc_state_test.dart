import 'package:flutter_test/flutter_test.dart';
import 'package:student_comparison/bloc/comparison_bloc.dart';
import 'package:student_comparison/data/repositories/comparison_repository.dart';
import 'package:student_comparison/data/repositories/school_repository.dart';
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

      final state = ComparisonState.derive(
        rows: [matched, mismatch],
        filter: 'MATCHED',
        classFilter: '',
        search: '',
        searchActive: false,
        remarks: const {},
      );

      expect(state.filteredRows, [matched]);
      expect(state.countType(MatchType.mismatch), 1);
      expect(state.countDiff('NAME_MISMATCH'), 1);
    });

    test('diff filter toggles through Bloc events', () async {
      final bloc = ComparisonBloc(
        repository: ComparisonRepository(),
        schoolRepository: SchoolRepository(),
      );
      addTearDown(bloc.close);

      bloc.add(const ComparisonDiffFilterToggled('NAME_MISMATCH'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filter, 'DIFF:NAME_MISMATCH');

      bloc.add(const ComparisonDiffFilterToggled('NAME_MISMATCH'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.filter, 'ALL');
    });
  });
}
