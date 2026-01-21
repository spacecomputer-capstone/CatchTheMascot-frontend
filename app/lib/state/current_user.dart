import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/user.dart';

class CurrentUser {
  static User? user;
  static bool get isLoggedIn => user != null;

  static Future<void> set(User u) async {
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(u.toJson()));
  }

  static Future<void> clear() async {
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  /// Call this once on app startup
  static Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('current_user');
    if (json != null) {
      user = User.fromJson(jsonDecode(json));
    }
  }
}