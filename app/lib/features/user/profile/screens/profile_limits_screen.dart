import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/premium_widgets.dart';
import '../../../../models/profile.dart';

class ProfileLimitsScreen extends StatelessWidget {
  const ProfileLimitsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return ProfileSubScreenScaffold(
      title: 'Account Tier & Limits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCurrentTierCard(context),
          const SizedBox(height: 20),
          _buildLimitProgressCard(),
          const SizedBox(height: 20),
          _buildTierMatrixCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentTierCard(BuildContext context) {
    final verified = profile.hasCompletedAnyKyc;

    return Container(
      decoration: AppDecorations.heroCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusPill(
                label: verified ? profile.levelBadgeTitle.toUpperCase() : 'UNVERIFIED',
                color: AppColors.accentGold,
              ),
              const Icon(Icons.stars_rounded, color: AppColors.accentGold, size: 28),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            verified ? 'Verified wallet access' : 'Identity not verified yet',
            style: AppTypography.textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.tierLimitDescription,
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.75),
            ),
          ),
          if (!verified) ...[
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.primaryNavy,
              ),
              onPressed: () => context.go('/app/kyc'),
              child: const Text('Start Level 1 verification'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitProgressCard() {
    final dailyLimit = profile.dailyTransferLimit;
    final singleLimit = dailyLimit > 0 ? (dailyLimit * 0.25).clamp(500.0, dailyLimit) : 0.0;
    final withdrawalLimit = dailyLimit > 0 ? (dailyLimit * 0.2).clamp(200.0, dailyLimit) : 0.0;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transaction limits', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            dailyLimit <= 0
                ? 'Transfers stay locked until you complete Level 1 (Tier 1).'
                : 'Limits reset every 24 hours based on your verification level.',
            style: AppTypography.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _buildMeter(
            label: 'Daily transfer limit',
            used: 0,
            total: dailyLimit,
            color: AppColors.secondaryBlue,
          ),
          const SizedBox(height: 20),
          _buildMeter(
            label: 'Single transfer maximum',
            used: 0,
            total: singleLimit,
            color: AppColors.accentGold,
          ),
          const SizedBox(height: 20),
          _buildMeter(
            label: 'Daily withdrawal limit',
            used: 0,
            total: withdrawalLimit,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildMeter({
    required String label,
    required double used,
    required double total,
    required Color color,
  }) {
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${formatCurrency(used)} / ${formatCurrency(total)}',
              style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.neutralLightGrey,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTierMatrixCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verification levels', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'New accounts start unverified. Complete each level to raise your daily limits.',
            style: AppTypography.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildTierRow(
            'Unverified',
            '\$0 / day',
            'Registered only — no transfers until ID check',
            active: profile.kycLevel == 0,
          ),
          const Divider(height: 24),
          _buildTierRow(
            'Level 1 · Tier 1',
            '\$5,000 / day',
            'Government-issued ID approved',
            active: profile.kycLevel == 1,
          ),
          const Divider(height: 24),
          _buildTierRow(
            'Level 2 · Tier 2',
            '\$20,000 / day',
            'Live face match against your ID',
            active: profile.kycLevel == 2,
          ),
          const Divider(height: 24),
          _buildTierRow(
            'Level 3 · Tier 3',
            '\$100,000 / day',
            'Proof of address on file',
            active: profile.kycLevel >= 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(
    String tier,
    String limit,
    String features, {
    bool active = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tier,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.secondaryBlue : null,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    const StatusPill(label: 'CURRENT', color: AppColors.secondaryBlue),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(features, style: AppTypography.textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          limit,
          style: AppTypography.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
