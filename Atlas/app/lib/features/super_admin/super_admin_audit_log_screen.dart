import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../shared/state_widgets.dart';

class SuperAdminAuditLogScreen extends StatefulWidget {
  const SuperAdminAuditLogScreen({super.key});

  @override
  State<SuperAdminAuditLogScreen> createState() => _SuperAdminAuditLogScreenState();
}

class _SuperAdminAuditLogScreenState extends State<SuperAdminAuditLogScreen> {
  List<AuditLogItem> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isInitial = _logs.isEmpty;
    if (isInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await AdminService(Supabase.instance.client).fetchAuditLogs();
      if (mounted) {
        setState(() {
          _logs = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && isInitial) setState(() => _error = 'Failed to load audit logs');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              title: 'System Audit Log',
              subtitle: 'Immutable trail of all administrative actions, status changes, and compliance events',
              onRefresh: _load,
            ),
          ),
        ),
        if (_loading && _logs.isEmpty)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue)))
        else if (_error != null && _logs.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: ErrorBanner(message: _error!)))
        else if (_logs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: PremiumCard(
                child: EmptyState(
                  icon: Icons.history_edu_outlined,
                  title: 'No audit records',
                  message: 'System activity logs will appear here as administrative actions occur.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final actor = log.actorEmail ?? log.actorName ?? 'System/Actor';

                return PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.security_rounded, color: AppColors.primaryNavy, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(log.action, style: AppTypography.textTheme.titleMedium),
                                const Spacer(),
                                Text(formatDate(log.createdAt), style: AppTypography.textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Actor: $actor', style: AppTypography.textTheme.bodySmall),
                            if (log.targetId != null) Text('Target ID: ${log.targetId}', style: AppTypography.textTheme.bodySmall),
                            if (log.metadata.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.neutralLightGrey,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  const JsonEncoder.withIndent('  ').convert(log.metadata),
                                  style: AppTypography.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                ),
                              ),
                            ],
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
