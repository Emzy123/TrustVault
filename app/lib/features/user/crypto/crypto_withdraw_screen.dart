import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import 'crypto_assets.dart';
import 'crypto_widgets.dart';

class CryptoWithdrawScreen extends StatefulWidget {
  const CryptoWithdrawScreen({super.key});

  @override
  State<CryptoWithdrawScreen> createState() => _CryptoWithdrawScreenState();
}

class _CryptoWithdrawScreenState extends State<CryptoWithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  late CryptoAsset _asset;
  String _destination = 'TrustVault Naira wallet';
  bool _loading = false;
  bool _confirming = false;
  bool _submitted = false;
  String? _reference;

  static const _destinations = [
    'TrustVault Naira wallet',
    'Linked bank account',
  ];

  /// Rough illustrative rates in NGN per unit.
  static const _ratesNgn = {
    'BTC': 151800000.0,
    'ETH': 3842000.0,
    'USDT': 1595.0,
    'SOL': 89600.0,
  };

  @override
  void initState() {
    super.initState();
    _asset = CryptoCatalog.assets.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _rate => _ratesNgn[_asset.symbol] ?? 1;

  double get _payoutNgn => _amount * _rate;

  String get _amountLabel {
    if (_amount >= 100) return _amount.toStringAsFixed(2);
    if (_amount >= 1) return _amount.toStringAsFixed(4);
    return _amount.toStringAsFixed(8);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await simulateCryptoLatency();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = true;
      _reference = 'CW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return CryptoResultView(
        icon: Icons.account_balance_outlined,
        title: 'Withdrawal queued',
        message:
            'Your crypto cash-out is pending settlement. Naira will arrive once the conversion clears.',
        details: [
          ('Reference', _reference ?? '—'),
          ('Sold', '$_amountLabel ${_asset.symbol}'),
          ('Payout', formatNaira(_payoutNgn)),
          ('Destination', _destination),
          ('Status', 'Queued for processing'),
        ],
      );
    }

    if (_confirming) {
      return CryptoFormScaffold(
        title: 'Confirm withdrawal',
        subtitle: 'Sell crypto and receive Naira to your chosen destination.',
        child: PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row(label: 'Asset', value: _asset.symbol),
              _Row(label: 'Amount', value: '$_amountLabel ${_asset.symbol}'),
              _Row(label: 'Rate', value: '${formatNaira(_rate)} / ${_asset.symbol}'),
              _Row(label: 'You receive', value: formatNaira(_payoutNgn)),
              _Row(label: 'Destination', value: _destination),
              if (_destination == 'Linked bank account')
                _Row(
                  label: 'Account',
                  value: _accountController.text.trim().isEmpty
                      ? '—'
                      : _accountController.text.trim(),
                ),
              const SizedBox(height: 8),
              Text(
                'Withdrawals typically settle within a few minutes during banking hours.',
                style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm withdrawal'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _confirming = false),
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
      );
    }

    return CryptoFormScaffold(
      title: 'Withdraw crypto',
      subtitle: 'Convert holdings to Naira and cash out to your wallet or bank.',
      child: Form(
        key: _formKey,
        child: PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Asset',
                style: AppTypography.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 12),
              CryptoAssetPicker(
                selected: _asset,
                onChanged: (asset) => setState(() => _asset = asset),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${_asset.balanceLabel} ${_asset.symbol}',
                style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (${_asset.symbol})',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  suffixIcon: TextButton(
                    onPressed: () {
                      _amountController.text = _asset.balanceLabel;
                      setState(() {});
                    },
                    child: const Text('Max'),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) return 'Enter an amount';
                  if (amount > _asset.balance) return 'Exceeds available balance';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _destination,
                decoration: const InputDecoration(
                  labelText: 'Payout destination',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  for (final item in _destinations)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _destination = value);
                },
              ),
              if (_destination == 'Linked bank account') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accountController,
                  decoration: const InputDecoration(
                    labelText: 'Bank account number',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 10) return 'Enter a valid account number';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.neutralLightGrey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _Row(
                  label: 'Estimated payout',
                  value: formatNaira(_payoutNgn),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _confirming = true);
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
