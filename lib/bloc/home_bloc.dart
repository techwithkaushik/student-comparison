import 'dart:async';

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
  final Completer<void>? completer;
  const HomeLoadRequested({this.completer});
}

final class HomeProfileSaved extends HomeEvent {
  final String? id;
  final String schoolName;
  final String pspCode;
  final String udiseCode;
  final Completer<void>? completer;
  const HomeProfileSaved({
    this.id,
    required this.schoolName,
    required this.pspCode,
    required this.udiseCode,
    this.completer,
  });
  @override
  List<Object?> get props => [id, schoolName, pspCode, udiseCode];
}

final class HomeProfileDeleted extends HomeEvent {
  final String profileId;
  final Completer<void>? completer;
  const HomeProfileDeleted(this.profileId, {this.completer});
  @override
  List<Object?> get props => [profileId];
}

final class HomeProfileSelected extends HomeEvent {
  final String profileId;
  final Completer<void>? completer;
  const HomeProfileSelected(this.profileId, {this.completer});
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
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.complete();
    } catch (e, st) {
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.completeError(e, st);
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
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.complete();
      add(const HomeLoadRequested());
    } catch (e, st) {
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.completeError(e, st);
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
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.complete();
      add(const HomeLoadRequested());
    } catch (e, st) {
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.completeError(e, st);
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
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.complete();
    } catch (e, st) {
      if (event.completer != null && !event.completer!.isCompleted) event.completer!.completeError(e, st);
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'Could not select school profile: $e',
      ));
    }
  }
}
  Future<void> load() {
    final completer = Completer<void>();
    add(HomeLoadRequested(completer: completer));
    return completer.future;
  }

  Future<void> saveProfile({
    String? id,
    required String schoolName,
    required String pspCode,
    required String udiseCode,
  }) {
    final completer = Completer<void>();
    add(HomeProfileSaved(id: id, schoolName: schoolName, pspCode: pspCode, udiseCode: udiseCode, completer: completer));
    return completer.future;
  }

  Future<void> deleteProfile(String profileId) {
    final completer = Completer<void>();
    add(HomeProfileDeleted(profileId, completer: completer));
    return completer.future;
  }

  Future<void> selectProfile(String profileId) {
    final completer = Completer<void>();
    add(HomeProfileSelected(profileId, completer: completer));
    return completer.future;
  }

