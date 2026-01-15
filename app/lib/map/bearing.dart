import 'dart:math' as math;

double computeBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    ) {
  final phi1 = lat1 * math.pi / 180.0;
  final phi2 = lat2 * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;

  final y = math.sin(dLon) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  final brng = math.atan2(y, x);

  return ((brng * 180.0 / math.pi) + 360.0) % 360.0;
}
