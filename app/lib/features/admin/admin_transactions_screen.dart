import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/wallet_models.dart';
import '../../services/admin_service.dart';
import '../../services/wallet_service.dart';
import '../shared/state_widgets.dart';
import '../user/history/transaction_history_screen.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isInitial = _transactions.isEmpty;
    if (isInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await AdminService(Supabase.instance.client).fetchTransactions();
      if (mounted) {
        setState(() {
          _transactions = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && isInitial) setState(() => _error = 'Failed to load transactions');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _raiseFlag(String transactionId) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raise Flag on Transaction'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason for flag',
            hintText: 'e.g. Suspicious transfer velocity or high amount',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Raise Flag'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final reason = controller.text.trim();
    if (reason.isEmpty) return;

    try {
      await AdminService(Supabase.instance.client).raiseFlag(
        transactionId: transactionId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flag raised and escalated to Super Admin'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapRpcError(e))),
        );
      }
    }
  }

  Future<void> _reviewWithdrawal(String transactionId, bool approve) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decline Withdrawal'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Decline reason',
              hintText: 'e.g. Identity verification pending',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Decline'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      reason = controller.text.trim();
      if (reason.isEmpty) reason = 'Declined by admin during transaction review';
    }

    try {
      await AdminService(Supabase.instance.client).reviewWithdrawal(
        transactionId: transactionId,
        approve: approve,
        declineReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Withdrawal approved & released' : 'Withdrawal declined'),
            backgroundColor: approve ? AppColors.success : AppColors.error,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapRpcError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
          sliver: SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Transaction Monitor',
              subtitle: 'Live feed of all wallet transfers, funding, deposits, and withdrawals',
              onRefresh: _load,
            ),
          ),
        ),
        if (_loading && _transactions.isEmpty)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue)))
        else if (_error != null && _transactions.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: ErrorBanner(message: _error!)))
        else if (_transactions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: PremiumCard(
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions recorded',
                  message: 'Platform transactions will appear here as users move funds.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _transactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                final profile = tx['profiles'] as Map<String, dynamic>?;
                final userEmail = profile?['email'] as String? ?? 'User';
                final amount = (tx['amount'] as num).toDouble();
                final type = tx['type'] as String;
                final statusRaw = tx['status'] as String;
                final status = TransactionStatus.fromString(statusRaw);
                final txId = tx['id'] as String;
                final createdAt = DateTime.parse(tx['created_at'] as String);
                final isPendingWithdrawal = type == 'withdrawal' && statusRaw == 'pending';

                return PremiumCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: context.isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_iconForType(type), color: AppColors.secondaryBlue, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$userEmail — ${type.toUpperCase()}',
                                        style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Text(formatDate(createdAt), style: AppTypography.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(formatNaira(amount), style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    StatusChip(status: status, compact: true),
                                  ],
                                ),
                              ],
                            ),
                            if (isPendingWithdrawal) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                    onPressed: () => _reviewWithdrawal(txId, false),
                                    child: const Text('Decline'),
                                  ),
                                  FilledButton(
                                    onPressed: () => _reviewWithdrawal(txId, true),
                                    child: const Text('Approve'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.flag_outlined, color: AppColors.error),
                                    tooltip: 'Raise flag on this transaction',
                                    onPressed: () => _raiseFlag(txId),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.flag_outlined, color: AppColors.error),
                                  tooltip: 'Raise flag on this transaction',
                                  onPressed: () => _raiseFlag(txId),
                                ),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_iconForType(type), color: AppColors.secondaryBlue, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$userEmail — ${type.toUpperCase()}', style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  Text(formatDate(createdAt), style: AppTypography.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatNaira(amount), style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                StatusChip(status: status, compact: true),
                              ],
                            ),
                            if (isPendingWithdrawal) ...[
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                onPressed: () => _reviewWithdrawal(txId, false),
                                child: const Text('Decline'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                onPressed: () => _reviewWithdrawal(txId, true),
                                child: const Text('Approve'),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.flag_outlined, color: AppColors.error),
                              tooltip: 'Raise flag on this transaction',
                              onPressed: () => _raiseFlag(txId),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'transfer':
        return Icons.swap_horiz;
      case 'deposit':
        return Icons.south_west;
      case 'withdrawal':
        return Icons.north_east;
      case 'funding':
        return Icons.add_card;
      default:
        return Icons.receipt;
    }
  }
}
