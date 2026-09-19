import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/bloc/auth/auth_bloc.dart';
import '../../backend/bloc/auth/auth_event.dart';
import '../../backend/bloc/auth/auth_state.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_config.dart';
import '../../constants/app_responsive.dart';
import '../../constants/app_strings.dart';
import '../../widgets/neon_backdrop.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  void _showServerSettings(BuildContext context, AppPalette p) {
    final ctrl = TextEditingController();
    var invalid = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: p.surface,
          title: const Text('Server address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Currently using:\n${AppConfig.apiBaseUrl}',
                style: GoogleFonts.inter(
                  color: p.textSecondary,
                  fontSize: AppResponsive.font(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppResponsive.h(12)),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'API base URL',
                  hintText: '192.168.0.103:5000',
                  errorText: invalid
                      ? 'Invalid address — use e.g. 192.168.1.20:5000'
                      : null,
                ),
              ),
              SizedBox(height: AppResponsive.h(8)),
              Text(
                'Your PC\'s LAN IP (from ipconfig) with the server port.',
                style: GoogleFonts.inter(
                  color: p.textMuted,
                  fontSize: AppResponsive.font(11),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AppConfig.clearRuntimeBaseUrl();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () async {
                final value = ctrl.text.trim();
                if (value.isEmpty) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  return;
                }
                final saved = await AppConfig.setRuntimeBaseUrl(value);
                if (!saved) {
                  setDialogState(() => invalid = true);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegistrationSheet(BuildContext context, AppPalette p) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final regFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (a, b) =>
              a.error != b.error || a.status != b.status,
          listener: (sheetCtx2, state) {
            if (state.status == AuthStatus.authenticated) {
              Navigator.of(sheetCtx).pop();
              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                const SnackBar(content: Text('Account created. You are signed in.')),
              );
            } else if (state.error != null) {
              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                SnackBar(content: Text(state.error!), backgroundColor: p.loss),
              );
            }
          },
          builder: (sheetCtx2, state) {
            final submitting = state.isSubmitting;
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xE6151A22),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: p.border, width: 0.8)),
              ),
              padding: EdgeInsets.only(
                left: AppResponsive.w(20),
                right: AppResponsive.w(20),
                top: AppResponsive.h(20),
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppResponsive.h(20),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: regFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create your TradeZ account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          color: p.textPrimary,
                          fontSize: AppResponsive.font(20),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(4)),
                      Text(
                        'Fill in the details to register',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: p.textSecondary,
                          fontSize: AppResponsive.font(12),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(20)),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                      ),
                      SizedBox(height: AppResponsive.h(12)),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter your email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      SizedBox(height: AppResponsive.h(12)),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                        validator: (v) => (v == null || v.trim().length < 7) ? 'Enter a valid phone' : null,
                      ),
                      SizedBox(height: AppResponsive.h(12)),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                      SizedBox(height: AppResponsive.h(20)),
                      SizedBox(
                        height: AppResponsive.h(48),
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () {
                                  if (!regFormKey.currentState!.validate()) return;
                                  sheetCtx2.read<AuthBloc>().add(
                                        AuthRegisterRequested(
                                          name: nameCtrl.text.trim(),
                                          email: emailCtrl.text.trim(),
                                          phone: phoneCtrl.text.trim(),
                                          password: passwordCtrl.text,
                                        ),
                                      );
                                },
                          child: submitting
                              ? SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onPrimary),
                                )
                              : const Text('Register'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    AppResponsive.init(context);
    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const Positioned.fill(child: NeonBackdrop()),
          SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (a, b) => a.error != b.error && b.error != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.error ?? 'Login failed'), backgroundColor: p.loss),
              );
          },
          builder: (context, state) {
            final loading = state.isSubmitting;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(22)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Server settings',
                            icon: Icon(Icons.cloud_outlined, color: p.textMuted),
                            onPressed: () => _showServerSettings(context, p),
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          width: AppResponsive.w(96),
                          height: AppResponsive.w(96),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.primary.withValues(alpha: 0.08),
                            border: Border.all(color: p.primary.withValues(alpha: 0.20), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x0F1E2D3C),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(AppResponsive.w(16)),
                          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(24)),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          color: p.textPrimary,
                          fontSize: AppResponsive.font(26),
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(6)),
                      Text(
                        'Sign in to your ${AppStrings.appName} account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: p.textSecondary,
                          fontSize: AppResponsive.font(13),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(28)),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _LabeledField(
                              label: 'Email',
                              child: TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  hintText: 'you@example.com',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(height: AppResponsive.h(14)),
                            _LabeledField(
                              label: 'Password',
                              child: TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: p.textMuted,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(24)),
                      SizedBox(
                        height: AppResponsive.h(52),
                        child: ElevatedButton(
                          key: const ValueKey('sign_in_submit'),
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onPrimary),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                      SizedBox(height: AppResponsive.h(12)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password recovery coming soon')),
                              );
                            },
                            child: const Text('Forgot password?'),
                          ),
                          Text('•', style: TextStyle(color: p.textMuted)),
                          TextButton(
                            onPressed: () => _showRegistrationSheet(context, p),
                            child: const Text('New Registration'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(bottom: AppResponsive.h(16)),
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: p.textMuted,
                            fontSize: AppResponsive.font(11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: AppResponsive.w(4), bottom: AppResponsive.h(6)),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: p.textSecondary,
              fontSize: AppResponsive.font(12),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
