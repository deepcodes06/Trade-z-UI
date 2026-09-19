import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trade_z/backend/bloc/auth/auth_bloc.dart';
import 'package:trade_z/backend/bloc/auth/auth_event.dart';
import 'package:trade_z/backend/bloc/auth/auth_state.dart';

void main() {
  group('AuthBloc (Testing Mode)', () {
    blocTest<AuthBloc, AuthState>(
      'emits [submitting, authenticated] on successful login with any credentials',
      build: () => AuthBloc(),
      act: (b) => b.add(const AuthLoginRequested(
        email: 'alice@example.com',
        password: 'secret123',
      )),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.isSubmitting, 'isSubmitting', true)
            .having((s) => s.error, 'error', null),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated)
            .having((s) => s.user?.email, 'user.email', 'alice@example.com')
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated+error] on login with empty email',
      build: () => AuthBloc(),
      act: (b) => b.add(const AuthLoginRequested(
        email: '',
        password: 'secret123',
      )),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.error, 'error', 'Please enter email and password')
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [submitting, authenticated] on successful registration with any credentials',
      build: () => AuthBloc(),
      act: (b) => b.add(const AuthRegisterRequested(
        name: 'Alice',
        email: 'alice@example.com',
        phone: '9999999999',
        password: 'secret123',
      )),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<AuthState>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.authenticated)
            .having((s) => s.user?.name, 'user.name', 'Alice')
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated+error] on registration with empty name',
      build: () => AuthBloc(),
      act: (b) => b.add(const AuthRegisterRequested(
        name: '',
        email: 'alice@example.com',
        phone: '9999999999',
        password: 'secret123',
      )),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated)
            .having((s) => s.error, 'error', 'Please fill in all required fields')
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] on logout',
      build: () => AuthBloc(),
      seed: () => const AuthState(status: AuthStatus.authenticated),
      act: (b) => b.add(const AuthLogoutRequested()),
      expect: () => [
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.unauthenticated),
      ],
    );
  });
}
