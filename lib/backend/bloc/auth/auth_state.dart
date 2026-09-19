import 'package:equatable/equatable.dart';

import '../../api/auth_api.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? error;
  final AuthUser? user;
  final bool isSubmitting;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.error,
    this.user,
    this.isSubmitting = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    AuthUser? user,
    bool? isSubmitting,
  }) =>
      AuthState(
        status: status ?? this.status,
        error: error,
        user: user ?? this.user,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );

  @override
  List<Object?> get props => [status, error, user, isSubmitting];
}
