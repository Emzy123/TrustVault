import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: '\$',
  decimalDigits: 2,
);

/// Formats [amount] as a USD dollar string, e.g. "$1,234.56".
String formatNaira(num amount) => _currencyFormat.format(amount);

/// Alias – prefer this name for new code.
String formatCurrency(num amount) => _currencyFormat.format(amount);

String formatDate(DateTime date) => DateFormat.yMMMd().add_jm().format(date.toLocal());

String formatShortDate(DateTime date) => DateFormat.MMMd().format(date.toLocal());

/// Formats date regulated to local country timezone with time zone indicator
String formatCountryDateTime(DateTime date) {
  final local = date.toLocal();
  final formatted = DateFormat.yMMMd().add_jm().format(local);
  final timeZoneName = local.timeZoneName;
  return timeZoneName.isNotEmpty ? '$formatted ($timeZoneName)' : formatted;
}

/// Formats raw 10-digit account numbers for display (e.g. "3081 928 471").
String formatAccountNumber(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length == 10) {
    return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4, 7)} ${digitsOnly.substring(7)}';
  }
  return raw;
}

String formatErrorMessage(Object error) {
  String rawMessage;
  if (error is AuthException) {
    rawMessage = error.message;
  } else if (error is Exception) {
    rawMessage = error.toString().replaceAll('Exception: ', '');
  } else {
    rawMessage = error.toString();
  }

  final trimmed = rawMessage.trim();
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final msg = decoded['message'] ?? decoded['msg'] ?? decoded['error_description'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          rawMessage = msg.toString().trim();
        }
      }
    } catch (_) {}
  }

  if (rawMessage.contains('Database error querying schema') ||
      rawMessage.contains('Database error finding user') ||
      rawMessage.contains('unexpected_failure')) {
    return 'This account cannot sign in (missing auth identity records). '
        'Run supabase/patch_fix_create_user_auth.sql in the Supabase SQL Editor, '
        'then try again. Default password for super-admin-created users is TrustVault123! unless you set another.';
  }

  if (rawMessage.contains('Could not find the function') ||
      rawMessage.contains('function public.get_super_admin_metrics') ||
      rawMessage.contains('function public.get_platform_analytics') ||
      rawMessage.contains('function public.submit_funding_request') ||
      rawMessage.contains('function public.review_kyc_submission') ||
      rawMessage.contains('function public.approve_funding_request') ||
      rawMessage.contains('function public.review_withdrawal')) {
    return 'Missing database function. Run "supabase/patch_missing_admin_rpcs.sql" in your Supabase SQL Editor.';
  }

  return rawMessage;
}
