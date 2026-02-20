import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class CurrentUser {
  static User? user;
  static bool get isLoggedIn => user != null;

  // Use SAME databaseId as CatchScreen
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'mascot-database',
  );

  static Future<void> set(User u) async {
    user = u;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', u.username);
  }

  static Future<void> clear() async {
    user = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  static Future<void> restoreIfPossible() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (username == null || user != null) return;

    try {
      final doc =
          await _firestore.collection('users').doc(username).get();

      if (!doc.exists) {
        await clear();
        return;
      }

      final data = doc.data()!;

      user = User(
        data['username'] ?? '',
        '', // never restore password
        List<int>.from(data['caughtMascots'] ?? []),
        List<int>.from(data['uncaughtMascots'] ?? []),
        List<int>.from(data['visitedPis'] ?? []),
        data['coins'] ?? 0,
      );
    } catch (e) {
      await clear();
    }
  }
}