import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/profile.dart';

class ProfileLimitsScreen extends StatelessWidget {
  const ProfileLimitsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = profile.accountStatus == AccountStatus.verified ||
        profile.accountStatus == AccountStatus.active;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Tier & Limits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/profile'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentTierCard(theme, isVerified),
                const SizedBox(height: 24),
                _buildLimitProgressCard(theme, isVerified),
                const SizedBox(height: 24),
                _buildTierMatrixCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTierCard(ThemeData theme, bool isVerified) {
    return Card(
      color: AppColors.primaryNavy,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentGold),
                  ),
                  child: Text(
                    isVerified ? 'TIER 2 VERIFIED WALLET' : 'TIER 1 UNVERIFIED',
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Icon(Icons.stars, color: AppColors.accentGold, size: 28),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              isVerified ? 'Full Access Granted' : 'Restricted Access',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVerified
                  ? 'Your identity is confirmed. Enjoy up to \$1,000,000 daily transaction limits.'
                  : 'Complete government ID verification to upgrade to Tier 2 limits.',
              style: TextStyle(color: AppColors.white.withValues(alpha: 0.8), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitProgressCard(ThemeData theme, bool isVerified) {
    final dailyLimit = isVerified ? 1000000.0 : 0.0;
    final singleLimit = isVerified ? 250000.0 : 0.0;
    final withdrawalLimit = isVerified ? 200000.0 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction Limits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            _buildMeter(
              label: 'Daily Transfer Limit',
              used: isVerified ? 150000 : 0,
              total: dailyLimit,
              color: AppColors.secondaryBlue,
            ),
            const SizedBox(height: 20),
            _buildMeter(
              label: 'Single Transfer Maximum',
              used: isVerified ? 25000 : 0,
              total: singleLimit,
              color: AppColors.accentGold,
            ),
            const SizedBox(height: 20),
            _buildMeter(
              label: 'Daily Withdrawal Limit',
              used: isVerified ? 20000 : 0,
              total: withdrawalLimit,
              color: AppColors.success,
            ),
          ],
        ),
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(
              '${formatNaira(used)} / ${formatNaira(total)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTierMatrixCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tier Structure Overview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildTierRow('Tier 1 (Unverified)', '\$0 Daily Limit', 'View dashboard only'),
            const Divider(),
            _buildTierRow('Tier 2 (Verified)', '\$1,000,000 Daily Limit', 'Transfers & Funding'),
            const Divider(),
            _buildTierRow('Tier 3 (Institutional)', 'Unlimited', 'Priority Compliance & API'),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String tier, String limit, String features) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(features, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
          Text(limit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
