import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
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
    final metrics = _metrics;

    return SingleChildScrollView(
      padding: context.adminPagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsivePageHeader(
            title: 'Admin Dashboard',
            subtitle: 'Real-time oversight queues and platform activity',
            actions: [
              IconButton.filledTonal(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh metrics',
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_loading && metrics == null)
            const Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue))
          else if (_error != null)
            ErrorBanner(message: _error!)
          else if (metrics != null) ...[
            ResponsiveMetricGrid(
              children: [
                _MetricCard(
                  title: 'Total users',
                  value: '${metrics.totalUsers}',
                  icon: Icons.people_outline_rounded,
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
                  icon: Icons.show_chart_rounded,
                ),
              ],
            ),
            const SizedBox(height: 36),
            const SectionHeader(title: 'Quick Queues'),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QueueCard(
                  title: 'KYC Submissions',
                  count: metrics.pendingKyc,
                  description: 'Identity verification queue awaiting review',
                  buttonLabel: 'Go to KYC Queue',
                  onPressed: () => context.go('/admin/kyc'),
                ),
                const SizedBox(height: 16),
                _QueueCard(
                  title: 'Funding Requests',
                  count: metrics.pendingFunding,
                  description: 'User balance funding requests awaiting approval',
                  buttonLabel: 'Go to Funding Queue',
                  onPressed: () => context.go('/admin/funding'),
                ),
                const SizedBox(height: 16),
                _QueueCard(
                  title: 'Withdrawal Requests',
                  count: metrics.pendingWithdrawals,
                  description: 'Pending withdrawals awaiting release or decline',
                  buttonLabel: 'Go to Withdrawals Queue',
                  onPressed: () => context.go('/admin/withdrawals'),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: PremiumCard(
          padding: EdgeInsets.all(context.isMobile ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (highlight ? AppColors.secondaryBlue : AppColors.textMuted)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: highlight ? AppColors.secondaryBlue : AppColors.textMuted,
                    ),
                  ),
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
              const SizedBox(height: 16),
              Text(
                value,
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  fontSize: context.isMobile ? 22 : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: AppTypography.textTheme.bodySmall),
            ],
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
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTypography.textTheme.titleMedium),
              const Spacer(),
              StatusPill(
                label: '$count pending',
                color: count > 0 ? AppColors.accentGold : AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: AppTypography.textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
