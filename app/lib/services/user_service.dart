import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'mascot-database');

  /// Adds a mascotId to the user's caughtMascots array in Firestore.
  Future<void> addCaughtMascot(String userId, int mascotId) async {
    try {
      final userRef = _db.collection('users').doc(userId);

      await userRef.update({
        'caughtMascots': FieldValue.arrayUnion([mascotId]),
      });
      
      print("UserService: Successfully added mascot $mascotId to user $userId");
    } catch (e) {
      print("UserService Error: Failed to add caught mascot: $e");
      // If the user doc doesn't exist, we might want to create it or set it?
      // For now, assuming user exists.
    }
  }

  /// Checks if a mascot is already caught by the user.
  Future<bool> isMascotCaught(String userId, int mascotId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data()!.containsKey('caughtMascots')) {
        final List<dynamic> caught = doc.get('caughtMascots');
        return caught.contains(mascotId);
      }
    } catch (e) {
      print("UserService Error: Failed to check if mascot caught: $e");
    }
    return false;
  }
}
