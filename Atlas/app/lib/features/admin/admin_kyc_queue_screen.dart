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

class AdminKycQueueScreen extends StatefulWidget {
  const AdminKycQueueScreen({super.key});

  @override
  State<AdminKycQueueScreen> createState() => _AdminKycQueueScreenState();
}

class _AdminKycQueueScreenState extends State<AdminKycQueueScreen> {
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
        .channel('admin:kyc_submissions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kyc_submissions',
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
      final items = await AdminService(Supabase.instance.client).fetchKycQueue();
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

  Future<void> _review(String submissionId, bool approve) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decline KYC submission'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Decline reason',
              hintText: 'e.g. Address does not match ID document',
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
      await AdminService(Supabase.instance.client).reviewKyc(
        submissionId: submissionId,
        approve: approve,
        declineReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'KYC approved successfully' : 'KYC declined'),
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
              title: 'KYC Review Queue',
              subtitle: 'Review user identity verification submissions',
              onRefresh: _load,
            ),
          ),
        ),
        if (_loading && _queue.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue)),
          )
        else if (_error != null && _queue.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.adminPagePadding.left),
              child: ErrorBanner(message: _error!),
            ),
          )
        else if (_queue.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.adminPagePadding.left),
              child: PremiumCard(
                child: EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No pending KYC submissions',
                  message: 'All submitted identity verifications have been processed.',
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
                final level = item['level'] as int? ?? 1;
                final idType = item['id_type'] as String? ?? 'N/A';
                final idNumber = item['id_number'] as String? ?? 'N/A';
                final address = item['address'] as String? ?? 'N/A';
                final faceMatchScore = (item['face_match_score'] as num?)?.toDouble();
                final proofUrl = item['proof_of_address_url'] as String?;
                final submissionId = item['id'] as String;
                final createdAt = DateTime.parse(item['created_at'] as String);

                return PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: ResponsiveReviewCard(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        level == 2 ? Icons.face_rounded : level == 3 ? Icons.home_work_rounded : Icons.badge_outlined,
                        color: AppColors.secondaryBlue,
                      ),
                    ),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(fullName, style: AppTypography.textTheme.titleMedium),
                            StatusPill(label: 'Level $level', color: AppColors.secondaryBlue),
                          ],
                        ),
                        Text(email, style: AppTypography.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        if (level == 1) ...[
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text('Type: $idType', style: AppTypography.textTheme.bodySmall),
                              Text('ID #: $idNumber', style: AppTypography.textTheme.bodySmall),
                              Text('Submitted: ${formatDate(createdAt)}', style: AppTypography.textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Address: $address', style: AppTypography.textTheme.bodySmall),
                        ] else if (level == 2) ...[
                          Text(
                            'Biometric Face Scan: ${faceMatchScore != null ? "${faceMatchScore.toStringAsFixed(1)}% Match" : "Selfie Captured"}',
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                          Text('Submitted: ${formatDate(createdAt)}', style: AppTypography.textTheme.bodySmall),
                        ] else ...[
                          Text(
                            'Proof of Address: ${proofUrl ?? "Uploaded Document"}',
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentGold,
                            ),
                          ),
                          Text('Submitted: ${formatDate(createdAt)}', style: AppTypography.textTheme.bodySmall),
                        ],
                      ],
                    ),
                    actions: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          onPressed: () => _review(submissionId, false),
                          child: const Text('Decline'),
                        ),
                        FilledButton(
                          onPressed: () => _review(submissionId, true),
                          child: const Text('Approve'),
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
