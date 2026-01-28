import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Adds a caught mascot ID to the user's list of caught mascots.
  /// 
  /// [userId] The ID of the user document (e.g. "1").
  /// [mascotId] The ID of the mascot caught (e.g. 1).
  Future<void> addCaughtMascot(String userId, int mascotId) async {
    try {
      // mascotId is stored as a string in the User model's list, 
      // but let's check the database schema from the screenshot.
      // The screenshot shows "caughtMascots" (array).
      // The elements inside usually match the type.
      // The User model says List<String> caughtMascots.
      // However, Mascot model says int mascotId.
      // I will convert to String to match the User model definition for now,
      // or check if I should use int.
      // Screenshot shows "1" as document ID for user, and fields.
      // I will stick to what the User model defines: List<String>.
      
      await _db.collection('users').doc(userId).update({
        'caughtMascots': FieldValue.arrayUnion([mascotId.toString()])
      });
      print('Added mascot $mascotId to user $userId caught list.');
    } catch (e) {
      print('Error updating caught mascots: $e');
      throw e;
    }
  }
}
