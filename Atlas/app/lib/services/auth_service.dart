import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
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
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
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
      redirectTo: Env.passwordResetRedirectUrl,
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
