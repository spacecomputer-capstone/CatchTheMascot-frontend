import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mascot.dart';

class MascotService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches a mascot by its document ID (e.g., 'mascot_1').
  Future<Mascot?> fetchMascot(String mascotDocId) async {
    try {
      DocumentSnapshot doc = await _db.collection('mascots').doc(mascotDocId).get();

      if (doc.exists && doc.data() != null) {
        return Mascot.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        print('Mascot $mascotDocId not found');
        return null;
      }
    } catch (e) {
      print('Error fetching mascot: $e');
      return null;
    }
  }
}
