import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared radii, shadows, and gradients for Atlas.
abstract final class AppDecorations {
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
  static const radiusXl = 32.0;

  static const cardShadow = [
    BoxShadow(
      color: Color(0x140F5C5B),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const heroShadow = [
    BoxShadow(
      color: Color(0x330F5C5B),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];

  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A4544),
      Color(0xFF0F5C5B),
      Color(0xFF147A78),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8DCCE),
      AppColors.accentGold,
      Color(0xFFE8A98A),
    ],
  );

  static const authPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF083837),
      Color(0xFF0F5C5B),
      Color(0xFF1A6B69),
    ],
  );

  static const pageBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFAFAF8),
        Color(0xFFF5F3F0),
      ],
    ),
  );

  static BoxDecoration glassCard({Color? tint}) => BoxDecoration(
        color: (tint ?? AppColors.white).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.8)),
        boxShadow: cardShadow,
      );

  static BoxDecoration heroCard() => BoxDecoration(
        gradient: navyGradient,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: heroShadow,
      );
}
