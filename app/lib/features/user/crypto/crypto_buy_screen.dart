import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import 'crypto_assets.dart';
import 'crypto_widgets.dart';

class CryptoBuyScreen extends StatefulWidget {
  const CryptoBuyScreen({super.key});

  @override
  State<CryptoBuyScreen> createState() => _CryptoBuyScreenState();
}

class _CryptoBuyScreenState extends State<CryptoBuyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '50000');
  late CryptoAsset _asset;
  bool _loading = false;
  bool _confirming = false;
  bool _submitted = false;
  String? _reference;

  /// Rough illustrative rates in NGN per unit.
  static const _ratesNgn = {
    'BTC': 152500000.0,
    'ETH': 3856000.0,
    'USDT': 1600.0,
    'SOL': 90100.0,
  };

  @override
  void initState() {
    super.initState();
    _asset = CryptoCatalog.assets.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _spendNgn => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _rate => _ratesNgn[_asset.symbol] ?? 1;

  double get _receiveAmount => _spendNgn <= 0 ? 0 : _spendNgn / _rate;

  String get _receiveLabel {
    final amount = _receiveAmount;
    if (amount >= 100) return amount.toStringAsFixed(2);
    if (amount >= 1) return amount.toStringAsFixed(4);
    return amount.toStringAsFixed(8);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await simulateCryptoLatency();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = true;
      _reference = 'CB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return CryptoResultView(
        icon: Icons.check_circle_outline_rounded,
        title: 'Purchase submitted',
        message:
            'Your ${_asset.symbol} buy order is being processed. Funds will appear in your crypto balance once settled.',
        details: [
          ('Reference', _reference ?? '—'),
          ('You spend', formatNaira(_spendNgn)),
          ('You receive', '$_receiveLabel ${_asset.symbol}'),
          ('Status', 'Processing'),
        ],
      );
    }

    if (_confirming) {
      return CryptoFormScaffold(
        title: 'Confirm purchase',
        subtitle: 'Review the details before placing your order.',
        child: PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(label: 'Asset', value: '${_asset.name} (${_asset.symbol})'),
              _DetailRow(label: 'Spend', value: formatNaira(_spendNgn)),
              _DetailRow(label: 'Rate', value: '${formatNaira(_rate)} / ${_asset.symbol}'),
              _DetailRow(label: 'You receive', value: '$_receiveLabel ${_asset.symbol}'),
              _DetailRow(label: 'Payment source', value: 'TrustVault wallet (NGN)'),
              const SizedBox(height: 8),
              Text(
                'Market rates refresh continuously. The final fill may vary slightly at execution.',
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
                    : const Text('Place order'),
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
      title: 'Buy crypto',
      subtitle: 'Purchase digital assets instantly using your TrustVault Naira balance.',
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (NGN)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount < 1000) {
                    return 'Enter at least ₦1,000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.neutralLightGrey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Indicative rate',
                      value: '${formatNaira(_rate)} / ${_asset.symbol}',
                    ),
                    _DetailRow(
                      label: 'You receive',
                      value: '$_receiveLabel ${_asset.symbol}',
                    ),
                  ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
