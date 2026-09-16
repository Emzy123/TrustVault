import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/premium_widgets.dart';

/// Settings hub matching the Atlas sample bottom-nav tab.
class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Settings'),
              const SizedBox(height: 4),
              Text(
                'Manage security, limits, statements, and support.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 20),
              PremiumMenuTile(
                title: 'Security & Privacy',
                subtitle: 'Password, sessions, and account protection',
                icon: Icons.security_outlined,
                color: AppColors.success,
                onTap: () => context.go('/app/profile/security'),
              ),
              PremiumMenuTile(
                title: 'Account Limits & Tier',
                subtitle: 'Transfer limits and verification upgrades',
                icon: Icons.speed_outlined,
                color: AppColors.accentGold,
                onTap: () => context.go('/app/profile/limits'),
              ),
              PremiumMenuTile(
                title: 'Account Statements',
                subtitle: 'Export monthly or custom reports',
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.primaryNavy,
                onTap: () => context.go('/app/profile/statements'),
              ),
              PremiumMenuTile(
                title: 'Help & Support',
                subtitle: 'FAQs and live support assistant',
                icon: Icons.support_agent_outlined,
                color: AppColors.secondaryBlue,
                onTap: () => context.go('/app/profile/support'),
              ),
              PremiumMenuTile(
                title: 'Notifications',
                subtitle: 'Push and email preferences',
                icon: Icons.notifications_outlined,
                color: AppColors.secondaryBlue,
                onTap: () {},
              ),
              PremiumMenuTile(
                title: 'Appearance',
                subtitle: 'Theme and display preferences',
                icon: Icons.palette_outlined,
                color: AppColors.accentGold,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
