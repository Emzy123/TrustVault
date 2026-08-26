import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../models/profile.dart';
import '../../shared/state_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile, this.accountNumber});

  final Profile profile;
  final String? accountNumber;

  void _copyAccountNumber(BuildContext context) {
    if (accountNumber == null) return;
    Clipboard.setData(ClipboardData(text: accountNumber!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account number copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = profile.fullName
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(initials),
              const SizedBox(height: 16),
              if (accountNumber != null) _buildAccountNumberCard(context),
              if (profile.accountStatus == AccountStatus.frozen) ...[
                const SizedBox(height: 16),
                const ErrorBanner(
                  message: 'Your account is frozen. All wallet transactions are locked by compliance.',
                ),
              ],
              const SizedBox(height: 28),
              const SectionHeader(title: 'Account Settings'),
              const SizedBox(height: 12),
              PremiumMenuTile(
                title: 'Identity & Verification',
                subtitle: 'View government ID, address, and KYC status',
                icon: Icons.badge_outlined,
                color: AppColors.secondaryBlue,
                onTap: () => context.go('/app/profile/identity'),
              ),
              PremiumMenuTile(
                title: 'Account Limits & Tier',
                subtitle: 'Check transfer limits and upgrade criteria',
                icon: Icons.speed_outlined,
                color: AppColors.accentGold,
                onTap: () => context.go('/app/profile/limits'),
              ),
              PremiumMenuTile(
                title: 'Security & Privacy',
                subtitle: 'Biometrics, 2FA, password, and active sessions',
                icon: Icons.security_outlined,
                color: AppColors.success,
                onTap: () => context.go('/app/profile/security'),
              ),
              PremiumMenuTile(
                title: 'Account Statements',
                subtitle: 'Export monthly or custom transaction reports',
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.primaryNavy,
                onTap: () => context.go('/app/profile/statements'),
              ),
              PremiumMenuTile(
                title: 'Help & Support',
                subtitle: 'Search FAQs or chat with live support assistant',
                icon: Icons.support_agent_outlined,
                color: AppColors.secondaryBlue,
                onTap: () => context.go('/app/profile/support'),
              ),
              const SizedBox(height: 24),
              _buildSignOutButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String initials) {
    final isVerified = profile.accountStatus == AccountStatus.verified ||
        profile.accountStatus == AccountStatus.active;

    return PremiumCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppDecorations.navyGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppDecorations.heroShadow,
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: AppTypography.textTheme.headlineMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isVerified ? AppColors.success : AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Icon(
                  isVerified ? Icons.check_rounded : Icons.hourglass_bottom_rounded,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            profile.fullName,
            style: AppTypography.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(profile.email, style: AppTypography.textTheme.bodySmall),
          if (profile.phone != null) ...[
            const SizedBox(height: 2),
            Text(profile.phone!, style: AppTypography.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              StatusPill(label: profile.levelBadgeTitle, color: AppColors.accentGold),
              StatusPill(
                label: profile.accountStatus.label,
                color: isVerified ? AppColors.success : AppColors.warning,
              ),
              StatusPill(
                label: 'KYC: ${_kycLabel(profile.kycStatus)}',
                color: profile.kycStatus == KycStatus.approved
                    ? AppColors.success
                    : AppColors.secondaryBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountNumberCard(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: InkWell(
        onTap: () => _copyAccountNumber(context),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.secondaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Atlas Account Number', style: AppTypography.overline),
                  const SizedBox(height: 4),
                  Text(
                    formatAccountNumber(accountNumber),
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, color: AppColors.secondaryBlue, size: 20),
              onPressed: () => _copyAccountNumber(context),
              tooltip: 'Copy Account Number',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Sign out'),
            content: const Text('Are you sure you want to sign out of Atlas?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Supabase.instance.client.auth.signOut();
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Sign Out of Account', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  String _kycLabel(KycStatus status) {
    switch (status) {
      case KycStatus.notSubmitted:
        return 'Not submitted';
      case KycStatus.pending:
        return 'Pending review';
      case KycStatus.approved:
        return 'Approved';
      case KycStatus.declined:
        return 'Declined';
    }
  }
}
