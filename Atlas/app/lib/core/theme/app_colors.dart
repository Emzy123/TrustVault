import 'dart:ui' show Color;

/// Atlas design tokens — teal / peach fintech palette from design samples.
abstract final class AppColors {
  /// Primary brand teal (login buttons, active states).
  static const primaryNavy = Color(0xFF0F5C5B);
  static const darkNavy = Color(0xFF0A4544);
  static const secondaryBlue = Color(0xFF147A78);
  static const primaryBlue = Color(0xFF1A6B69);

  /// Warm peach accent (secondary CTAs).
  static const accentGold = Color(0xFFF3C9B5);
  static const accentGoldLight = Color(0xFFF8DCCE);

  static const neutralLightGrey = Color(0xFFF5F3F0);
  static const lightGrey = Color(0xFFFAFAF8);
  static const borderGrey = Color(0xFFE6E2DC);
  static const textGrey = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const white = Color(0xFFFFFFFF);
  static const error = Color(0xFFDC2626);
  static const success = Color(0xFF0F5C5B);
  static const warning = Color(0xFFD97706);
  static const surfaceLight = Color(0xFFFAFAF8);
  static const textDark = Color(0xFF111827);

  static const navBarBg = Color(0xFAFFFFFF);

  /// Explicit Atlas aliases used by welcome / marketing surfaces.
  static const brandTeal = primaryNavy;
  static const brandPeach = accentGold;
}
