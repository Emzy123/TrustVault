import 'package:flutter/foundation.dart';

/// Supabase configuration for the separate Atlas project.
/// Pass keys via --dart-define; do not reuse TrustVault credentials.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const _passwordResetRedirectBase = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT',
    defaultValue: '',
  );

  /// Supabase Auth redirect target after the user clicks the email link.
  static String get passwordResetRedirectUrl {
    String base = _passwordResetRedirectBase;
    if (base.isEmpty) {
      if (kIsWeb) {
        base = Uri.base.origin;
      } else {
        base = 'http://localhost:3000';
      }
    }
    final cleanBase = base.replaceAll(RegExp(r'/+$'), '');
    return '$cleanBase/reset-password';
  }
}
