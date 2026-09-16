import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import 'crypto_assets.dart';
import 'crypto_widgets.dart';

class CryptoSendScreen extends StatefulWidget {
  const CryptoSendScreen({super.key});

  @override
  State<CryptoSendScreen> createState() => _CryptoSendScreenState();
}

class _CryptoSendScreenState extends State<CryptoSendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  late CryptoAsset _asset;
  late String _network;
  bool _loading = false;
  bool _confirming = false;
  bool _submitted = false;
  String? _txId;

  @override
  void initState() {
    super.initState();
    _asset = CryptoCatalog.assets.first;
    _network = _asset.networks.first;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

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
      _txId = '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}a7f2';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return CryptoResultView(
        icon: Icons.outbound_outlined,
        title: 'Transfer broadcast',
        message:
            'Your ${_asset.symbol} send is awaiting network confirmation. Track progress from Crypto balances once confirmed.',
        details: [
          ('Asset', '$_amountLabel ${_asset.symbol}'),
          ('Network', _network),
          ('To', _shortAddress(_addressController.text.trim())),
          ('Tx ID', _shortAddress(_txId ?? '')),
          ('Status', 'Pending confirmation'),
        ],
      );
    }

    if (_confirming) {
      return CryptoFormScaffold(
        title: 'Confirm send',
        subtitle: 'Double-check the recipient address and network.',
        child: PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row(label: 'Asset', value: _asset.symbol),
              _Row(label: 'Amount', value: '$_amountLabel ${_asset.symbol}'),
              _Row(label: 'Network', value: _network),
              _Row(label: 'Recipient', value: _shortAddress(_addressController.text.trim())),
              _Row(label: 'Network fee', value: 'Covered by TrustVault'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Crypto transfers are irreversible. Sending to the wrong address or network can result in permanent loss.',
                  style: AppTypography.textTheme.bodySmall,
                ),
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
                    : const Text('Send now'),
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
      title: 'Send crypto',
      subtitle: 'Transfer assets from your TrustVault crypto wallet to an external address.',
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
                onChanged: (asset) {
                  setState(() {
                    _asset = asset;
                    _network = asset.networks.first;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${_asset.balanceLabel} ${_asset.symbol}',
                style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              CryptoNetworkPicker(
                networks: _asset.networks,
                selected: _network,
                onChanged: (network) => setState(() => _network = network),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Recipient address',
                  prefixIcon: Icon(Icons.wallet_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 20) return 'Enter a valid wallet address';
                  return null;
                },
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
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) return 'Enter an amount';
                  if (amount > _asset.balance) return 'Exceeds available balance';
                  return null;
                },
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

  String _shortAddress(String value) {
    if (value.length <= 16) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 6)}';
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
