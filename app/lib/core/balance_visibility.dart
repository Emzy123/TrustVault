import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether monetary balances should be shown or masked on dashboards.
abstract final class BalanceVisibility {
  static const _key = 'balances_visible_v1';
  static const masked = '••••••';

  static Future<bool> isVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> setVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, visible);
  }

  static String maskOrFormat(bool visible, String formatted) =>
      visible ? formatted : masked;
}
