import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
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

  double get _resultingBalance => widget.availableBalance - (_amount ?? 0);

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
    final eligibility = WalletEligibility(profile: widget.profile);

    if (!eligibility.canTransfer) {
      return Center(
        child: PremiumCard(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'Transfers unavailable',
            message: eligibility.transferLockReason,
            action: FilledButton(
              onPressed: () => context.go('/app'),
              child: const Text('Back to dashboard'),
            ),
          ),
        ),
      );
    }

    if (_confirming) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormPageHeader(
                  title: 'Confirm transfer',
                  subtitle: 'Review the details before sending',
                ),
                const SizedBox(height: 24),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppDecorations.navyGradient,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'You are sending',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatNaira(_amount!),
                              style: AppTypography.balance.copyWith(fontSize: 36),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      DetailRow(label: 'Recipient', value: formatAccountNumber(_recipientController.text.trim())),
                      DetailRow(label: 'Balance after', value: formatNaira(_resultingBalance)),
                      if (_noteController.text.trim().isNotEmpty)
                        DetailRow(label: 'Note', value: _noteController.text.trim()),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
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
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _loading ? null : () => setState(() => _confirming = false),
                        child: const Text('Go back'),
                      ),
                    ],
                  ),
                ),
              ],
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
              FormPageHeader(
                title: 'Transfer',
                subtitle: 'Available: ${formatNaira(widget.availableBalance)}',
              ),
              const SizedBox(height: 24),
              PremiumCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _recipientController,
                        decoration: const InputDecoration(
                          labelText: 'Recipient email or account number',
                          prefixIcon: Icon(Icons.person_outline_rounded),
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
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final amount = double.tryParse(v?.trim() ?? '');
                          if (amount == null || amount <= 0) return 'Enter a valid amount';
                          if (amount > widget.availableBalance) return 'Insufficient balance';
                          final limit = widget.profile.dailyTransferLimit;
                          if (limit <= 0) {
                            return 'Complete Level 1 verification to unlock transfers';
                          }
                          if (amount > limit) {
                            return 'Your daily limit is ${widget.profile.formattedDailyLimit}';
                          }
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
                      const SizedBox(height: 24),
                      FilledButton(
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
            ],
          ),
        ),
      ),
    );
  }
}
