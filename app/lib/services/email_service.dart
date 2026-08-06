import 'package:supabase_flutter/supabase_flutter.dart';

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
    await _client.rpc<String>(
      'complete_registration',
      params: {
        'p_email': email.trim(),
        'p_otp': otp.trim(),
        'p_password': password,
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
      },
    );

    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password reset link via Supabase Auth.
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _passwordResetRedirectUrl,
    );
  }

  /// Resends registration OTP (same as initial request).
  Future<void> resendRegistrationOtp(String email) =>
      requestRegistrationOtp(email);

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

  static String get _passwordResetRedirectUrl {
    // Web app origin; override via dart-define for production builds.
    const redirect = String.fromEnvironment(
      'PASSWORD_RESET_REDIRECT',
      defaultValue: 'http://localhost:3000',
    );
    return redirect;
  }
}
