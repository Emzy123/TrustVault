import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);
    final eligibility = WalletEligibility(profile: widget.profile);

    if (!eligibility.canRequestFunding) {
      return Center(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'Funding unavailable',
          message: eligibility.fundingLockReason,
          action: ElevatedButton(
            onPressed: () => context.go('/app'),
            child: const Text('Back to dashboard'),
          ),
        ),
      );
    }

    if (_successId != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text('Funding request submitted', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Your request is pending admin review. You will see the outcome here once reviewed.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
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
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Request funding', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Submit an amount for admin approval. No real money is moved.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
