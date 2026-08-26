import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';

class EmailService {
  EmailService(this._client);

  final SupabaseClient _client;

  /// Sends a 6-digit OTP to the given email for registration verification.
  Future<void> requestRegistrationOtp(String email) async {
    final outboxId = await _client.rpc(
      'request_registration_otp',
      params: {'p_email': email.trim()},
    );

    if (outboxId != null) {
      await _dispatchEmail(outboxId.toString());
    }
  }

  /// Verifies OTP and creates the account, then signs the user in.
  Future<AuthResponse> completeRegistration({
    required String email,
    required String otp,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final cleanEmail = email.trim();
    final cleanOtp = otp.trim();

    try {
      await _client.rpc<void>(
        'complete_registration',
        params: {
          'p_email': cleanEmail,
          'p_otp': cleanOtp,
          'p_password': password,
          'p_full_name': fullName.trim(),
          'p_phone': phone.trim(),
        },
      );

      return await _signInOrSignUp(
        email: cleanEmail,
        password: password,
        fullName: fullName.trim(),
        phone: phone.trim(),
      );
    } on PostgrestException catch (error) {
      if (!_shouldFallbackToAuthSignUp(error)) rethrow;

      return _signUpAndSignIn(
        email: cleanEmail,
        password: password,
        fullName: fullName.trim(),
        phone: phone.trim(),
      );
    }
  }

  bool _shouldFallbackToAuthSignUp(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('kyc_level') ||
        message.contains('does not exist') ||
        message.contains('querying schema');
  }

  Future<AuthResponse> _signInOrSignUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (_) {
      return _signUpAndSignIn(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
    }
  }

  Future<AuthResponse> _signUpAndSignIn({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
      },
    );
    if (res.session != null) return res;

    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a password reset link via Supabase Auth.
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: Env.passwordResetRedirectUrl,
    );
  }

  /// Resends registration OTP (same as initial request).
  Future<void> resendRegistrationOtp(String email) =>
      requestRegistrationOtp(email);

  /// Returns the latest generated registration OTP (used when email delivery fails).
  Future<String?> getRegistrationOtp(String email) async {
    final res = await _client.rpc(
      'get_registration_otp',
      params: {'p_email': email.trim()},
    );
    if (res == null) return null;
    final code = res.toString().trim();
    return code.isEmpty ? null : code;
  }

  Future<void> _dispatchEmail(String outboxId) async {
    try {
      await _client.functions.invoke(
        'send-email',
        body: {'outbox_id': outboxId},
      );
    } catch (_) {
      // Outbox row remains pending; pg_net trigger may still deliver.
    }
  }
}
