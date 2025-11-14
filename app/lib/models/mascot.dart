import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';

class Mascot {

  int mascotId;
  Float rarity;
  int piId;
  int respawnTime; //in minutes

  Mascot(this.mascotId, this.rarity, this.piId, this.respawnTime);

  static toMap(Mascot mascot){
    return {
      'mascotId': mascot.mascotId,
      'rarity': mascot.rarity,
      'piId': mascot.piId,
      'respawnTime': mascot.respawnTime,
    };
  }

  factory Mascot.fromMap(Map<String, dynamic> map){
    return Mascot(
      map['mascotId'],
      map['rarity'],
      map['piId'],
      map['respawnTime'],
    );
  }
}
