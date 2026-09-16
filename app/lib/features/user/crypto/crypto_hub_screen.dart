import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../core/widgets/responsive_layout.dart';
import 'crypto_assets.dart';
import 'crypto_widgets.dart';

class CryptoHubScreen extends StatelessWidget {
  const CryptoHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = CryptoCatalog.totalFiatNgn;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Crypto', style: AppTypography.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Hold, buy, and move digital assets alongside your TrustVault wallet.',
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppDecorations.heroCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio value',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCryptoFiat(total),
                      style: AppTypography.textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+${formatCryptoFiat(total * 0.018)} today',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: AppColors.accentGoldLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Actions'),
              const SizedBox(height: 14),
              QuickActionGrid(
                children: [
                  QuickActionTile(
                    label: 'Deposit',
                    icon: Icons.download_rounded,
                    enabled: true,
                    onTap: () => context.go('/app/crypto/deposit'),
                  ),
                  QuickActionTile(
                    label: 'Buy',
                    icon: Icons.shopping_cart_outlined,
                    enabled: true,
                    onTap: () => context.go('/app/crypto/buy'),
                  ),
                  QuickActionTile(
                    label: 'Send',
                    icon: Icons.send_rounded,
                    enabled: true,
                    onTap: () => context.go('/app/crypto/send'),
                  ),
                  QuickActionTile(
                    label: 'Withdraw',
                    icon: Icons.account_balance_outlined,
                    enabled: true,
                    onTap: () => context.go('/app/crypto/withdraw'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Balances'),
              const SizedBox(height: 12),
              for (final asset in CryptoCatalog.assets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CryptoAssetAvatar(asset: asset),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.name,
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                asset.symbol,
                                style: AppTypography.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${asset.balanceLabel} ${asset.symbol}',
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              formatCryptoFiat(asset.fiatValueNgn),
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${asset.changePercent >= 0 ? '+' : ''}${asset.changePercent.toStringAsFixed(1)}%',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: asset.changePercent >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              PremiumCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.secondaryBlue, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Crypto transfers settle on-chain. Always confirm the network and address before sending.',
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: AppColors.textGrey,
                        ),
                      ),
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
}
