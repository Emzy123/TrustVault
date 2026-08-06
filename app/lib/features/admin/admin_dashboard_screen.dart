import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../shared/state_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminMetrics? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final metrics = await AdminService(Supabase.instance.client).fetchAdminMetrics();
      if (mounted) setState(() => _metrics = metrics);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load metrics');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _metrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Dashboard', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time oversight queues and platform activity',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh metrics',
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading && metrics == null)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            ErrorBanner(message: _error!)
          else if (metrics != null) ...[
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  title: 'Total users',
                  value: '${metrics.totalUsers}',
                  icon: Icons.people_outline,
                ),
                _MetricCard(
                  title: 'Pending KYC',
                  value: '${metrics.pendingKyc}',
                  icon: Icons.how_to_reg_outlined,
                  highlight: metrics.pendingKyc > 0,
                  onTap: () => context.go('/admin/kyc'),
                ),
                _MetricCard(
                  title: 'Pending funding',
                  value: '${metrics.pendingFunding}',
                  icon: Icons.pending_actions_outlined,
                  highlight: metrics.pendingFunding > 0,
                  onTap: () => context.go('/admin/funding'),
                ),
                _MetricCard(
                  title: 'Pending withdrawals',
                  value: '${metrics.pendingWithdrawals}',
                  icon: Icons.outbound_outlined,
                  highlight: metrics.pendingWithdrawals > 0,
                  onTap: () => context.go('/admin/withdrawals'),
                ),
                _MetricCard(
                  title: 'Open flags',
                  value: '${metrics.openFlags}',
                  icon: Icons.flag_outlined,
                  highlight: metrics.openFlags > 0,
                  onTap: () => context.go('/admin/flags'),
                ),
                _MetricCard(
                  title: '24h volume',
                  value: formatNaira(metrics.dailyVolume),
                  icon: Icons.show_chart,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('Quick Queues', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 300, maxWidth: 450),
                  child: _QueueCard(
                    title: 'KYC Submissions',
                    count: metrics.pendingKyc,
                    description: 'Identity verification queue awaiting review',
                    buttonLabel: 'Go to KYC Queue',
                    onPressed: () => context.go('/admin/kyc'),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 300, maxWidth: 450),
                  child: _QueueCard(
                    title: 'Funding Requests',
                    count: metrics.pendingFunding,
                    description: 'User balance funding requests awaiting approval',
                    buttonLabel: 'Go to Funding Queue',
                    onPressed: () => context.go('/admin/funding'),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 300, maxWidth: 450),
                  child: _QueueCard(
                    title: 'Withdrawal Requests',
                    count: metrics.pendingWithdrawals,
                    description: 'Pending withdrawals awaiting release or decline',
                    buttonLabel: 'Go to Withdrawals Queue',
                    onPressed: () => context.go('/admin/withdrawals'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 220,
        child: Card(
          color: highlight ? AppColors.secondaryBlue.withValues(alpha: 0.08) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: highlight ? AppColors.secondaryBlue : AppColors.textGrey),
                    const Spacer(),
                    if (highlight)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(value, style: theme.textTheme.headlineLarge),
                const SizedBox(height: 4),
                Text(title, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.title,
    required this.count,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final int count;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? AppColors.accentGold.withValues(alpha: 0.2)
                        : AppColors.neutralLightGrey,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count pending',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: count > 0 ? AppColors.primaryNavy : AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
