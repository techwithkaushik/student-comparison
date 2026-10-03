import 'package:flutter_bloc/flutter_bloc.dart';
import '../database/database.dart';

enum AppStatus { initializing, ready, failure }

class AppState {
  final AppStatus status;
  final String? error;
  const AppState({this.status = AppStatus.initializing, this.error});

  AppState copyWith({AppStatus? status, String? error}) =>
      AppState(status: status ?? this.status, error: error);
}

class AppCubit extends Cubit<AppState> {
  final AppDatabase database;
  AppCubit({AppDatabase? database})
      : database = database ?? AppDatabase.instance,
        super(const AppState());

  Future<void> initialize() async {
    emit(const AppState(status: AppStatus.initializing));
    try {
      await database.database;
      if (!isClosed) emit(const AppState(status: AppStatus.ready));
    } catch (e) {
      if (!isClosed) {
        emit(AppState(
          status: AppStatus.failure,
          error: 'Database initialization failed: $e',
        ));
      }
    }
  }

  Future<void> retry() => initialize();
}
