import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
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
    final openCount = _flags.where((f) => f.status == 'open').length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminPageHeader(
                  title: 'Flags Queue',
                  subtitle: 'Monitor transaction flags you raised — resolution is handled by Super Admin',
                  onRefresh: _load,
                ),
                if (openCount > 0) ...[
                  const SizedBox(height: 12),
                  AdminInfoBanner(message: '$openCount flag(s) awaiting Super Admin resolution'),
                ],
              ],
            ),
          ),
        ),
        if (_loading && _flags.isEmpty)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue)))
        else if (_error != null && _flags.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: ErrorBanner(message: _error!)))
        else if (_flags.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: PremiumCard(
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _flags.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final flag = _flags[index];
                final isOpen = flag.status == 'open';

                return PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (isOpen ? AppColors.error : AppColors.textMuted).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.flag_rounded, color: isOpen ? AppColors.error : AppColors.textMuted),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('Reason: ${flag.reason}', style: AppTypography.textTheme.titleMedium)),
                                StatusPill(label: flag.status.toUpperCase(), color: isOpen ? AppColors.error : AppColors.success),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (flag.userEmail != null) Text('User: ${flag.userEmail}', style: AppTypography.textTheme.bodySmall),
                            if (flag.transactionAmount != null)
                              Text('Tx: ${flag.transactionType?.toUpperCase()} · ${formatNaira(flag.transactionAmount!)}', style: AppTypography.textTheme.bodySmall),
                            Text('Raised at: ${formatDate(flag.createdAt)}', style: AppTypography.textTheme.bodySmall),
                            if (flag.resolutionNote != null) Text('Resolution: ${flag.resolutionNote}', style: AppTypography.textTheme.bodySmall),
                          ],
                        ),
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
}
