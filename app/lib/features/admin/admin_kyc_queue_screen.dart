import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
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
                    Text('KYC Review Queue', style: theme.textTheme.headlineLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Review user identity verification submissions',
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
                  title: 'No pending KYC submissions',
                  message: 'All submitted identity verifications have been processed.',
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
                final level = item['level'] as int? ?? 1;
                final idType = item['id_type'] as String? ?? 'N/A';
                final idNumber = item['id_number'] as String? ?? 'N/A';
                final address = item['address'] as String? ?? 'N/A';
                final faceMatchScore = (item['face_match_score'] as num?)?.toDouble();
                final proofUrl = item['proof_of_address_url'] as String?;
                final submissionId = item['id'] as String;
                final createdAt = DateTime.parse(item['created_at'] as String);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.12),
                          child: Icon(
                            level == 2 ? Icons.face : level == 3 ? Icons.home_work : Icons.badge,
                            color: AppColors.secondaryBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(fullName, style: theme.textTheme.titleMedium),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Level $level Submission',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(email, style: theme.textTheme.bodySmall),
                              const SizedBox(height: 8),
                              if (level == 1) ...[
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    Text('Type: $idType', style: theme.textTheme.bodySmall),
                                    Text('ID #: $idNumber', style: theme.textTheme.bodySmall),
                                    Text('Submitted: ${formatDate(createdAt)}', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Address: $address', style: theme.textTheme.bodySmall),
                              ] else if (level == 2) ...[
                                Text(
                                  '📸 Biometric Face Scan: ${faceMatchScore != null ? "${faceMatchScore.toStringAsFixed(1)}% Match Score" : "Selfie Captured"}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                ),
                                Text('Submitted: ${formatDate(createdAt)}', style: theme.textTheme.bodySmall),
                              ] else ...[
                                Text(
                                  '📄 Proof of Address Document: ${proofUrl ?? "Uploaded Document"}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.accentGold),
                                ),
                                Text('Submitted: ${formatDate(createdAt)}', style: theme.textTheme.bodySmall),
                              ],
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
                              onPressed: () => _review(submissionId, false),
                              child: const Text('Decline'),
                            ),
                            FilledButton(
                              onPressed: () => _review(submissionId, true),
                              child: const Text('Approve'),
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
