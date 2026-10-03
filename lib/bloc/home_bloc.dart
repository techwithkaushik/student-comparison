import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/school_repository.dart';

enum HomeStatus { initial, loading, ready, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<Map<String, dynamic>> profiles;
  final String? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.profiles = const [],
    this.error,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<Map<String, dynamic>>? profiles,
    String? error,
    bool clearError = false,
  }) =>
      HomeState(
        status: status ?? this.status,
        profiles: profiles ?? this.profiles,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, profiles, error];
}

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

final class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}

final class HomeProfileSaved extends HomeEvent {
  final String? id;
  final String schoolName;
  final String pspCode;
  final String udiseCode;
  const HomeProfileSaved({
    this.id,
    required this.schoolName,
    required this.pspCode,
    required this.udiseCode,
  });
  @override
  List<Object?> get props => [id, schoolName, pspCode, udiseCode];
}

final class HomeProfileDeleted extends HomeEvent {
  final String profileId;
  const HomeProfileDeleted(this.profileId);
  @override
  List<Object?> get props => [profileId];
}

final class HomeProfileSelected extends HomeEvent {
  final String profileId;
  const HomeProfileSelected(this.profileId);
  @override
  List<Object?> get props => [profileId];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SchoolRepository _repository;

  HomeBloc({required SchoolRepository repository})
      : _repository = repository,
        super(const HomeState()) {
    on<HomeLoadRequested>(_onLoad);
    on<HomeProfileSaved>(_onSave);
    on<HomeProfileDeleted>(_onDelete);
    on<HomeProfileSelected>(_onSelect);
  }

  Future<void> _onLoad(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading, clearError: true));
    try {
      final profiles = await _repository.getProfiles();
      emit(state.copyWith(
        status: HomeStatus.ready,
        profiles: profiles
            .map((row) => Map<String, dynamic>.unmodifiable(row))
            .toList(growable: false),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'School profiles could not be loaded: $e',
      ));
    }
  }

  Future<void> _onSave(
    HomeProfileSaved event,
    Emitter<HomeState> emit,
  ) async {
    try {
      await _repository.saveProfile(
        id: event.id,
        schoolName: event.schoolName,
        pspCode: event.pspCode,
        udiseCode: event.udiseCode,
      );
      add(const HomeLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'Could not save profile: $e',
      ));
    }
  }

  Future<void> _onDelete(
    HomeProfileDeleted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      await _repository.deleteProfile(event.profileId);
      add(const HomeLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'Could not delete profile: $e',
      ));
    }
  }

  Future<void> _onSelect(
    HomeProfileSelected event,
    Emitter<HomeState> emit,
  ) async {
    try {
      await _repository.setActiveProfile(event.profileId);
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'Could not select school profile: $e',
      ));
    }
  }
}
