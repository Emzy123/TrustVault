import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/wallet_eligibility.dart';
import '../../models/profile.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_models.dart';
import '../../services/wallet_service.dart';
import '../shared/state_widgets.dart';
import 'history/transaction_history_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({
    super.key,
    required this.profile,
    required this.account,
    required this.availableBalance,
    required this.onRefresh,
  });

  final Profile profile;
  final WalletAccount? account;
  final double availableBalance;
  final Future<void> Function() onRefresh;

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  List<WalletTransaction> _recent = [];
  bool _loadingRecent = true;
  RealtimeChannel? _txChannel;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _txChannel = Supabase.instance.client
        .channel('public:transactions:user')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (_) {
            if (mounted) _loadRecent();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _txChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UserDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account?.id != widget.account?.id ||
        oldWidget.availableBalance != widget.availableBalance) {
      _loadRecent();
    }
  }

  Future<void> _loadRecent() async {
    final accountId = widget.account?.id;
    if (accountId == null) {
      setState(() => _loadingRecent = false);
      return;
    }

    setState(() => _loadingRecent = true);
    try {
      final items = await WalletService(Supabase.instance.client)
          .fetchRecentTransactions(accountId: accountId, limit: 5);
      if (mounted) setState(() => _recent = items);
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final eligibility = WalletEligibility(profile: profile);
    final balance = widget.account?.balance ?? 0;
    final greeting = _greetingForTime();

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        await _loadRecent();
      },
      color: AppColors.secondaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.pagePadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hi, ${profile.fullName.split(' ').first}',
                  style: AppTypography.textTheme.headlineMedium?.copyWith(
                    fontSize: context.isMobile ? 22 : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s an overview of your vault today.',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                ),
                const SizedBox(height: 24),
                if (profile.kycStatus == KycStatus.notSubmitted ||
                    profile.kycStatus == KycStatus.declined)
                  _OnboardingBanner(profile: profile),
                if (profile.kycStatus == KycStatus.pending) ...[
                  _InfoStrip(
                    icon: Icons.hourglass_top_rounded,
                    title: 'Verification in progress',
                    subtitle: 'We\'ll notify you when review is complete.',
                    actionLabel: 'View status',
                    onAction: () => context.go('/app/kyc/pending'),
                  ),
                  const SizedBox(height: 16),
                ],
                BalanceHeroCard(
                  balanceLabel: 'Total balance',
                  balance: formatNaira(balance),
                  subtitle: widget.account == null
                      ? 'Account unavailable'
                      : 'Acct ${formatAccountNumber(widget.account!.accountNumber)} · Available ${formatNaira(widget.availableBalance)}',
                  trailing: StatusPill(label: profile.accountStatus.label),
                ),
                const SizedBox(height: 16),
                _AccountLevelCard(profile: profile),
                const SizedBox(height: 28),
                SectionHeader(title: 'Quick actions'),
                const SizedBox(height: 14),
                QuickActionGrid(
                  children: [
                    QuickActionTile(
                      label: 'Fund',
                      icon: Icons.add_card_outlined,
                      enabled: eligibility.canRequestFunding,
                      lockReason: eligibility.fundingLockReason,
                      onTap: () => context.go('/app/funding'),
                    ),
                    QuickActionTile(
                      label: 'Transfer',
                      icon: Icons.swap_horiz_rounded,
                      enabled: eligibility.canTransfer,
                      lockReason: eligibility.transferLockReason,
                      onTap: () => context.go('/app/transfer'),
                    ),
                    QuickActionTile(
                      label: 'Withdraw',
                      icon: Icons.account_balance_wallet_outlined,
                      enabled: eligibility.canWithdraw,
                      lockReason: eligibility.withdrawLockReason,
                      onTap: () => context.go('/app/withdraw'),
                    ),
                    QuickActionTile(
                      label: 'Verify',
                      icon: Icons.verified_user_outlined,
                      enabled: true,
                      onTap: () => context.go('/app/kyc'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SectionHeader(
                  title: 'Recent activity',
                  actionLabel: _recent.isNotEmpty ? 'View all' : null,
                  onAction: _recent.isNotEmpty ? () => context.go('/app/history') : null,
                ),
                const SizedBox(height: 12),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: _loadingRecent
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: TransactionListSkeleton(),
                        )
                      : _recent.isEmpty
                          ? EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              message: 'Your activity will appear here once you start using your wallet.',
                            )
                          : Column(
                              children: _recent
                                  .map((tx) => TransactionTile(
                                        transaction: tx,
                                        onTap: () => context.go('/app/history/${tx.id}'),
                                      ))
                                  .toList(),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greetingForTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: AppDecorations.heroCard(),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.accentGoldLight, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    profile.kycStatus == KycStatus.declined
                        ? 'Verification required'
                        : 'Complete verification',
                    style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                profile.kycStatus == KycStatus.declined
                    ? 'Your previous submission was declined. Please resubmit your details.'
                    : 'Verify your identity to unlock funding and wallet features.',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/app/kyc'),
                child: Text(profile.kycStatus == KycStatus.declined ? 'Resubmit KYC' : 'Start verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final compact = context.isMobile;

    return PremiumCard(
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: 14),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.secondaryBlue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTypography.textTheme.titleMedium?.copyWith(fontSize: 15)),
                          Text(subtitle, style: AppTypography.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onAction, child: Text(actionLabel)),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.secondaryBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.textTheme.titleMedium?.copyWith(fontSize: 15)),
                      Text(subtitle, style: AppTypography.textTheme.bodySmall),
                    ],
                  ),
                ),
                TextButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
    );
  }
}

class _AccountLevelCard extends StatelessWidget {
  const _AccountLevelCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final level = profile.kycLevel;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppDecorations.goldShimmer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.primaryNavy, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile.levelBadgeTitle,
                  style: AppTypography.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/app/kyc'),
                child: Text(
                  level >= 3 ? 'Max level' : 'Upgrade',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily transfer limit', style: AppTypography.textTheme.bodySmall),
              Text(
                profile.formattedDailyLimit,
                style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (level / 3.0).clamp(0.08, 1.0),
              backgroundColor: AppColors.borderGrey,
              color: AppColors.accentGold,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
