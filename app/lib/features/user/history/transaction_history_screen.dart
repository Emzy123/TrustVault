import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('History', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                if (loading && transactions.isEmpty)
                  const Card(child: TransactionListSkeleton())
                else if (error != null)
                  ErrorBanner(message: error!)
                else if (transactions.isEmpty)
                  Card(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      message: 'Transfers, funding, and withdrawals will appear here.',
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: transactions
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
    final theme = Theme.of(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: ErrorBanner(message: error!));
    }

    final tx = transaction;
    if (tx == null) {
      return const Center(child: Text('Transaction not found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(tx.type.label, style: theme.textTheme.headlineMedium),
                      const Spacer(),
                      StatusChip(status: tx.status),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _DetailRow(
                    label: 'Amount',
                    value: '${tx.isIncoming ? '+' : '-'}${formatNaira(tx.amount)}',
                  ),
                  _DetailRow(label: 'Date', value: formatDate(tx.createdAt)),
                  if (tx.note != null && tx.note!.isNotEmpty)
                    _DetailRow(label: 'Note', value: tx.note!),
                  if (tx.declineReason != null && tx.declineReason!.isNotEmpty)
                    _DetailRow(label: 'Reason', value: tx.declineReason!),
                  if (tx.status == TransactionStatus.pending &&
                      tx.type == TransactionType.withdrawal) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'This withdrawal is under review. You will see the real outcome here when resolved.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final tx = transaction;
    final prefix = tx.isIncoming ? '+' : '-';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.neutralLightGrey,
        child: Icon(_iconForType(tx.type), color: AppColors.secondaryBlue, size: 20),
      ),
      title: Text('${tx.type.label}${tx.isIncoming ? ' received' : ''}'),
      subtitle: Text(formatDate(tx.createdAt), style: theme.textTheme.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$prefix${formatNaira(tx.amount)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: tx.isIncoming ? AppColors.success : AppColors.primaryNavy,
            ),
          ),
          StatusChip(status: tx.status, compact: true),
        ],
      ),
    );
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.deposit:
        return Icons.south_west;
      case TransactionType.withdrawal:
        return Icons.north_east;
      case TransactionType.funding:
        return Icons.add_card;
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
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10 : null,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
