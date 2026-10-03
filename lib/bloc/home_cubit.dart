import 'package:flutter_bloc/flutter_bloc.dart';
import '../database/database.dart';

enum HomeStatus { initial, loading, ready, failure }

class HomeState {
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
  }) {
    return HomeState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeCubit extends Cubit<HomeState> {
  final AppDatabase database;

  HomeCubit({AppDatabase? database})
      : database = database ?? AppDatabase.instance,
        super(const HomeState());

  Future<void> load() async {
    emit(state.copyWith(status: HomeStatus.loading, clearError: true));
    try {
      final profiles = await database.getSchoolProfiles();
      emit(state.copyWith(status: HomeStatus.ready, profiles: profiles));
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'School profiles could not be loaded: $e',
      ));
    }
  }

  Future<void> saveProfile({
    String? id,
    required String schoolName,
    required String pspCode,
    required String udiseCode,
  }) async {
    try {
      await database.saveSchoolProfile(
        id: id,
        schoolName: schoolName,
        pspCode: pspCode,
        udiseCode: udiseCode,
      );
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'Could not save profile: $e',
      ));
      rethrow;
    }
  }

  Future<void> deleteProfile(String profileId) async {
    try {
      await database.deleteSchoolProfile(profileId);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'Could not delete profile: $e',
      ));
      rethrow;
    }
  }

  Future<void> selectProfile(String profileId) {
    return database.setActiveSchoolProfile(profileId);
  }

  void setError(String message) => emit(state.copyWith(status: HomeStatus.failure, error: message));
  void clearError() => emit(state.copyWith(clearError: true));
}
