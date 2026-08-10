import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared radii, shadows, and gradients for a consistent premium look.
abstract final class AppDecorations {
  static const radiusSm = 10.0;
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
  static const radiusXl = 32.0;

  static const cardShadow = [
    BoxShadow(
      color: Color(0x140F172A),
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
      color: Color(0x331B2A4A),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];

  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1B2A4A),
      Color(0xFF2F5C9E),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE8C872),
      AppColors.accentGold,
      Color(0xFF9A7209),
    ],
  );

  static const authPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B1220),
      Color(0xFF1B2A4A),
      Color(0xFF1E3A5F),
    ],
  );

  static const pageBackground = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFF8FAFC),
        Color(0xFFF1F5F9),
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
