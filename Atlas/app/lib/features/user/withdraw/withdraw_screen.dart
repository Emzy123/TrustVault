import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
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
    final eligibility = WalletEligibility(profile: widget.profile);

    if (!eligibility.canWithdraw) {
      return Center(
        child: PremiumCard(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'Withdrawals unavailable',
            message: eligibility.withdrawLockReason,
            action: FilledButton(
              onPressed: () => context.go('/app'),
              child: const Text('Back to dashboard'),
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormPageHeader(
                title: 'Withdraw',
                subtitle:
                    'Available: ${formatNaira(widget.availableBalance)} · Daily limit \$2,000,000',
              ),
              const SizedBox(height: 24),
              PremiumCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondaryBlue.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: AppColors.secondaryBlue.withValues(alpha: 0.8)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Withdrawals enter a genuine pending review state. A Super Admin will approve or decline with a real reason.',
                                style: AppTypography.textTheme.bodySmall?.copyWith(
                                  color: AppColors.secondaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          if (amount > widget.availableBalance) return 'Insufficient available balance';
                          if (amount > 2000000) return 'Maximum withdrawal is \$2,000,000';
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
                            : const Text('Submit for review'),
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
                    color: AppColors.secondaryBlue.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, size: 48, color: AppColors.secondaryBlue),
                ),
                const SizedBox(height: 20),
                StatusPill(label: TransactionStatus.pending.label, color: AppColors.secondaryBlue),
                const SizedBox(height: 16),
                Text('Withdrawal in review', style: AppTypography.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(formatNaira(amount), style: AppTypography.balance.copyWith(color: AppColors.textDark)),
                const SizedBox(height: 12),
                Text(
                  'Your request is being reviewed. This is a real pending state — you will see the actual outcome in your history once a Super Admin resolves it.',
                  style: AppTypography.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
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
