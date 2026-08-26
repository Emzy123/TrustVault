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

class AdminFundingQueueScreen extends StatefulWidget {
  const AdminFundingQueueScreen({super.key});

  @override
  State<AdminFundingQueueScreen> createState() => _AdminFundingQueueScreenState();
}

class _AdminFundingQueueScreenState extends State<AdminFundingQueueScreen> {
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
        .channel('admin:funding_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'funding_requests',
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
      final items = await AdminService(Supabase.instance.client).fetchFundingQueue();
      if (mounted) {
        setState(() {
          _queue = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && isInitial) setState(() => _error = mapRpcError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String requestId, bool approve) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decline funding request'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Decline reason',
              hintText: 'e.g. Funding request exceeds account allowance',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Decline'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      reason = controller.text.trim();
      if (reason.isEmpty) reason = 'Declined during administrative review';
    }

    try {
      await AdminService(Supabase.instance.client).reviewFunding(
        requestId: requestId,
        approve: approve,
        declineReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Funding request approved & credited' : 'Funding request declined'),
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
              title: 'Funding Requests Queue',
              subtitle: 'Approve or decline user balance credit requests',
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
                  title: 'No pending funding requests',
                  message: 'All user funding requests have been reviewed.',
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
                final profile = item['profiles'] as Map<String, dynamic>?;
                final fullName = profile?['full_name'] as String? ?? 'User';
                final email = profile?['email'] as String? ?? '';
                final amount = (item['amount'] as num).toDouble();
                final note = item['note'] as String?;
                final requestId = item['id'] as String;
                final createdAt = DateTime.parse(item['created_at'] as String);

                return PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: ResponsiveReviewCard(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add_card_rounded, color: AppColors.primaryNavy),
                    ),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, style: AppTypography.textTheme.titleMedium),
                        Text(email, style: AppTypography.textTheme.bodySmall),
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
                          onPressed: () => _review(requestId, false),
                          child: const Text('Decline'),
                        ),
                        FilledButton(onPressed: () => _review(requestId, true), child: const Text('Approve & Credit')),
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
