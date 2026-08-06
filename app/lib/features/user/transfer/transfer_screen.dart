import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/wallet_eligibility.dart';
import '../../../models/profile.dart';
import '../../../models/wallet_account.dart';
import '../../../services/wallet_service.dart';
import '../../shared/state_widgets.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    required this.profile,
    required this.account,
    required this.availableBalance,
  });

  final Profile profile;
  final WalletAccount account;
  final double availableBalance;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = false;
  bool _confirming = false;
  String? _error;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  double get _resultingBalance =>
      widget.availableBalance - (_amount ?? 0);

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletService(Supabase.instance.client).transferFunds(
        recipient: _recipientController.text.trim(),
        amount: _amount!,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (mounted) context.go('/app/history');
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

    if (!eligibility.canTransfer) {
      return Center(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'Transfers unavailable',
          message: eligibility.transferLockReason,
          action: ElevatedButton(
            onPressed: () => context.go('/app'),
            child: const Text('Back to dashboard'),
          ),
        ),
      );
    }

    if (_confirming) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Confirm transfer', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    _ConfirmRow(label: 'Recipient', value: _recipientController.text.trim()),
                    _ConfirmRow(label: 'Amount', value: formatNaira(_amount!)),
                    _ConfirmRow(
                      label: 'Balance after',
                      value: formatNaira(_resultingBalance),
                    ),
                    if (_noteController.text.trim().isNotEmpty)
                      _ConfirmRow(label: 'Note', value: _noteController.text.trim()),
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
                          : const Text('Confirm & send'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loading ? null : () => setState(() => _confirming = false),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
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
              Text('Transfer', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Available: ${formatNaira(widget.availableBalance)}',
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
                          controller: _recipientController,
                          decoration: const InputDecoration(
                            labelText: 'Recipient email or account number',
                          ),
                          validator: (v) =>
                              v == null || v.trim().length < 3 ? 'Enter recipient details' : null,
                        ),
                        const SizedBox(height: 16),
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
                            if (amount > widget.availableBalance) {
                              return 'Insufficient balance';
                            }
                            if (amount > 5000000) return 'Maximum transfer is \$5,000,000';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(labelText: 'Note (optional)'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _confirming = true;
                                _error = null;
                              });
                            }
                          },
                          child: const Text('Review transfer'),
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

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
