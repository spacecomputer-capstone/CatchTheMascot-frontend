import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mascot.dart';

class MascotService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Mascot?> fetchMascot(String mascotDocId) async {
    try {
      final doc = await _db.collection('mascots').doc(mascotDocId).get();
      if (doc.exists) {
        return Mascot.fromMap(doc.data()!);
      } else {
        print("MascotService: Document $mascotDocId not found.");
      }
    } catch (e) {
      print("MascotService Error: $e");
    }
    return null;
  }
}
