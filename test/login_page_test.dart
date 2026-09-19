import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:trade_z/backend/bloc/auth/auth_bloc.dart';
import 'package:trade_z/backend/bloc/auth/auth_event.dart';
import 'package:trade_z/backend/bloc/auth/auth_state.dart';
import 'package:trade_z/screens/auth/login_page.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late _MockAuthBloc bloc;

  setUpAll(() {
    registerFallbackValue(const AuthLoginRequested(
      email: '',
      password: '',
    ));
  });

  setUp(() {
    bloc = _MockAuthBloc();
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthState(),
    );
  });

  testWidgets('renders the Sign In button and email + password fields',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('dispatches AuthLoginRequested on submit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@example.com'),
      'alice@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '••••••••'),
      'secret123',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.whereType<AuthLoginRequested>(), isNotEmpty);
    final ev = captured.whereType<AuthLoginRequested>().first;
    expect(ev.email, 'alice@example.com');
    expect(ev.password, 'secret123');
  });

  testWidgets('exposes the requested widget key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('sign_in_submit')),
      findsOneWidget,
    );
  });
}
