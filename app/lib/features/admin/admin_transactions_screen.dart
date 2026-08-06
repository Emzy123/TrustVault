import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Transaction Monitor', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Live feed of all wallet transfers, funding, deposits, and withdrawals',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
        if (_loading && _transactions.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _transactions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ErrorBanner(message: _error!),
            ),
          )
        else if (_transactions.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _transactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
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

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.neutralLightGrey,
                      child: Icon(
                        _iconForType(type),
                        color: AppColors.secondaryBlue,
                        size: 20,
                      ),
                    ),
                    title: Text('$userEmail — ${type.toUpperCase()}'),
                    subtitle: Text(formatDate(createdAt), style: theme.textTheme.bodySmall),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatNaira(amount), style: theme.textTheme.titleMedium),
                            StatusChip(status: status, compact: true),
                          ],
                        ),
                        if (isPendingWithdrawal) ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _reviewWithdrawal(txId, false),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _reviewWithdrawal(txId, true),
                            child: const Text('Approve'),
                          ),
                        ],
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.flag_outlined, color: AppColors.error),
                          tooltip: 'Raise flag on this transaction',
                          onPressed: () => _raiseFlag(txId),
                        ),
                      ],
                    ),
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
