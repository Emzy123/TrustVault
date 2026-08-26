import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../services/admin_service.dart';
import '../../services/wallet_service.dart';
import '../shared/state_widgets.dart';

/// Shared withdrawal review queue — used by both Admin and Super Admin dashboards.
class WithdrawalsReviewScreen extends StatefulWidget {
  const WithdrawalsReviewScreen({
    super.key,
    this.title = 'Withdrawals Review Queue',
    this.subtitle = 'Review pending user withdrawal requests and release or decline funds',
  });

  final String title;
  final String subtitle;

  @override
  State<WithdrawalsReviewScreen> createState() => _WithdrawalsReviewScreenState();
}

class _WithdrawalsReviewScreenState extends State<WithdrawalsReviewScreen> {
  List<Map<String, dynamic>> _queue = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('withdrawals:review')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final isInitial = _queue.isEmpty;
    if (isInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await AdminService(Supabase.instance.client).fetchWithdrawalQueue();
      if (mounted) {
        setState(() {
          _queue = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && isInitial) setState(() => _error = 'Failed to load withdrawal queue');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String transactionId, bool approve) async {
    String? reason;
    if (!approve) {
      String selectedReason = 'Awaiting further identity verification';
      final customController = TextEditingController();

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Decline Withdrawal'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select genuine compliance or operational reason:'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(labelText: 'Reason category'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Awaiting further identity verification',
                          child: Text('Awaiting further identity verification'),
                        ),
                        DropdownMenuItem(
                          value: 'Above daily withdrawal limit',
                          child: Text('Above daily withdrawal limit'),
                        ),
                        DropdownMenuItem(
                          value: 'Suspicious account activity detected',
                          child: Text('Suspicious account activity detected'),
                        ),
                        DropdownMenuItem(
                          value: 'Custom reason',
                          child: Text('Custom reason...'),
                        ),
                      ],
                      onChanged: (val) => setDialogState(() => selectedReason = val!),
                    ),
                    if (selectedReason == 'Custom reason') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customController,
                        decoration: const InputDecoration(labelText: 'Custom decline reason'),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Decline Request'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirm != true) return;
      reason = selectedReason == 'Custom reason'
          ? customController.text.trim()
          : selectedReason;
      if (reason.isEmpty) reason = 'Declined during administrative review';
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
            content: Text(approve ? 'Withdrawal approved & debited' : 'Withdrawal declined'),
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
          padding: EdgeInsets.fromLTRB(
            context.adminPagePadding.left,
            context.adminPagePadding.top,
            context.adminPagePadding.right,
            16,
          ),
          sliver: SliverToBoxAdapter(
            child: AdminPageHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              onRefresh: _load,
            ),
          ),
        ),
        if (_loading && _queue.isEmpty)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue)))
        else if (_error != null && _queue.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: context.adminPagePadding.left), child: ErrorBanner(message: _error!)))
        else if (_queue.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.adminPagePadding.left),
              child: PremiumCard(
                child: EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No pending withdrawal requests',
                  message: 'All withdrawal requests have been resolved.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.adminPagePadding.left,
              8,
              context.adminPagePadding.right,
              context.adminPagePadding.bottom,
            ),
            sliver: SliverList.separated(
              itemCount: _queue.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _queue[index];
                final account = item['accounts'] as Map<String, dynamic>?;
                final profile = account?['profiles'] as Map<String, dynamic>?;
                final fullName = profile?['full_name'] as String? ?? 'User';
                final email = profile?['email'] as String? ?? '';
                final accountStatus = profile?['account_status'] as String? ?? '';
                final kycStatus = profile?['kyc_status'] as String? ?? '';
                final amount = (item['amount'] as num).toDouble();
                final note = item['note'] as String?;
                final txId = item['id'] as String;
                final createdAt = DateTime.parse(item['created_at'] as String);

                return PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: ResponsiveReviewCard(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.outbound_rounded, color: AppColors.secondaryBlue),
                    ),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, style: AppTypography.textTheme.titleMedium),
                        Text(email, style: AppTypography.textTheme.bodySmall),
                        Text('Account: $accountStatus · KYC: $kycStatus', style: AppTypography.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(formatNaira(amount), style: AppTypography.textTheme.headlineSmall?.copyWith(color: AppColors.primaryNavy)),
                        if (note != null && note.isNotEmpty) Text('Note: $note', style: AppTypography.textTheme.bodySmall),
                        Text('Requested at: ${formatDate(createdAt)}', style: AppTypography.textTheme.bodySmall),
                      ],
                    ),
                    actions: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          onPressed: () => _review(txId, false),
                          child: const Text('Decline'),
                        ),
                        FilledButton(onPressed: () => _review(txId, true), child: const Text('Approve & Release')),
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
}
