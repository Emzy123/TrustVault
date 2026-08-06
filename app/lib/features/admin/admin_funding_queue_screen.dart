import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
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
                    Text('Funding Requests Queue', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Approve or decline user balance credit requests',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
        if (_loading && _queue.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _queue.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ErrorBanner(message: _error!),
            ),
          )
        else if (_queue.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No pending funding requests',
                  message: 'All user funding requests have been reviewed.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _queue.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _queue[index];
                final profile = item['profiles'] as Map<String, dynamic>?;
                final fullName = profile?['full_name'] as String? ?? 'User';
                final email = profile?['email'] as String? ?? '';
                final amount = (item['amount'] as num).toDouble();
                final note = item['note'] as String?;
                final requestId = item['id'] as String;
                final createdAt = DateTime.parse(item['created_at'] as String);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.accentGold.withValues(alpha: 0.2),
                          child: const Icon(Icons.add_card, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: theme.textTheme.titleMedium),
                              Text(email, style: theme.textTheme.bodySmall),
                              const SizedBox(height: 8),
                              Text(
                                'Requested: ${formatNaira(amount)}',
                                style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primaryNavy),
                              ),
                              if (note != null && note.isNotEmpty)
                                Text('Note: $note', style: theme.textTheme.bodySmall),
                              Text('Requested at: ${formatDate(createdAt)}', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                              onPressed: () => _review(requestId, false),
                              child: const Text('Decline'),
                            ),
                            FilledButton(
                              onPressed: () => _review(requestId, true),
                              child: const Text('Approve & Credit'),
                            ),
                          ],
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
}
