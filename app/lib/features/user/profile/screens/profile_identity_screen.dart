import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/premium_widgets.dart';
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
    return ProfileSubScreenScaffold(
      title: 'Identity & Verification',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVerificationBanner(),
          const SizedBox(height: 20),
          if (_loading)
            const PremiumCard(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.secondaryBlue)),
              ),
            )
          else if (_error != null)
            ErrorBanner(message: _error!)
          else ...[
            _buildIdentityCard(),
            const SizedBox(height: 16),
            _buildContactDetailsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    final isApproved = widget.profile.kycStatus == KycStatus.approved;
    final isPending = widget.profile.kycStatus == KycStatus.pending;
    final color = isApproved ? AppColors.success : isPending ? AppColors.warning : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              isApproved
                  ? Icons.check_circle_outline_rounded
                  : isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.error_outline_rounded,
              color: AppColors.white,
              size: 26,
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
                  style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isApproved
                      ? 'Your account has full access to wallet transfers and funding.'
                      : isPending
                          ? 'Your KYC documents are under review by compliance officers.'
                          : 'Complete identity verification to unlock funding and wallet features.',
                  style: AppTypography.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_outlined, color: AppColors.secondaryBlue),
              ),
              const SizedBox(width: 12),
              Text('Government Identity', style: AppTypography.textTheme.titleMedium),
            ],
          ),
          const Divider(height: 32),
          DetailRow(label: 'Full Legal Name', value: widget.profile.fullName),
          DetailRow(label: 'ID Type', value: _kyc?.idType ?? 'National ID'),
          DetailRow(label: 'ID Number', value: _obfuscateId(_kyc?.idNumber ?? 'Not provided')),
          DetailRow(
            label: 'Date of Birth',
            value: _kyc?.dob != null ? formatShortDate(_kyc!.dob!) : 'Not provided',
          ),
          DetailRow(
            label: 'Submission Date',
            value: _kyc?.createdAt != null ? formatDate(_kyc!.createdAt) : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailsCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home_work_outlined, color: AppColors.secondaryBlue),
              ),
              const SizedBox(width: 12),
              Text('Address & Contact Info', style: AppTypography.textTheme.titleMedium),
            ],
          ),
          const Divider(height: 32),
          DetailRow(label: 'Registered Email', value: widget.profile.email),
          DetailRow(label: 'Phone Number', value: widget.profile.phone ?? 'Not provided'),
          DetailRow(label: 'Residential Address', value: _kyc?.address ?? 'Not provided'),
        ],
      ),
    );
  }

  String _obfuscateId(String id) {
    if (id.length <= 4) return id;
    return '${id.substring(0, 3)}****${id.substring(id.length - 3)}';
  }
}
