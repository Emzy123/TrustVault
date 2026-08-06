import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);
    final profile = widget.profile;
    final eligibility = WalletEligibility(profile: profile);
    final balance = widget.account?.balance ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        await _loadRecent();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile.kycStatus == KycStatus.notSubmitted ||
                    profile.kycStatus == KycStatus.declined)
                  _OnboardingBanner(profile: profile),
                if (profile.kycStatus == KycStatus.pending) ...[
                  Card(
                    color: AppColors.secondaryBlue.withValues(alpha: 0.06),
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top, color: AppColors.secondaryBlue),
                      title: const Text('Verification in progress'),
                      subtitle: const Text('We will notify you when review is complete.'),
                      trailing: TextButton(
                        onPressed: () => context.go('/app/kyc/pending'),
                        child: const Text('View status'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Wallet balance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textGrey,
                              ),
                            ),
                            const Spacer(),
                            _StatusBadge(label: profile.accountStatus.label),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(formatNaira(balance), style: theme.textTheme.displayLarge),
                        const SizedBox(height: 8),
                        Text(
                          widget.account == null
                              ? 'Account unavailable'
                              : 'Account ${widget.account!.accountNumber} · Available ${formatNaira(widget.availableBalance)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _AccountLevelCard(profile: profile),
                const SizedBox(height: 24),
                Text('Quick actions', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ActionButton(
                      label: 'Request funding',
                      icon: Icons.add_card_outlined,
                      enabled: eligibility.canRequestFunding,
                      lockReason: eligibility.fundingLockReason,
                      onPressed: () => context.go('/app/funding'),
                    ),
                    _ActionButton(
                      label: 'Transfer',
                      icon: Icons.swap_horiz,
                      enabled: eligibility.canTransfer,
                      lockReason: eligibility.transferLockReason,
                      onPressed: () => context.go('/app/transfer'),
                    ),
                    _ActionButton(
                      label: 'Withdraw',
                      icon: Icons.account_balance_wallet_outlined,
                      enabled: eligibility.canWithdraw,
                      lockReason: eligibility.withdrawLockReason,
                      onPressed: () => context.go('/app/withdraw'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Text('Recent activity', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    if (_recent.isNotEmpty)
                      TextButton(
                        onPressed: () => context.go('/app/history'),
                        child: const Text('View all'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: _loadingRecent
                      ? const TransactionListSkeleton()
                      : _recent.isEmpty
                          ? EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              message:
                                  'Your activity will appear here once you start using your wallet.',
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
}

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: AppColors.primaryNavy,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.kycStatus == KycStatus.declined
                    ? 'Verification required'
                    : 'Complete verification',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: 8),
              Text(
                profile.kycStatus == KycStatus.declined
                    ? 'Your previous submission was declined. Please resubmit your details.'
                    : 'Verify your identity to unlock funding and wallet features.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryBlue,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.lockReason,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final String lockReason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Tooltip(
        message: lockReason,
        child: OutlinedButton.icon(onPressed: null, icon: Icon(icon), label: Text(label)),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _AccountLevelCard extends StatelessWidget {
  const _AccountLevelCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = profile.kycLevel;

    return Card(
      color: AppColors.primaryNavy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.accentGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      profile.levelBadgeTitle,
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/app/kyc'),
                  child: Text(
                    level >= 3 ? 'Max Level Reached' : 'Upgrade Level',
                    style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Transfer Limit',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
                ),
                Text(
                  profile.formattedDailyLimit,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (level / 3.0).clamp(0.1, 1.0),
                backgroundColor: AppColors.white.withValues(alpha: 0.15),
                color: AppColors.accentGold,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
