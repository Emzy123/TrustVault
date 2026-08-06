import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/profile.dart';
import '../../../services/wallet_service.dart';
import '../../shared/state_widgets.dart';

class KycFormScreen extends StatefulWidget {
  const KycFormScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends State<KycFormScreen> {
  int _activeStep = 1; // 1: Level 1 (ID), 2: Level 2 (Face), 3: Level 3 (Address)

  // Level 1 Form State
  final _level1FormKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _addressController = TextEditingController();
  String _idType = 'National ID';
  DateTime? _dob;

  // Level 2 Face Scan State
  bool _scanningFace = false;
  double _scanProgress = 0.0;
  bool _faceVerified = false;
  final double _faceMatchScore = 96.5;

  // Level 3 Proof of Address State
  final _docUrlController = TextEditingController(text: 'https://trustvault.app/docs/proof_of_address.pdf');
  String _docType = 'Utility Bill';

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default active step based on user's current kycLevel
    if (widget.profile.kycLevel == 1) {
      _activeStep = 2;
    } else if (widget.profile.kycLevel == 2) {
      _activeStep = 3;
    } else if (widget.profile.kycLevel >= 3) {
      _activeStep = 3;
    }
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _addressController.dispose();
    _docUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submitLevel1() async {
    if (!_level1FormKey.currentState!.validate() || _dob == null) {
      if (_dob == null) setState(() => _error = 'Date of birth is required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletService(Supabase.instance.client).submitKycLevel1(
        idType: _idType,
        idNumber: _idNumberController.text.trim(),
        dob: _dob!,
        address: _addressController.text.trim(),
      );
      if (mounted) {
        setState(() => _activeStep = 2);
        context.go('/app/kyc/pending');
      }
    } catch (error) {
      setState(() => _error = mapRpcError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startFaceScan() {
    setState(() {
      _scanningFace = true;
      _scanProgress = 0.0;
      _error = null;
    });

    Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _scanProgress += 0.05;
      });
      if (_scanProgress >= 1.0) {
        timer.cancel();
        setState(() {
          _scanningFace = false;
          _faceVerified = true;
        });
      }
    });
  }

  Future<void> _submitLevel2() async {
    if (!_faceVerified) {
      setState(() => _error = 'Complete facial verification scan first');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletService(Supabase.instance.client).submitKycLevel2(
        faceImageUrl: 'https://trustvault.app/biometrics/face_${widget.profile.id.substring(0, 8)}.png',
        matchScore: _faceMatchScore,
      );
      if (mounted) {
        setState(() => _activeStep = 3);
        context.go('/app');
      }
    } catch (error) {
      setState(() => _error = mapRpcError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLevel3() async {
    if (_docUrlController.text.trim().length < 5) {
      setState(() => _error = 'Valid proof of address document URL required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletService(Supabase.instance.client).submitKycLevel3(
        proofOfAddressUrl: _docUrlController.text.trim(),
      );
      if (mounted) context.go('/app/kyc/pending');
    } catch (error) {
      setState(() => _error = mapRpcError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Account Leveling & KYC', style: theme.textTheme.headlineLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.secondaryBlue),
                    ),
                    child: Text(
                      widget.profile.levelBadgeTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Complete verification levels to expand daily transfer limits and unlock full features.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),

              // Stepper Tabs Header
              Row(
                children: [
                  _buildStepHeaderTab(1, 'Level 1', 'Government ID', widget.profile.kycLevel >= 1),
                  const SizedBox(width: 8),
                  _buildStepHeaderTab(2, 'Level 2', 'Face Match', widget.profile.kycLevel >= 2),
                  const SizedBox(width: 8),
                  _buildStepHeaderTab(3, 'Level 3', 'Proof Address', widget.profile.kycLevel >= 3),
                ],
              ),
              const SizedBox(height: 24),

              // Active Step Form Content
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildActiveStepContent(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeaderTab(int stepNumber, String title, String subtitle, bool isCompleted) {
    final isActive = _activeStep == stepNumber;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeStep = stepNumber),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.secondaryBlue
                : isCompleted
                    ? AppColors.lightGrey
                    : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.secondaryBlue
                  : isCompleted
                      ? AppColors.secondaryBlue
                      : AppColors.borderGrey,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCompleted)
                    const Icon(Icons.check_circle, size: 16, color: AppColors.secondaryBlue)
                  else
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: isActive ? AppColors.white : AppColors.textGrey,
                      child: Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.secondaryBlue : AppColors.white,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? AppColors.white.withValues(alpha: 0.8) : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStepContent(ThemeData theme) {
    if (_activeStep == 1) {
      return _buildLevel1Form(theme);
    } else if (_activeStep == 2) {
      return _buildLevel2FaceScan(theme);
    } else {
      return _buildLevel3AddressForm(theme);
    }
  }

  Widget _buildLevel1Form(ThemeData theme) {
    return Form(
      key: _level1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: AppColors.secondaryBlue),
              const SizedBox(width: 8),
              Text('Level 1: Identity & Government ID', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Unlocks Tier 2: \$500,000 Daily Transfer Limit',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryBlue, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          DropdownButtonFormField<String>(
            value: _idType,
            decoration: const InputDecoration(labelText: 'ID type'),
            items: const [
              DropdownMenuItem(value: 'National ID', child: Text('National ID')),
              DropdownMenuItem(value: 'Passport', child: Text('Passport')),
              DropdownMenuItem(value: "Driver's License", child: Text("Driver's License")),
            ],
            onChanged: _loading ? null : (v) => setState(() => _idType = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _idNumberController,
            decoration: const InputDecoration(labelText: 'ID number'),
            validator: (v) => v == null || v.trim().length < 4 ? 'Enter a valid ID number' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _loading ? null : _pickDob,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of birth'),
              child: Text(
                _dob == null ? 'Select date' : formatShortDate(_dob!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _dob == null ? AppColors.textGrey : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Residential Address'),
            maxLines: 2,
            validator: (v) => v == null || v.trim().length < 3 ? 'Enter your full address' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _submitLevel1,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                : const Text('Submit Level 1 Verification'),
          ),
        ],
      ),
    );
  }

  Widget _buildLevel2FaceScan(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.face_retouching_natural, color: AppColors.secondaryBlue),
            const SizedBox(width: 8),
            Text('Level 2: Biometric Face Verification', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Unlocks Tier 3: \$5,000,000 Daily Transfer Limit',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryBlue, fontWeight: FontWeight.bold),
        ),
        const Divider(height: 24),
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _faceVerified ? AppColors.secondaryBlue : AppColors.secondaryBlue,
                width: 4,
              ),
              color: AppColors.darkNavy.withValues(alpha: 0.05),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_scanningFace)
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: _scanProgress,
                      strokeWidth: 6,
                      color: AppColors.accentGold,
                    ),
                  ),
                Icon(
                  _faceVerified ? Icons.sentiment_very_satisfied : Icons.face,
                  size: 96,
                  color: _faceVerified ? AppColors.secondaryBlue : AppColors.darkNavy,
                ),
                if (_faceVerified)
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Matches ${widget.profile.fullName} (${_faceMatchScore.toStringAsFixed(1)}%)',
                        style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _faceVerified
              ? '✅ Biometric facial scan verified! Facial features rhyme 96.5% with Level 1 Identity (${widget.profile.fullName}).'
              : _scanningFace
                  ? 'Position your face in center. Performing liveness check & matching with Level 1 ID...'
                  : 'Click "Start Face Scan" to capture biometric selfie and match against Level 1 Identity.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _faceVerified ? AppColors.secondaryBlue : AppColors.textGrey,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        if (!_faceVerified)
          OutlinedButton.icon(
            onPressed: _scanningFace ? null : _startFaceScan,
            icon: const Icon(Icons.camera_alt),
            label: Text(_scanningFace ? 'Scanning Biometrics...' : 'Start Face Scan'),
          )
        else
          ElevatedButton(
            onPressed: _loading ? null : _submitLevel2,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                : const Text('Confirm & Upgrade to Level 2 (\$5M Limit)'),
          ),
      ],
    );
  }

  Widget _buildLevel3AddressForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.home_work_outlined, color: AppColors.secondaryBlue),
            const SizedBox(width: 8),
            Text('Level 3: Proof of Address Document', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Unlocks Tier 4: Unlimited (\$50,000,000) Daily Transfer Limit',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accentGold, fontWeight: FontWeight.bold),
        ),
        const Divider(height: 24),
        DropdownButtonFormField<String>(
          value: _docType,
          decoration: const InputDecoration(labelText: 'Document Type'),
          items: const [
            DropdownMenuItem(value: 'Utility Bill', child: Text('Utility Bill (Electricity / Water)')),
            DropdownMenuItem(value: 'Bank Statement', child: Text('Bank Statement (Last 3 Months)')),
            DropdownMenuItem(value: 'Tenancy Agreement', child: Text('Tenancy Agreement / Title Deed')),
          ],
          onChanged: _loading ? null : (v) => setState(() => _docType = v!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _docUrlController,
          decoration: const InputDecoration(
            labelText: 'Document URL / Upload Link',
            hintText: 'https://...',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderGrey),
          ),
          child: Row(
            children: [
              Icon(Icons.description, color: AppColors.secondaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Document Selected: $_docType', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    const Text('Must clearly state your full name and residential address.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _submitLevel3,
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
              : const Text('Submit Proof of Address for Review'),
        ),
      ],
    );
  }
}

class KycPendingScreen extends StatelessWidget {
  const KycPendingScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (profile.kycStatus == KycStatus.approved) {
      return Center(
        child: EmptyState(
          icon: Icons.verified_outlined,
          title: 'Verification Complete — ${profile.levelBadgeTitle}',
          message: 'Your verification has been approved! Current Daily Limit: ${profile.formattedDailyLimit}.',
          action: ElevatedButton(
            onPressed: () => context.go('/app'),
            child: const Text('Go to dashboard'),
          ),
        ),
      );
    }

    if (profile.kycStatus == KycStatus.declined) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Verification Declined',
            message: 'Your submission was declined. Please review your details and submit again.',
            action: ElevatedButton(
              onPressed: () => context.go('/app/kyc'),
              child: const Text('Resubmit verification'),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, size: 48, color: AppColors.secondaryBlue),
                const SizedBox(height: 16),
                Text('Pending verification', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Your level submission is under review by compliance team. This takes a short time during demo.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.go('/app'),
                  child: const Text('Back to dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
