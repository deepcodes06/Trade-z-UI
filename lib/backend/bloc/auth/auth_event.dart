import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String phone;
  final String password;
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });
  @override
  List<Object?> get props => [name, email, phone, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Fired once when the app starts: restores the session from the token (and
/// cached user profile) persisted on this device, so returning users skip the
/// login screen — even without network.
class AuthRestoreRequested extends AuthEvent {
  const AuthRestoreRequested();
}
