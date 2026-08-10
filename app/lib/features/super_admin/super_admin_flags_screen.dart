import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../services/wallet_service.dart';
import '../shared/state_widgets.dart';

class SuperAdminFlagsScreen extends StatefulWidget {
  const SuperAdminFlagsScreen({super.key});

  @override
  State<SuperAdminFlagsScreen> createState() => _SuperAdminFlagsScreenState();
}

class _SuperAdminFlagsScreenState extends State<SuperAdminFlagsScreen> {
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
        .channel('superadmin:flags')
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

  Future<void> _resolve(TransactionFlag flag, bool dismiss) async {
    bool freezeAccount = false;
    final noteController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(dismiss ? 'Dismiss Flag' : 'Resolve Flag'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flag reason: "${flag.reason}"'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Resolution note',
                      hintText: 'e.g. Investigation completed; transaction verified.',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Freeze user account'),
                    subtitle: const Text('Suspend account from making further transactions'),
                    value: freezeAccount,
                    onChanged: (val) => setDialogState(() => freezeAccount = val ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(dismiss ? 'Dismiss Flag' : 'Mark Resolved'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    try {
      await AdminService(Supabase.instance.client).resolveFlag(
        flagId: flag.id,
        dismiss: dismiss,
        resolutionNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        freezeAccount: freezeAccount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dismiss ? 'Flag dismissed' : 'Flag resolved'),
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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
          sliver: SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Flags Resolution Queue',
              subtitle: 'Review transaction flags raised by Admins and take compliance resolution actions',
              onRefresh: _load,
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
                  message: 'No transactions are currently flagged for review.',
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
                            if (flag.resolutionNote != null) Text('Note: ${flag.resolutionNote}', style: AppTypography.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (isOpen) ...[
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(onPressed: () => _resolve(flag, true), child: const Text('Dismiss')),
                            FilledButton(onPressed: () => _resolve(flag, false), child: const Text('Resolve Flag')),
                          ],
                        ),
                      ],
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
