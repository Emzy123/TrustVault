import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import 'crypto_assets.dart';

class CryptoAssetAvatar extends StatelessWidget {
  const CryptoAssetAvatar({
    super.key,
    required this.asset,
    this.size = 40,
  });

  final CryptoAsset asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CryptoUi.tint(asset.color, 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        asset.symbol.substring(0, asset.symbol.length.clamp(0, 1)),
        style: TextStyle(
          color: asset.color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

class CryptoAssetPicker extends StatelessWidget {
  const CryptoAssetPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CryptoAsset selected;
  final ValueChanged<CryptoAsset> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final asset in CryptoCatalog.assets)
          ChoiceChip(
            selected: asset.symbol == selected.symbol,
            label: Text('${asset.symbol} · ${asset.name}'),
            avatar: CryptoAssetAvatar(asset: asset, size: 22),
            selectedColor: CryptoUi.tint(AppColors.primaryNavy, 0.14),
            backgroundColor: AppColors.white,
            side: BorderSide(
              color: asset.symbol == selected.symbol
                  ? AppColors.primaryNavy
                  : AppColors.borderGrey,
            ),
            labelStyle: AppTypography.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            onSelected: (_) => onChanged(asset),
          ),
      ],
    );
  }
}

class CryptoNetworkPicker extends StatelessWidget {
  const CryptoNetworkPicker({
    super.key,
    required this.networks,
    required this.selected,
    required this.onChanged,
  });

  final List<String> networks;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Network',
        prefixIcon: Icon(Icons.hub_outlined),
      ),
      items: [
        for (final network in networks)
          DropdownMenuItem(value: network, child: Text(network)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class CryptoResultView extends StatelessWidget {
  const CryptoResultView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.details = const [],
    this.primaryLabel = 'Back to Crypto',
    this.onPrimary,
  });

  final String title;
  final String message;
  final IconData icon;
  final List<(String, String)> details;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                  child: Icon(icon, size: 48, color: AppColors.success),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: AppTypography.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: AppTypography.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  for (final entry in details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.$1,
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              entry.$2,
                              textAlign: TextAlign.end,
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: onPrimary ?? () => context.go('/app/crypto'),
                  child: Text(primaryLabel),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go('/app'),
                  child: const Text('Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CryptoCopyField extends StatelessWidget {
  const CryptoCopyField({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTypography.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.neutralLightGrey,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderGrey),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CryptoFormScaffold extends StatelessWidget {
  const CryptoFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

String formatCryptoFiat(double amount) => formatNaira(amount);

Future<void> simulateCryptoLatency() =>
    Future<void>.delayed(const Duration(milliseconds: 1100));
