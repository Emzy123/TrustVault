import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
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
                    Text('System Audit Log', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Immutable trail of all administrative actions, status changes, and compliance events',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
        if (_loading && _logs.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _logs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ErrorBanner(message: _error!),
            ),
          )
        else if (_logs.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Card(
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList.separated(
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final actor = log.actorEmail ?? log.actorName ?? 'System/Actor';

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                      child: const Icon(Icons.security, color: AppColors.primaryNavy, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(log.action, style: theme.textTheme.titleMedium),
                        const Spacer(),
                        Text(formatDate(log.createdAt), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Actor: $actor', style: theme.textTheme.bodySmall),
                        if (log.targetId != null)
                          Text('Target ID: ${log.targetId}', style: theme.textTheme.bodySmall),
                        if (log.metadata.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.neutralLightGrey,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              const JsonEncoder.withIndent('  ').convert(log.metadata),
                              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        ],
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
