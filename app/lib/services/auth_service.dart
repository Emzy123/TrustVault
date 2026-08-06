import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    try {
      return await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
    } on AuthException {
      if (cleanEmail.endsWith('@trustvault.demo')) {
        try {
          final prefix = cleanEmail.split('@').first;
          final name = prefix[0].toUpperCase() + prefix.substring(1);
          await _client.auth.signUp(
            email: cleanEmail,
            password: password,
            data: {
              'full_name': '$name Demo',
              'phone': '+2348000000000',
            },
          );
          return await _client.auth.signInWithPassword(
            email: cleanEmail,
            password: password,
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: const String.fromEnvironment(
        'PASSWORD_RESET_REDIRECT',
        defaultValue: 'http://localhost:3000',
      ),
    );
  }
}

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  Future<Profile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    var data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      // Profile should exist via auth trigger; retry once after brief delay
      await Future<void>.delayed(const Duration(milliseconds: 500));
      data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    }

    if (data == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(data));
  }
}
