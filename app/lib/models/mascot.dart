// import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';

class Mascot {
  String mascotName;
  int mascotId;
  double rarity;
  int piId;
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
