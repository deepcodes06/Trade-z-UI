import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/bloc/auth/auth_bloc.dart';
import '../../backend/bloc/auth/auth_event.dart';
import '../../backend/bloc/profile/profile_bloc.dart';
import '../../backend/bloc/profile/profile_event.dart';
import '../../backend/bloc/profile/profile_state.dart';
import '../../backend/bloc/portfolio/portfolio_bloc.dart';
import '../../backend/bloc/portfolio/portfolio_event.dart';
import '../../backend/bloc/portfolio/portfolio_state.dart';
import '../../backend/models/user_profile.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileBloc>().add(const ProfileLoadRequested());
      context.read<PortfolioBloc>().add(const PortfolioLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state.status == ProfileStatus.loading || state.profile == null) {
          return Center(child: CircularProgressIndicator(color: AppPalette.of(context).primary));
        }
        final p = state.profile!;
        return ListView(
          padding: EdgeInsets.only(bottom: AppResponsive.h(24)),
          children: [
            SizedBox(height: AppResponsive.h(8)),
            _HeaderCard(profile: p),
            SizedBox(height: AppResponsive.h(14)),
            _OverallPortfolioCard(),
            SizedBox(height: AppResponsive.h(14)),
            _LogoutCard(),
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserProfile profile;
  const _HeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = profile.name;
    final phone = profile.phone;
    final initials = name.isEmpty
        ? 'U'
        : name.split(' ').where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).take(2).join();
    return Container(
      margin: AppResponsive.symH(16).add(EdgeInsets.only(top: AppResponsive.h(8))),
      padding: AppResponsive.padAll(18),
      decoration: BoxDecoration(
        color: const Color(0x66151A22), // translucent dark glass
        borderRadius: BorderRadius.circular(AppResponsive.w(20)),
        border: Border.all(
          color: const Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: AppResponsive.w(56),
            height: AppResponsive.w(56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: p.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              initials,
              style: GoogleFonts.spaceGrotesk(
                color: p.onPrimary,
                fontSize: AppResponsive.font(20),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: AppResponsive.w(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.spaceGrotesk(
                    color: p.textPrimary,
                    fontSize: AppResponsive.font(18),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: AppResponsive.h(3)),
                Text(
                  phone.isEmpty ? 'No phone number' : phone,
                  style: GoogleFonts.inter(
                    color: p.textSecondary,
                    fontSize: AppResponsive.font(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the user's overall portfolio worth (how much money they have in the
/// market right now) using the live PortfolioBloc holdings.
class _OverallPortfolioCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<PortfolioBloc, PortfolioState>(
      builder: (context, state) {
        final invested = state.totalInvested;
        final current = state.totalCurrentValue;
        final pnl = state.totalPnl;
        final pnlColor = state.totalPnlPositive ? p.gain : p.loss;
        return Container(
          margin: AppResponsive.symH(16),
          padding: AppResponsive.padAll(18),
          decoration: BoxDecoration(
            color: const Color(0x66151A22),
            borderRadius: BorderRadius.circular(AppResponsive.w(20)),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
            boxShadow: [
              BoxShadow(color: const Color(0x66000000), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Portfolio',
                style: GoogleFonts.inter(
                  color: p.textMuted,
                  fontSize: AppResponsive.font(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppResponsive.h(6)),
              Text(
                '₹${_fmt(current)}',
                style: GoogleFonts.spaceGrotesk(
                  color: p.textPrimary,
                  fontSize: AppResponsive.font(28),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: AppResponsive.h(12)),
              Row(
                children: [
                  Expanded(
                    child: _Pill(
                      label: 'Invested',
                      value: '₹${_fmt(invested)}',
                      p: p,
                    ),
                  ),
                  SizedBox(width: AppResponsive.w(10)),
                  Expanded(
                    child: _Pill(
                      label: 'P&L',
                      value: '${pnl >= 0 ? '+' : ''}₹${_fmt(pnl)}',
                      sub: '${state.totalPnlPct >= 0 ? '+' : ''}${state.totalPnlPct.toStringAsFixed(2)}%',
                      color: pnlColor,
                      p: p,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(double v) => v.abs().toStringAsFixed(2);
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  final AppPalette p;

  const _Pill({required this.label, required this.value, this.sub, this.color, required this.p});

  @override
  Widget build(BuildContext context) {
    final c = color ?? p.textPrimary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(14), vertical: AppResponsive.h(10)),
      decoration: BoxDecoration(
        color: p.softHighlight,
        borderRadius: BorderRadius.circular(AppResponsive.w(12)),
        border: Border.all(color: p.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11), fontWeight: FontWeight.w500),
          ),
          SizedBox(height: AppResponsive.h(2)),
          Text(
            value,
            style: GoogleFonts.inter(color: c, fontSize: AppResponsive.font(15), fontWeight: FontWeight.w700),
          ),
          if (sub != null) ...[
            SizedBox(height: AppResponsive.h(2)),
            Text(
              sub!,
              style: GoogleFonts.inter(color: c, fontSize: AppResponsive.font(11), fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: AppResponsive.symH(16),
      decoration: BoxDecoration(
        color: const Color(0x66151A22),
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        onTap: () {
          context.read<AuthBloc>().add(const AuthLogoutRequested());
          context.read<ProfileBloc>().add(const ProfileLogoutRequested());
        },
        child: Padding(
          padding: AppResponsive.symH(16).add(
            EdgeInsets.symmetric(vertical: AppResponsive.h(14)),
          ),
          child: Row(
            children: [
              Icon(Icons.logout, color: p.loss, size: AppResponsive.w(20)),
              SizedBox(width: AppResponsive.w(12)),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  color: p.loss,
                  fontSize: AppResponsive.font(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}