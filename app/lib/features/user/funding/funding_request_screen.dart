import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../core/wallet_eligibility.dart';
import '../../../models/profile.dart';
import '../../../services/wallet_service.dart';
import '../../shared/state_widgets.dart';

class FundingRequestScreen extends StatefulWidget {
  const FundingRequestScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<FundingRequestScreen> createState() => _FundingRequestScreenState();
}

class _FundingRequestScreenState extends State<FundingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final amount = double.parse(_amountController.text.trim());
      final id = await WalletService(Supabase.instance.client).submitFundingRequest(
        amount: amount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      setState(() => _successId = id);
    } catch (error) {
      setState(() => _error = mapRpcError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibility = WalletEligibility(profile: widget.profile);

    if (!eligibility.canRequestFunding) {
      return Center(
        child: PremiumCard(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'Funding unavailable',
            message: eligibility.fundingLockReason,
            action: FilledButton(
              onPressed: () => context.go('/app'),
              child: const Text('Back to dashboard'),
            ),
          ),
        ),
      );
    }

    if (_successId != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: PremiumCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
                  ),
                  const SizedBox(height: 20),
                  Text('Funding request submitted', style: AppTypography.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Your request is pending admin review. You will see the outcome here once reviewed.',
                    style: AppTypography.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormPageHeader(
                title: 'Request funding',
                subtitle: 'Submit an amount for admin approval. No real money is moved.',
              ),
              const SizedBox(height: 24),
              PremiumCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (USD)',
                          prefixText: '\$ ',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final amount = double.tryParse(v?.trim() ?? '');
                          if (amount == null || amount <= 0) return 'Enter a valid amount';
                          if (amount > 10000000) return 'Maximum request is \$10,000,000';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        maxLines: 2,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                              )
                            : const Text('Submit request'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
