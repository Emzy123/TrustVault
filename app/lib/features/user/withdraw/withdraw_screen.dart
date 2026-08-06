import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/wallet_eligibility.dart';
import '../../../models/profile.dart';
import '../../../models/wallet_account.dart';
import '../../../models/wallet_models.dart';
import '../../../services/wallet_service.dart';
import '../../shared/state_widgets.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({
    super.key,
    required this.profile,
    required this.account,
    required this.availableBalance,
  });

  final Profile profile;
  final WalletAccount account;
  final double availableBalance;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _transactionId;

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
      final id = await WalletService(Supabase.instance.client).requestWithdrawal(
        amount: amount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      setState(() => _transactionId = id);
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

    if (!eligibility.canWithdraw) {
      return Center(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'Withdrawals unavailable',
          message: eligibility.withdrawLockReason,
          action: ElevatedButton(
            onPressed: () => context.go('/app'),
            child: const Text('Back to dashboard'),
          ),
        ),
      );
    }

    if (_transactionId != null) {
      return WithdrawPendingView(
        amount: double.parse(_amountController.text.trim()),
        transactionId: _transactionId!,
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
              Text('Withdraw', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Available: ${formatNaira(widget.availableBalance)} · Daily limit \$2,000,000',
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
                        Text(
                          'Withdrawals enter a genuine pending review state. A Super Admin will approve or decline with a real reason.',
                          style: theme.textTheme.bodySmall,
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
                              return 'Insufficient available balance';
                            }
                            if (amount > 2000000) return 'Maximum withdrawal is \$2,000,000';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(labelText: 'Note (optional)'),
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
                              : const Text('Submit for review'),
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

class WithdrawPendingView extends StatelessWidget {
  const WithdrawPendingView({
    super.key,
    required this.amount,
    required this.transactionId,
  });

  final double amount;
  final String transactionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    TransactionStatus.pending.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Withdrawal in review', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  formatNaira(amount),
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your request is being reviewed. This is a real pending state — you will see the actual outcome in your history once a Super Admin resolves it.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/app/history/$transactionId'),
                  child: const Text('View in history'),
                ),
                TextButton(
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
