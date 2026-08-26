import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../models/wallet_models.dart';
import '../../shared/state_widgets.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({
    super.key,
    required this.transactions,
    required this.loading,
    this.error,
    required this.onRefresh,
  });

  final List<WalletTransaction> transactions;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.secondaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormPageHeader(
                  title: 'History',
                  subtitle: 'All transfers, funding, and withdrawals',
                ),
                const SizedBox(height: 20),
                if (loading && transactions.isEmpty)
                  PremiumCard(child: const TransactionListSkeleton())
                else if (error != null)
                  ErrorBanner(message: error!)
                else if (transactions.isEmpty)
                  PremiumCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      message: 'Transfers, funding, and withdrawals will appear here.',
                    ),
                  )
                else
                  PremiumCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        for (var i = 0; i < transactions.length; i++) ...[
                          TransactionTile(
                            transaction: transactions[i],
                            onTap: () => context.go('/app/history/${transactions[i].id}'),
                          ),
                          if (i < transactions.length - 1)
                            Divider(
                              height: 1,
                              indent: 72,
                              color: AppColors.borderGrey.withValues(alpha: 0.6),
                            ),
                        ],
                      ],
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

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.loading = false,
    this.error,
  });

  final WalletTransaction? transaction;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue));
    }

    if (error != null) {
      return Center(child: ErrorBanner(message: error!));
    }

    final tx = transaction;
    if (tx == null) {
      return const Center(child: Text('Transaction not found'));
    }

    final prefix = tx.isIncoming ? '+' : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormPageHeader(
                title: tx.type.label,
                trailing: StatusChip(status: tx.status),
              ),
              const SizedBox(height: 20),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppDecorations.navyGradient,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      child: Column(
                        children: [
                          Icon(_iconForType(tx.type), color: AppColors.white.withValues(alpha: 0.8), size: 28),
                          const SizedBox(height: 12),
                          Text(
                            '$prefix${formatNaira(tx.amount)}',
                            style: AppTypography.balance.copyWith(
                              color: tx.isIncoming ? AppColors.accentGoldLight : AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tx.isIncoming ? 'Received' : 'Sent',
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    DetailRow(label: 'Date', value: formatDate(tx.createdAt)),
                    DetailRow(label: 'Status', value: tx.status.label),
                    if (tx.note != null && tx.note!.isNotEmpty) DetailRow(label: 'Note', value: tx.note!),
                    if (tx.declineReason != null && tx.declineReason!.isNotEmpty)
                      DetailRow(label: 'Reason', value: tx.declineReason!),
                    if (tx.status == TransactionStatus.pending && tx.type == TransactionType.withdrawal) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondaryBlue.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          'This withdrawal is under review. You will see the real outcome here when resolved.',
                          style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.secondaryBlue),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.deposit:
        return Icons.south_west_rounded;
      case TransactionType.withdrawal:
        return Icons.north_east_rounded;
      case TransactionType.funding:
        return Icons.add_card_rounded;
    }
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final WalletTransaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final prefix = tx.isIncoming ? '+' : '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconColor(tx.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForType(tx.type), color: _iconColor(tx.type), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tx.type.label}${tx.isIncoming ? ' received' : ''}',
                      style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(formatDate(tx.createdAt), style: AppTypography.textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${formatNaira(tx.amount)}',
                    style: AppTypography.textTheme.titleSmall?.copyWith(
                      color: tx.isIncoming ? AppColors.success : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusChip(status: tx.status, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _iconColor(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return AppColors.secondaryBlue;
      case TransactionType.deposit:
      case TransactionType.funding:
        return AppColors.success;
      case TransactionType.withdrawal:
        return AppColors.accentGold;
    }
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.deposit:
        return Icons.south_west_rounded;
      case TransactionType.withdrawal:
        return Icons.north_east_rounded;
      case TransactionType.funding:
        return Icons.add_card_rounded;
    }
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final TransactionStatus status;
  final bool compact;

  Color get _color {
    switch (status) {
      case TransactionStatus.pending:
        return AppColors.secondaryBlue;
      case TransactionStatus.completed:
        return AppColors.success;
      case TransactionStatus.declined:
        return AppColors.error;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.label,
        style: AppTypography.textTheme.bodySmall?.copyWith(
          color: _color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 10 : null,
        ),
      ),
    );
  }
}
