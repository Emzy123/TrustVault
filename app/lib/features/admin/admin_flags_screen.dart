import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../shared/state_widgets.dart';

/// View-only flags queue for Admin role — admins can raise flags on transactions
/// but cannot resolve them (Super Admin only).
class AdminFlagsScreen extends StatefulWidget {
  const AdminFlagsScreen({super.key});

  @override
  State<AdminFlagsScreen> createState() => _AdminFlagsScreenState();
}

class _AdminFlagsScreenState extends State<AdminFlagsScreen> {
  List<TransactionFlag> _flags = [];
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
        .channel('admin:flags')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'flags',
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
    final isInitial = _flags.isEmpty;
    if (isInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await AdminService(Supabase.instance.client).fetchFlags();
      if (mounted) {
        setState(() {
          _flags = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && isInitial) setState(() => _error = 'Failed to load flags');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openCount = _flags.where((f) => f.status == 'open').length;

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
                    Text('Flags Queue', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor transaction flags you raised — resolution is handled by Super Admin',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                ),
                if (openCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.primaryNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$openCount flag(s) awaiting Super Admin resolution',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_loading && _flags.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _flags.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ErrorBanner(message: _error!),
            ),
          )
        else if (_flags.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: EmptyState(
                  icon: Icons.outlined_flag,
                  title: 'No flags raised',
                  message: 'Raise flags from the Transactions screen when you spot suspicious activity.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _flags.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final flag = _flags[index];
                final isOpen = flag.status == 'open';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isOpen
                              ? AppColors.error.withValues(alpha: 0.15)
                              : AppColors.neutralLightGrey,
                          child: Icon(
                            Icons.flag,
                            color: isOpen ? AppColors.error : AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Reason: ${flag.reason}', style: theme.textTheme.titleMedium),
                                  ),
                                  const SizedBox(width: 8),
                                  _FlagBadge(status: flag.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (flag.userEmail != null)
                                Text('User: ${flag.userEmail}', style: theme.textTheme.bodySmall),
                              if (flag.transactionAmount != null)
                                Text(
                                  'Tx: ${flag.transactionType?.toUpperCase()} · ${formatNaira(flag.transactionAmount!)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              Text('Raised at: ${formatDate(flag.createdAt)}', style: theme.textTheme.bodySmall),
                              if (flag.resolutionNote != null)
                                Text('Resolution: ${flag.resolutionNote}', style: theme.textTheme.bodySmall),
                            ],
                          ),
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

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'open':
        color = AppColors.error;
        break;
      case 'resolved':
        color = AppColors.success;
        break;
      default:
        color = AppColors.textGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
      ),
    );
  }
}
