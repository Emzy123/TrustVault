import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/profile.dart';
import '../../../../models/wallet_models.dart';
import '../../../../services/wallet_service.dart';
import '../../../shared/state_widgets.dart';

class ProfileIdentityScreen extends StatefulWidget {
  const ProfileIdentityScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileIdentityScreen> createState() => _ProfileIdentityScreenState();
}

class _ProfileIdentityScreenState extends State<ProfileIdentityScreen> {
  KycSubmission? _kyc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final kyc = await WalletService(Supabase.instance.client).fetchLatestKyc();
      setState(() {
        _kyc = kyc;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load identity details';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity & Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/profile'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVerificationBanner(theme),
                const SizedBox(height: 24),
                if (_loading)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_error != null)
                  ErrorBanner(message: _error!)
                else ...[
                  _buildIdentityCard(theme),
                  const SizedBox(height: 20),
                  _buildContactDetailsCard(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBanner(ThemeData theme) {
    final isApproved = widget.profile.kycStatus == KycStatus.approved;
    final isPending = widget.profile.kycStatus == KycStatus.pending;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isApproved
            ? AppColors.success.withValues(alpha: 0.1)
            : isPending
                ? AppColors.warning.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? AppColors.success
              : isPending
                  ? AppColors.warning
                  : AppColors.error,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isApproved
                  ? AppColors.success
                  : isPending
                      ? AppColors.warning
                      : AppColors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isApproved
                  ? Icons.check_circle_outline
                  : isPending
                      ? Icons.hourglass_top
                      : Icons.error_outline,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApproved
                      ? 'Identity Verified'
                      : isPending
                          ? 'Verification Pending'
                          : 'Identity Unverified',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isApproved
                      ? 'Your account has full access to wallet transfers and funding.'
                      : isPending
                          ? 'Your KYC documents are under review by compliance officers.'
                          : 'Complete identity verification to unlock funding and wallet features.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.secondaryBlue),
                const SizedBox(width: 10),
                Text('Government Identity', style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('Full Legal Name', widget.profile.fullName),
            _buildDetailRow('ID Type', _kyc?.idType ?? 'National ID'),
            _buildDetailRow('ID Number', _obfuscateId(_kyc?.idNumber ?? 'Not provided')),
            _buildDetailRow(
              'Date of Birth',
              _kyc?.dob != null ? formatShortDate(_kyc!.dob!) : 'Not provided',
            ),
            _buildDetailRow(
              'Submission Date',
              _kyc?.createdAt != null ? formatDate(_kyc!.createdAt) : 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactDetailsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work_outlined, color: AppColors.secondaryBlue),
                const SizedBox(width: 10),
                Text('Address & Contact Info', style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('Registered Email', widget.profile.email),
            _buildDetailRow('Phone Number', widget.profile.phone ?? 'Not provided'),
            _buildDetailRow('Residential Address', _kyc?.address ?? 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _obfuscateId(String id) {
    if (id.length <= 4) return id;
    final prefix = id.substring(0, 3);
    final suffix = id.substring(id.length - 3);
    return '$prefix****$suffix';
  }
}
