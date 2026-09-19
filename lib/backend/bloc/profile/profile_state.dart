import 'package:equatable/equatable.dart';
import '../../models/user_profile.dart';

enum ProfileStatus { initial, loading, ready, failure }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final UserProfile? profile;
  final String? error;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.error,
  });

  ProfileState copyWith({ProfileStatus? status, UserProfile? profile, String? error}) =>
      ProfileState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        error: error,
      );

  @override
  List<Object?> get props => [status, profile, error];
}
