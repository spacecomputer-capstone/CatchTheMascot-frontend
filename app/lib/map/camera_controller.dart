import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'bearing.dart';

class CameraController {
  CameraController({
    required this.map,
    required this.maxUpdateHz,
    required this.minZoom,
    required this.maxZoom,
  });

  final mb.MapboxMap map;
  final double maxUpdateHz;
  final double minZoom;
  final double maxZoom;

  DateTime _lastCamUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> easeToPosition({
    required geo.Position pos,
    required double zoom,
    required double pitch,
    required double bearing,
  }) async {
    final now = DateTime.now();
    // Increase frequency for smoother updates (maxUpdateHz is usually 10, so 100ms)
    final minFrameIntervalMs = (1000 / maxUpdateHz).floor();
    if (now.difference(_lastCamUpdate).inMilliseconds < minFrameIntervalMs) return;
    _lastCamUpdate = now;

    map.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(pos.longitude, pos.latitude)),
        zoom: zoom,
        pitch: pitch,
        bearing: bearing,
      ),
      // Use a shorter duration and linear-like curve for "real-time" feel
      mb.MapAnimationOptions(duration: 300, startDelay: 0),
    );
  }

  double alignBearingFromMovement({
    required geo.Position? lastPos,
    required geo.Position? currentPos,
    required double currentBearing,
  }) {
    if (lastPos == null || currentPos == null) return currentBearing;

    final distance = geo.Geolocator.distanceBetween(
      lastPos.latitude,
      lastPos.longitude,
      currentPos.latitude,
      currentPos.longitude,
    );
    // Only update bearing if we moved significantly to avoid jitter
    if (distance < 2.0) return currentBearing;

    return computeBearing(
      lastPos.latitude,
      lastPos.longitude,
      currentPos.latitude,
      currentPos.longitude,
    );
  }

  double zoomBy(double zoom, double delta) {
    return (zoom + delta).clamp(minZoom, maxZoom);
  }
}
