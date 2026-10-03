import 'package:flutter_test/flutter_test.dart';

import 'package:student_comparison/bloc/print_bloc.dart';
import 'package:student_comparison/data/repositories/print_repository.dart';
import 'package:student_comparison/printing/native_print_service.dart';

void main() {
  group('PrintSettings', () {
    test('restores legacy single margin into all four sides', () {
      final settings = PrintSettings.fromMap({
        'paper': 'A4',
        'orientation': 'landscape',
        'margin': 7,
        'fontSize': 11,
      });

      expect(settings.marginTop, 7);
      expect(settings.marginRight, 7);
      expect(settings.marginBottom, 7);
      expect(settings.marginLeft, 7);
      expect(settings.fontSize, 11);
    });

    test('round-trips independent margins', () {
      final original = const PrintSettings(
        marginTop: 2,
        marginRight: 4,
        marginBottom: 6,
        marginLeft: 8,
        autoFit: false,
        repeatHeader: true,
        pageNumber: false,
      );

      final restored = PrintSettings.fromMap(original.toMap());

      expect(restored, original);
    });
  });

  group('PrintSettingsBloc', () {
    test('keeps all page setup changes in Bloc state and clamps margins', () async {
      final bloc = PrintSettingsBloc(
        repository: PrintRepository(),
        initial: const PrintSettings(),
      );
      addTearDown(bloc.close);

      bloc.setMarginTop(100);
      bloc.setMarginRight(-10);
      bloc.setMarginBottom(12);
      bloc.setMarginLeft(3);
      bloc.setAutoFit(false);
      bloc.setPageNumber(false);

      await pumpEventQueue();

      expect(bloc.state.marginTop, 50);
      expect(bloc.state.marginRight, 0);
      expect(bloc.state.marginBottom, 12);
      expect(bloc.state.marginLeft, 3);
      expect(bloc.state.autoFit, isFalse);
      expect(bloc.state.pageNumber, isFalse);
    });
  });
}
