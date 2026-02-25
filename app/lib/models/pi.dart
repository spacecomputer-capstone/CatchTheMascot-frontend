// Pi Model

class Pi {
  int piId; //unique identifier
  String location;
  List<int> mascotIds; //list of mascotIds that can be found at this Pi
  double latitude;
  double longitude;

  Pi(this.piId, this.location, this.mascotIds, this.latitude, this.longitude);

  static toMap(Pi pi) {
    return {
      'piId': pi.piId,
      'location': pi.location,
      'mascotIds': pi.mascotIds,
      'latitude': pi.latitude,
      'longitude': pi.longitude,
    };
  }

  factory Pi.fromMap(Map<String, dynamic> map) {
    return Pi(
      map['piId'] ?? 0,
      map['location'] ?? '',
      List<int>.from((map['mascotIds'] ?? []).map((e) => e as int)),
      map['latitude']?.toDouble() ?? 0.0,
      map['longitude']?.toDouble() ?? 0.0,
    );
  }
}
