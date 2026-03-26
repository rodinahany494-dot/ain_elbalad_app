import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static String? _token;
  static String? _displayName;
  static String? _email;
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      _displayName = prefs.getString('display_name');
      _email = prefs.getString('email');
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> saveAuth({
    required String token,
    String? displayName,
    String? email,
  }) async {
    _token = token;
    if (displayName != null && displayName.trim().isNotEmpty) {
      _displayName = displayName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      _email = email.trim();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      if (_displayName != null) {
        await prefs.setString('display_name', _displayName!);
      }
      if (_email != null) {
        await prefs.setString('email', _email!);
      }
    } catch (_) {}
  }

  static Future<String?> token() async {
    await _ensureLoaded();
    return _token;
  }

  static Future<String?> displayName() async {
    await _ensureLoaded();
    return _displayName;
  }

  static Future<String?> email() async {
    await _ensureLoaded();
    return _email;
  }

  static Future<void> saveDisplayName(String name) async {
    _displayName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('display_name', name);
    } catch (_) {}
  }

  static Future<void> clear() async {
    _token = null;
    _displayName = null;
    _email = null;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('display_name');
      await prefs.remove('email');
    } catch (_) {}
  }
}
