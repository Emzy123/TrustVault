import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_typography.dart';
import 'responsive_layout.dart';

/// Responsive auth layout with branded hero panel on wide screens.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.heroTagline = 'Bank-grade security.\nSeamless digital wealth.',
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final String heroTagline;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                Expanded(child: _HeroPanel(tagline: heroTagline)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: _FormColumn(
                        title: title,
                        subtitle: subtitle,
                        footer: footer,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: AppDecorations.pageBackground,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        _MobileBrandHeader(),
                        const SizedBox(height: 32),
                        PremiumCard(
                          child: _FormColumn(
                            title: title,
                            subtitle: subtitle,
                            footer: footer,
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppDecorations.authPanelGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png', height: 44),
                      const SizedBox(width: 14),
                      Text(
                        'TrustVault',
                        style: AppTypography.textTheme.headlineMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    tagline,
                    style: AppTypography.textTheme.displayMedium?.copyWith(
                      color: AppColors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Secure digital banking for individuals and institutions.',
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _TrustBadge(icon: Icons.verified_user_outlined, label: '256-bit encryption'),
                      _TrustBadge(icon: Icons.account_balance_outlined, label: 'Licensed demo'),
                      _TrustBadge(icon: Icons.speed_outlined, label: 'Instant transfers'),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '© ${DateTime.now().year} TrustVault · Demo environment',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentGoldLight),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: AppDecorations.cardShadow,
          ),
          child: Image.asset('assets/images/logo.png', height: 56),
        ),
        const SizedBox(height: 16),
        Text(
          'TrustVault',
          style: AppTypography.textTheme.displayMedium?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          'Secure Digital Banking',
          style: AppTypography.overline.copyWith(color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey)),
          const SizedBox(height: 28),
          child,
          if (footer != null) ...[
            const SizedBox(height: 24),
            footer!,
          ],
        ],
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key, required this.child, this.padding = const EdgeInsets.all(28)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.glassCard(),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTypography.textTheme.titleLarge),
        const Spacer(),
        if (action != null)
          action!
        else if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.lockReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final String? lockReason;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: enabled ? AppColors.white : AppColors.neutralLightGrey,
      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: context.isMobile ? 14 : 18,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(color: AppColors.borderGrey),
            boxShadow: enabled ? AppDecorations.cardShadow : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.secondaryBlue.withValues(alpha: 0.1)
                      : AppColors.textMuted.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  enabled ? icon : Icons.lock_outline,
                  color: enabled ? AppColors.secondaryBlue : AppColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!enabled && lockReason != null) {
      return Tooltip(message: lockReason!, child: content);
    }
    return content;
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = AppColors.secondaryBlue,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AppTypography.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class BalanceHeroCard extends StatelessWidget {
  const BalanceHeroCard({
    super.key,
    required this.balanceLabel,
    required this.balance,
    required this.subtitle,
    this.trailing,
  });

  final String balanceLabel;
  final String balance;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = context.isMobile;

    return Container(
      decoration: AppDecorations.heroCard(),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: compact ? 100 : 140,
              height: compact ? 100 : 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        balanceLabel.toUpperCase(),
                        style: AppTypography.overline.copyWith(
                          color: AppColors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    balance,
                    style: AppTypography.balance.copyWith(fontSize: compact ? 32 : 42),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
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

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.pageBackground,
      child: child,
    );
  }
}

/// Page title block for inner screens (transfer, profile, etc.).
class FormPageHeader extends StatelessWidget {
  const FormPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.textTheme.headlineMedium?.copyWith(
              fontSize: context.isMobile ? 22 : null,
            )),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );

    if (context.isMobile && trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          trailing!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Consistent shell for profile sub-screens with back navigation.
class ProfileSubScreenScaffold extends StatelessWidget {
  const ProfileSubScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.backPath = '/app/profile',
  });

  final String title;
  final Widget child;
  final String backPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(backPath),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderGrey),
        ),
      ),
      body: PageScaffold(
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Header row for admin queue and oversight screens.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.textTheme.headlineMedium?.copyWith(
                    fontSize: context.isMobile ? 22 : null,
                  )),
                  const SizedBox(height: 6),
                  Text(subtitle, style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            IconButton.filledTonal(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ],
    );
  }
}

/// Info callout banner for admin screens.
class AdminInfoBanner extends StatelessWidget {
  const AdminInfoBanner({super.key, required this.message, this.icon = Icons.info_outline_rounded});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryNavy),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTypography.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Tappable menu row for profile and settings screens.
class PremiumMenuTile extends StatelessWidget {
  const PremiumMenuTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              border: Border.all(color: AppColors.borderGrey),
              boxShadow: AppDecorations.cardShadow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypography.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Key-value row for confirmation and detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: emphasize
                  ? AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
                  : AppTypography.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
