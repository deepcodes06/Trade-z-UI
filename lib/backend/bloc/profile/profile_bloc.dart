import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../backend/api/profile_api.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileApi _api;
  ProfileBloc({ProfileApi? api}) : _api = api ?? ProfileApi.instance, super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoad);
    on<ProfileLogoutRequested>((e, emit) => emit(const ProfileState()));
  }

  Future<void> _onLoad(ProfileLoadRequested e, Emitter<ProfileState> emit) async {
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final profile = await _api.fetchProfile();
      emit(state.copyWith(status: ProfileStatus.ready, profile: profile));
    } catch (error) {
      emit(state.copyWith(
        status: ProfileStatus.failure,
        error: error.toString(),
      ));
    }
  }
}
