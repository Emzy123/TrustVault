import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
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
        content: Text('Account number copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = profile.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(context, theme, initials),
              const SizedBox(height: 20),
              if (accountNumber != null) _buildAccountNumberCard(context, theme),
              if (profile.accountStatus == AccountStatus.frozen) ...[
                const SizedBox(height: 16),
                const ErrorBanner(
                  message: 'Your account is frozen. All wallet transactions are locked by compliance.',
                ),
              ],
              const SizedBox(height: 24),
              Text('Account Settings & Features', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildMenuTile(
                context,
                title: 'Identity & Verification',
                subtitle: 'View government ID, address, and KYC status',
                icon: Icons.badge_outlined,
                color: AppColors.secondaryBlue,
                path: '/app/profile/identity',
              ),
              _buildMenuTile(
                context,
                title: 'Account Limits & Tier',
                subtitle: 'Check transfer limits and upgrade criteria',
                icon: Icons.speed_outlined,
                color: AppColors.accentGold,
                path: '/app/profile/limits',
              ),
              _buildMenuTile(
                context,
                title: 'Security & Privacy',
                subtitle: 'Biometrics, 2FA, password, and active sessions',
                icon: Icons.security_outlined,
                color: AppColors.success,
                path: '/app/profile/security',
              ),
              _buildMenuTile(
                context,
                title: 'Account Statements',
                subtitle: 'Export monthly or custom transaction reports',
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.primaryNavy,
                path: '/app/profile/statements',
              ),
              _buildMenuTile(
                context,
                title: 'Help & Support',
                subtitle: 'Search FAQs or chat with live support assistant',
                icon: Icons.support_agent_outlined,
                color: AppColors.secondaryBlue,
                path: '/app/profile/support',
              ),
              const SizedBox(height: 24),
              _buildSignOutCard(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ThemeData theme, String initials) {
    final isVerified = profile.accountStatus == AccountStatus.verified ||
        profile.accountStatus == AccountStatus.active;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primaryNavy,
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isVerified ? AppColors.success : AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: Icon(
                    isVerified ? Icons.check : Icons.hourglass_bottom,
                    size: 16,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              profile.fullName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              profile.email,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            if (profile.phone != null) ...[
              const SizedBox(height: 2),
              Text(
                profile.phone!,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                AppStatusBadge(
                  label: profile.levelBadgeTitle,
                  color: AppColors.accentGold,
                ),
                AppStatusBadge(
                  label: profile.accountStatus.label,
                  color: isVerified ? AppColors.success : AppColors.warning,
                ),
                AppStatusBadge(
                  label: 'KYC: ${_kycLabel(profile.kycStatus)}',
                  color: profile.kycStatus == KycStatus.approved
                      ? AppColors.success
                      : AppColors.secondaryBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountNumberCard(BuildContext context, ThemeData theme) {
    return Card(
      color: AppColors.surfaceLight,
      child: InkWell(
        onTap: () => _copyAccountNumber(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.secondaryBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TrustVault Account Number', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      accountNumber!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.primaryNavy,
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
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String path,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
        onTap: () => context.go(path),
      ),
    );
  }

  Widget _buildSignOutCard(BuildContext context, ThemeData theme) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Sign out'),
            content: const Text('Are you sure you want to sign out of TrustVault?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
      icon: const Icon(Icons.logout),
      label: const Text('Sign Out of Account', style: TextStyle(fontWeight: FontWeight.bold)),
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
