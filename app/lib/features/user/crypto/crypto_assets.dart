import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CryptoAsset {
  const CryptoAsset({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.fiatValueNgn,
    required this.changePercent,
    required this.color,
    required this.networks,
    required this.depositAddress,
  });

  final String symbol;
  final String name;
  final double balance;
  final double fiatValueNgn;
  final double changePercent;
  final Color color;
  final List<String> networks;
  final String depositAddress;

  String get balanceLabel {
    if (balance >= 100) return balance.toStringAsFixed(2);
    if (balance >= 1) return balance.toStringAsFixed(4);
    return balance.toStringAsFixed(6);
  }
}

abstract final class CryptoCatalog {
  static const assets = <CryptoAsset>[
    CryptoAsset(
      symbol: 'BTC',
      name: 'Bitcoin',
      balance: 0.084210,
      fiatValueNgn: 12845000,
      changePercent: 2.4,
      color: Color(0xFFF7931A),
      networks: ['Bitcoin', 'Lightning'],
      depositAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
    ),
    CryptoAsset(
      symbol: 'ETH',
      name: 'Ethereum',
      balance: 1.250000,
      fiatValueNgn: 4820000,
      changePercent: -0.8,
      color: Color(0xFF627EEA),
      networks: ['Ethereum', 'Base', 'Arbitrum'],
      depositAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1',
    ),
    CryptoAsset(
      symbol: 'USDT',
      name: 'Tether',
      balance: 2450.00,
      fiatValueNgn: 3920000,
      changePercent: 0.1,
      color: Color(0xFF26A17B),
      networks: ['TRC-20', 'ERC-20', 'BEP-20'],
      depositAddress: 'TXyz9kPqRmN2vLwHsJcFdUeBgYa4pQr8Mn',
    ),
    CryptoAsset(
      symbol: 'SOL',
      name: 'Solana',
      balance: 18.640000,
      fiatValueNgn: 1680000,
      changePercent: 4.1,
      color: Color(0xFF9945FF),
      networks: ['Solana'],
      depositAddress: '7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDVJXtpsKV',
    ),
  ];

  static double get totalFiatNgn =>
      assets.fold(0, (sum, asset) => sum + asset.fiatValueNgn);

  static CryptoAsset bySymbol(String symbol) =>
      assets.firstWhere((a) => a.symbol == symbol, orElse: () => assets.first);
}

/// Soft brand tints used on crypto surfaces.
abstract final class CryptoUi {
  static Color tint(Color color, [double alpha = 0.12]) =>
      color.withValues(alpha: alpha);

  static const surfaceAccent = AppColors.secondaryBlue;
}
