import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/auth_api.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthApi? api})
      : _api = api ?? AuthApi.instance,
        super(const AuthState(status: AuthStatus.unknown)) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthRestoreRequested>(_onRestore);
    // Kick off the session restore as soon as the bloc is created, so the
    // splash screen is followed by the right page on the first frame.
    add(const AuthRestoreRequested());
  }

  final AuthApi _api;

  Future<void> _onLogin(AuthLoginRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      isSubmitting: true,
      error: null,
    ));
    if (e.email.trim().isEmpty || e.password.isEmpty) {
      emit(state.copyWith(
        error: 'Please enter email and password',
        isSubmitting: false,
      ));
      return;
    }
    try {
      final result = await _api.login(email: e.email.trim(), password: e.password);
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        isSubmitting: false,
        error: null,
      ));
    } on AuthApiException catch (err) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        error: err.message,
        isSubmitting: false,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Could not reach server: $err',
        isSubmitting: false,
      ));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      isSubmitting: true,
      error: null,
    ));
    if (e.name.trim().isEmpty || e.email.trim().isEmpty || e.password.isEmpty) {
      emit(state.copyWith(
        error: 'Please fill in all required fields',
        isSubmitting: false,
      ));
      return;
    }
    if (e.password.length < 6) {
      emit(state.copyWith(
        error: 'Password must be at least 6 characters',
        isSubmitting: false,
      ));
      return;
    }
    try {
      final result = await _api.register(
        name: e.name.trim(),
        email: e.email.trim(),
        phone: e.phone.trim().isEmpty ? null : e.phone.trim(),
        password: e.password,
      );
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: result.user,
        isSubmitting: false,
        error: null,
      ));
    } on AuthApiException catch (err) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        error: err.message,
        isSubmitting: false,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Could not reach server: $err',
        isSubmitting: false,
      ));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested e, Emitter<AuthState> emit) async {
    try {
      await _api.logout();
    } catch (_) {
      // Even if the server-side revoke fails, we still want to forget the
      // locally-stored token so the user is logged out of the app.
    }
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// Restore the session on app launch from the token + per-token user cache
  /// stored on this device. Offline-friendly: if the token exists we treat the
  /// user as authenticated. Only clears the session if there is genuinely no
  /// stored token (i.e. a manual logout happened).
  Future<void> _onRestore(
    AuthRestoreRequested e,
    Emitter<AuthState> emit,
  ) async {
    try {
      final token = await _api.getStoredToken();
      // ignore: avoid_print
      print('[AUTH-RESTORE] token=${token == null ? "NULL" : (token.isEmpty ? "EMPTY" : "present len=${token.length}")}');
      if (token == null || token.isEmpty) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
        return;
      }
      final cached = await _api.cachedUserForToken(token);
      // ignore: avoid_print
      print('[AUTH-RESTORE] cachedUser=${cached == null ? "NULL" : cached.email}');
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          user: cached ??
              const AuthUser(id: '', name: 'Loading…', email: ''),
        ),
      );
      // ignore: avoid_print
      print('[AUTH-RESTORE] emitted authenticated');
    } catch (err) {
      // ignore: avoid_print
      print('[AUTH-RESTORE] ERROR: $err');
      // If secure storage is unavailable, fall back to logged-out so the user
      // can always log in again.
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }
}
