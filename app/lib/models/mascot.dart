// import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';
import 'package:shared_preferences/shared_preferences.dart';


// Mascot Model
// each mascot has a unique mascotId, but other attributes can be the same
class Mascot {
  String mascotName; //common name of the mascot
  int mascotId; //unique identifier
  double rarity; //0.0 to 1.0, the lower the rarer
  int piId; //the pi that this mascot belongs to
  int respawnTime; //in minutes
  int coins; //coins to challenge

  Mascot(
    this.mascotName,
    this.mascotId,
    this.rarity,
    this.piId,
    this.respawnTime,
    this.coins,
  );

  static toMap(Mascot mascot) {
    return {
      'mascotName': mascot.mascotName,
      'mascotId': mascot.mascotId,
      'rarity': mascot.rarity,
      'piId': mascot.piId,
      'respawnTime': mascot.respawnTime,
      'coins': mascot.coins,
    };
  }

  factory Mascot.fromMap(Map<String, dynamic> map) {
    return Mascot(
      map['mascotName'],
      map['mascotId'],
      map['rarity'],
      map['piId'],
      map['respawnTime'],
      map['coins'],
    );
  }
}


// storage to save highest mascotId locally
class MascotStorageService {
  static const String _keyHighestMascotId = 'highest_mascot_id';

  /// Save highest mascot ID
  Future<void> saveHighestMascotId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHighestMascotId, id);
  }

  /// Load the saved highest mascot ID
  Future<int> getHighestMascotId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyHighestMascotId) ?? 0;
  }

  /// Update the highest ID only if new ID is larger
  Future<void> updateHighestMascotId(int newId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyHighestMascotId) ?? 0;

    if (newId > current) {
      await prefs.setInt(_keyHighestMascotId, newId);
    }
  }
}

