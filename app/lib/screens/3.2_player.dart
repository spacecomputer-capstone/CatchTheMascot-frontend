// 3.2 player.dart

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

class Player {
  final void Function(geo.Position) onPosition;
  final void Function(double) onHeading;
  final void Function() onLocationDenied;

  Player({
    required this.onPosition,
    required this.onHeading,
    required this.onLocationDenied,
  });

  static const String _mapboxAccessToken =
      "pk.eyJ1Ijoic2FuaWxrYXR1bGEiLCJhIjoiY21pYjRoOHZsMDVyZjJpcHFxdmg2OXVicSJ9.JBlvf3X2eEd7TA0u8K5B0Q";

  final List<geo.Position> _locationHistory = [];
  double _lastBearing = 0.0;

  StreamSubscription<geo.Position>? _posSub;
  StreamSubscription? _orientationSub;

  Future<void> init() async {
    await _initLocation();
    _initOrientation();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onLocationDenied();
        return;
      }

      geo.LocationPermission perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }

      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        onLocationDenied();
        return;
      }

      final rawPos = await geo.Geolocator.getCurrentPosition();
      final snapped = await _snapToRoad(rawPos);
      onPosition(snapped);

      _posSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 1, // Reduced to 1m for more frequent updates
        ),
      ).listen((rawP) async {
        final snapped = await _snapToRoad(rawP);
        onPosition(snapped);
      });
    } catch (e) {
      onLocationDenied();
    }
  }

  Future<geo.Position> _snapToRoad(geo.Position raw) async {
    try {
      if (_locationHistory.isEmpty ||
          _locationHistory.last.latitude != raw.latitude ||
          _locationHistory.last.longitude != raw.longitude) {
        _locationHistory.add(raw);
      }

      const maxPoints = 5; // Slightly longer history for smoother snapping
      if (_locationHistory.length > maxPoints) {
        _locationHistory.removeRange(0, _locationHistory.length - maxPoints);
      }

      final coords = _locationHistory
          .map((p) => "${p.longitude},${p.latitude}")
          .join(";");

      final uri = Uri.parse(
        "https://api.mapbox.com/matching/v5/mapbox/walking/$coords"
            "?geometries=geojson&access_token=$_mapboxAccessToken",
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) return raw;

      final data = convert.json.decode(resp.body) as Map<String, dynamic>;
      final matches = data["matchings"] as List<dynamic>?;
      if (matches == null || matches.isEmpty) return raw;

      final geometry = matches[0]["geometry"] as Map<String, dynamic>;
      final coordsList = geometry["coordinates"] as List<dynamic>;
      if (coordsList.isEmpty) return raw;

      final lastCoord = coordsList.last as List<dynamic>;
      final snappedLon = (lastCoord[0] as num).toDouble();
      final snappedLat = (lastCoord[1] as num).toDouble();

      return geo.Position(
        latitude: snappedLat,
        longitude: snappedLon,
        accuracy: raw.accuracy,
        altitude: raw.altitude,
        heading: raw.heading,
        speed: raw.speed,
        speedAccuracy: raw.speedAccuracy,
        timestamp: raw.timestamp,
        altitudeAccuracy: raw.altitudeAccuracy,
        headingAccuracy: raw.headingAccuracy,
      );
    } catch (e) {
      return raw;
    }
  }

  void _initOrientation() {
    // Magnetometer is often noisy, so we'll use a simple low-pass filter
    _orientationSub = magnetometerEvents.listen((event) {
      final x = event.x;
      final y = event.y;

      final headingRad = math.atan2(y, x);
      final yawDeg = headingRad * 180.0 / math.pi;

      // Adjusting direction logic:
      // If the map feels inverted when you turn, flip the sign of yawDeg
      double targetBearing = (yawDeg + 360.0) % 360.0;

      // Smooth the bearing update (Linear interpolation)
      double alpha = 0.15; // Tuning parameter for smoothness vs responsiveness
      
      // Calculate shortest path for rotation
      double diff = targetBearing - _lastBearing;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      
      _lastBearing = (_lastBearing + diff * alpha) % 360.0;
      if (_lastBearing < 0) _lastBearing += 360;

      onHeading(_lastBearing);
    });
  }

  void dispose() {
    _posSub?.cancel();
    _orientationSub?.cancel();
  }
}
