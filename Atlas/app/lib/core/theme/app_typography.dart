import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography — Plus Jakarta Sans for a refined fintech feel.
abstract final class AppTypography {
  static TextStyle _display({required double size, required FontWeight weight}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: AppColors.textDark,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle _body({required double size, required FontWeight weight, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.textDark,
        height: 1.5,
      );

  static TextTheme textTheme = TextTheme(
    displayLarge: _display(size: 40, weight: FontWeight.w700),
    displayMedium: _display(size: 32, weight: FontWeight.w700),
    headlineLarge: _display(size: 28, weight: FontWeight.w700),
    headlineMedium: _display(size: 22, weight: FontWeight.w600),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    ),
    bodyLarge: _body(size: 16, weight: FontWeight.w400),
    bodyMedium: _body(size: 14, weight: FontWeight.w400),
    bodySmall: _body(size: 12, weight: FontWeight.w400, color: AppColors.textGrey),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.white,
      letterSpacing: 0.2,
    ),
  );

  static TextStyle get balance => GoogleFonts.plusJakartaSans(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
        letterSpacing: -1.2,
        height: 1.0,
      );

  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      );
}
