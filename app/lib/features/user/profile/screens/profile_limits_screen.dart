import 'package:flutter/material.dart';

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
    final isVerified = profile.accountStatus == AccountStatus.verified ||
        profile.accountStatus == AccountStatus.active;

    return ProfileSubScreenScaffold(
      title: 'Account Tier & Limits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCurrentTierCard(isVerified),
          const SizedBox(height: 20),
          _buildLimitProgressCard(isVerified),
          const SizedBox(height: 20),
          _buildTierMatrixCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentTierCard(bool isVerified) {
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
                label: isVerified ? 'TIER 2 VERIFIED WALLET' : 'TIER 1 UNVERIFIED',
                color: AppColors.accentGold,
              ),
              const Icon(Icons.stars_rounded, color: AppColors.accentGold, size: 28),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isVerified ? 'Full Access Granted' : 'Restricted Access',
            style: AppTypography.textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isVerified
                ? 'Your identity is confirmed. Enjoy up to \$1,000,000 daily transaction limits.'
                : 'Complete government ID verification to upgrade to Tier 2 limits.',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitProgressCard(bool isVerified) {
    final dailyLimit = isVerified ? 1000000.0 : 0.0;
    final singleLimit = isVerified ? 250000.0 : 0.0;
    final withdrawalLimit = isVerified ? 200000.0 : 0.0;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transaction Limits', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: 20),
          _buildMeter(label: 'Daily Transfer Limit', used: isVerified ? 150000 : 0, total: dailyLimit, color: AppColors.secondaryBlue),
          const SizedBox(height: 20),
          _buildMeter(label: 'Single Transfer Maximum', used: isVerified ? 25000 : 0, total: singleLimit, color: AppColors.accentGold),
          const SizedBox(height: 20),
          _buildMeter(label: 'Daily Withdrawal Limit', used: isVerified ? 20000 : 0, total: withdrawalLimit, color: AppColors.success),
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
            Text(label, style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${formatNaira(used)} / ${formatNaira(total)}', style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
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
          Text('Tier Structure Overview', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildTierRow('Tier 1 (Unverified)', '\$0 Daily Limit', 'View dashboard only'),
          const Divider(height: 24),
          _buildTierRow('Tier 2 (Verified)', '\$1,000,000 Daily Limit', 'Transfers & Funding'),
          const Divider(height: 24),
          _buildTierRow('Tier 3 (Institutional)', 'Unlimited', 'Priority Compliance & API'),
        ],
      ),
    );
  }

  Widget _buildTierRow(String tier, String limit, String features) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tier, style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(features, style: AppTypography.textTheme.bodySmall),
            ],
          ),
        ),
        Text(limit, style: AppTypography.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
