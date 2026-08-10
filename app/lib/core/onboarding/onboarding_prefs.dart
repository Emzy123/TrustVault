import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the pre-auth onboarding carousel has been completed.
abstract final class OnboardingPrefs {
  static const _key = 'onboarding_completed_v1';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
