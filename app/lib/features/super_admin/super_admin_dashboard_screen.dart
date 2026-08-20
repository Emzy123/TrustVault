import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/balance_visibility.dart';
import '../../core/formatters.dart' show formatErrorMessage, formatNaira;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../shared/state_widgets.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  SuperAdminMetrics? _metrics;
  PlatformAnalytics? _analytics;
  bool _loading = true;
  bool _balancesVisible = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVisibility();
    _load();
  }

  Future<void> _loadVisibility() async {
    final visible = await BalanceVisibility.isVisible();
    if (mounted) setState(() => _balancesVisible = visible);
  }

  Future<void> _toggleBalances() async {
    final next = !_balancesVisible;
    setState(() => _balancesVisible = next);
    await BalanceVisibility.setVisible(next);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final admin = AdminService(Supabase.instance.client);
    SuperAdminMetrics? metrics;
    PlatformAnalytics? analytics;
    Object? metricsError;
    Object? analyticsError;

    try {
      metrics = await admin.fetchSuperAdminMetrics();
    } catch (e) {
      metricsError = e;
    }

    try {
      analytics = await admin.fetchPlatformAnalytics();
    } catch (e) {
      analyticsError = e;
    }

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _analytics = analytics;
        if (metrics == null && analytics == null) {
          _error = formatErrorMessage(metricsError ?? analyticsError ?? 'Unknown error');
        } else if (metricsError != null || analyticsError != null) {
          final parts = <String>[];
          if (metricsError != null) {
            parts.add('Core metrics: ${formatErrorMessage(metricsError)}');
          }
          if (analyticsError != null) {
            parts.add('Platform analytics: ${formatErrorMessage(analyticsError)}');
          }
          _error = parts.join('\n');
        }
      });
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final analytics = _analytics;

    return SingleChildScrollView(
      padding: context.adminPagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsivePageHeader(
            title: 'Super Admin Dashboard',
            subtitle: 'Full platform oversight, compliance resolution, and security controls',
            actions: [
              IconButton.filledTonal(
                onPressed: _toggleBalances,
                icon: Icon(
                  _balancesVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                tooltip: _balancesVisible ? 'Hide balances' : 'Show balances',
              ),
              IconButton.filledTonal(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh metrics',
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_loading && metrics == null && analytics == null)
            const Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue))
          else if (metrics == null && analytics == null)
            ErrorBanner(message: _error ?? 'Failed to load system metrics')
          else ...[
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            ResponsiveMetricGrid(
              minTileWidth: 160,
              children: [
                if (metrics != null) ...[
                  _StatTile(
                    title: 'Total Users',
                    value: '${metrics.totalUsers}',
                    icon: Icons.people_outline,
                    onTap: () => context.go('/superadmin/users'),
                  ),
                  _StatTile(
                    title: 'Total Admins',
                    value: '${metrics.totalAdmins}',
                    icon: Icons.admin_panel_settings_outlined,
                    onTap: () => context.go('/superadmin/users'),
                  ),
                  _StatTile(
                    title: 'Pending KYC',
                    value: '${metrics.pendingKyc}',
                    icon: Icons.how_to_reg_outlined,
                    highlight: metrics.pendingKyc > 0,
                    onTap: () => context.go('/superadmin/kyc'),
                  ),
                  _StatTile(
                    title: 'Pending Funding',
                    value: '${metrics.pendingFunding}',
                    icon: Icons.pending_actions_outlined,
                    highlight: metrics.pendingFunding > 0,
                    onTap: () => context.go('/superadmin/funding'),
                  ),
                  _StatTile(
                    title: 'Pending Withdrawals',
                    value: '${metrics.pendingWithdrawals}',
                    icon: Icons.outbound_outlined,
                    highlight: metrics.pendingWithdrawals > 0,
                    onTap: () => context.go('/superadmin/withdrawals'),
                  ),
                  _StatTile(
                    title: 'Open Flags',
                    value: '${metrics.openFlags}',
                    icon: Icons.flag_outlined,
                    highlight: metrics.openFlags > 0,
                    onTap: () => context.go('/superadmin/flags'),
                    subtitle: analytics != null ? '${analytics.flagRatePct}% open rate' : null,
                  ),
                  _StatTile(
                    title: 'Frozen Accounts',
                    value: '${metrics.frozenAccounts}',
                    icon: Icons.ac_unit,
                    onTap: () => context.go('/superadmin/users'),
                  ),
                  _StatTile(
                    title: 'Total Volume',
                    value: BalanceVisibility.maskOrFormat(
                      _balancesVisible,
                      formatNaira(metrics.totalVolume),
                    ),
                    icon: Icons.account_balance_wallet,
                  ),
                ],
                if (analytics != null) ...[
                  _StatTile(
                    title: 'Active Users',
                    value: '${analytics.activeUsers}',
                    subtitle: '${analytics.activeUserRate}% of total',
                    icon: Icons.person_pin_outlined,
                  ),
                  _StatTile(
                    title: '7-Day Volume',
                    value: BalanceVisibility.maskOrFormat(
                      _balancesVisible,
                      formatNaira(analytics.volume7d),
                    ),
                    icon: Icons.trending_up,
                  ),
                  _StatTile(
                    title: 'Pending Admin Invites',
                    value: '${analytics.pendingAdminInvites}',
                    icon: Icons.mail_outline,
                    highlight: analytics.pendingAdminInvites > 0,
                    onTap: () => context.go('/superadmin/users'),
                  ),
                ],
              ],
            ),
            if (metrics != null || analytics != null) ...[
              const SizedBox(height: 36),
              const SectionHeader(title: 'Action Needed'),
              const SizedBox(height: 16),
              if (metrics != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionCard(
                      title: 'Withdrawal Review Queue',
                      count: metrics.pendingWithdrawals,
                      subtitle: 'Honest withdrawal requests awaiting decision',
                      buttonText: 'Review Withdrawals',
                      onPressed: () => context.go('/superadmin/withdrawals'),
                    ),
                    const SizedBox(height: 16),
                    _ActionCard(
                      title: 'Flag Resolution Queue',
                      count: metrics.openFlags,
                      subtitle: 'Admin-raised transaction flags awaiting Super Admin action',
                      buttonText: 'Resolve Flags',
                      onPressed: () => context.go('/superadmin/flags'),
                    ),
                  ],
                ),
              if (metrics != null && analytics != null) const SizedBox(height: 16),
              if (analytics != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionCard(
                      title: 'Admin Management',
                      count: analytics.pendingAdminInvites,
                      subtitle: 'Create admins, manage roles, and review pending invitations',
                      buttonText: 'Manage Admins',
                      onPressed: () => context.go('/superadmin/users'),
                    ),
                    const SizedBox(height: 16),
                    _ActionCard(
                      title: 'Audit Log',
                      count: analytics.resolvedFlags,
                      subtitle: 'Full system-wide activity trail for compliance review',
                      buttonText: 'View Audit Log',
                      onPressed: () => context.go('/superadmin/audit'),
                    ),
                  ],
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.highlight = false,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (highlight ? AppColors.secondaryBlue : AppColors.textMuted).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: highlight ? AppColors.secondaryBlue : AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  fontSize: context.isMobile ? 22 : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: AppTypography.textTheme.bodySmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTypography.textTheme.bodySmall?.copyWith(fontSize: 10)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final int count;
  final String subtitle;
  final String buttonText;
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
              StatusPill(label: '$count pending', color: count > 0 ? AppColors.secondaryBlue : AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: AppTypography.textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }
}
