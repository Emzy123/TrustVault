import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import 'crypto_assets.dart';
import 'crypto_widgets.dart';

class CryptoDepositScreen extends StatefulWidget {
  const CryptoDepositScreen({super.key});

  @override
  State<CryptoDepositScreen> createState() => _CryptoDepositScreenState();
}

class _CryptoDepositScreenState extends State<CryptoDepositScreen> {
  late CryptoAsset _asset;
  late String _network;
  bool _addressReady = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _asset = CryptoCatalog.assets.first;
    _network = _asset.networks.first;
  }

  Future<void> _generateAddress() async {
    setState(() => _loading = true);
    await simulateCryptoLatency();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _addressReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CryptoFormScaffold(
      title: 'Deposit crypto',
      subtitle: 'Receive assets to your Atlas crypto wallet on the selected network.',
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select asset',
              style: AppTypography.textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),
            CryptoAssetPicker(
              selected: _asset,
              onChanged: (asset) {
                setState(() {
                  _asset = asset;
                  _network = asset.networks.first;
                  _addressReady = false;
                });
              },
            ),
            const SizedBox(height: 20),
            CryptoNetworkPicker(
              networks: _asset.networks,
              selected: _network,
              onChanged: (network) {
                setState(() {
                  _network = network;
                  _addressReady = false;
                });
              },
            ),
            const SizedBox(height: 22),
            if (!_addressReady)
              FilledButton(
                onPressed: _loading ? null : _generateAddress,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get deposit address'),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CryptoUi.tint(_asset.color, 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CryptoUi.tint(_asset.color, 0.28)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 120, color: _asset.color),
                    const SizedBox(height: 8),
                    Text(
                      'Scan to deposit ${_asset.symbol}',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CryptoCopyField(
                label: '$_network address',
                value: _asset.depositAddress,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Only send ${_asset.symbol} on $_network. Assets sent on the wrong network may be unrecoverable.',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  setState(() => _addressReady = false);
                },
                child: const Text('Change asset or network'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
