import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/app_repository.dart';

enum AppStatus { initializing, ready, failure }

class AppState extends Equatable {
  final AppStatus status;
  final String? error;

  const AppState({
    this.status = AppStatus.initializing,
    this.error,
  });

  AppState copyWith({AppStatus? status, String? error, bool clearError = false}) =>
      AppState(
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, error];
}

sealed class AppEvent extends Equatable {
  const AppEvent();
  @override
  List<Object?> get props => [];
}

final class AppStarted extends AppEvent {
  const AppStarted();
}

final class AppRetryRequested extends AppEvent {
  const AppRetryRequested();
}

class AppBloc extends Bloc<AppEvent, AppState> {
  final AppRepository _repository;

  AppBloc({required AppRepository repository})
      : _repository = repository,
        super(const AppState()) {
    on<AppStarted>(_onInitialize);
    on<AppRetryRequested>(_onInitialize);
  }

  Future<void> _onInitialize(
    AppEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(const AppState(status: AppStatus.initializing));
    try {
      await _repository.initialize();
      emit(const AppState(status: AppStatus.ready));
    } catch (e) {
      emit(AppState(
        status: AppStatus.failure,
        error: 'Database initialization failed: $e',
      ));
    }
  }
}
