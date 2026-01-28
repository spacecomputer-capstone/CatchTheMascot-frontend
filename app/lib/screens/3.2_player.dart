// 3.2 player.dart

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';

/// Encapsulates:
/// - location permission + tracking
/// - Mapbox map-matching (snap to road)
/// - device orientation (heading)
///
/// It reports updates back to the UI via callbacks.
class Player {
  final void Function(geo.Position) onPosition;
  final void Function(double) onHeading;
  final void Function() onLocationDenied;

  Player({
    required this.onPosition,
    required this.onHeading,
    required this.onLocationDenied,
  });

  // Mapbox access token for map-matching
  static const String _mapboxAccessToken =
      "pk.eyJ1Ijoic2FuaWxrYXR1bGEiLCJhIjoiY21pYjRoOHZsMDVyZjJpcHFxdmg2OXVicSJ9.JBlvf3X2eEd7TA0u8K5B0Q";

  final List<geo.Position> _locationHistory = [];

  StreamSubscription<geo.Position>? _posSub;
  StreamSubscription<CompassEvent>? _orientationSub;

  /// Call once from initState in your widget.
  Future<void> init() async {
    await _initLocation();
    _initOrientation();
  }

  // ---------------- LOCATION ----------------

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled");
        onLocationDenied();
        return;
      }

      geo.LocationPermission perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }

      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        debugPrint("Location permission denied by user");
        onLocationDenied();
        return;
      }

      final rawPos = await geo.Geolocator.getCurrentPosition();
      final snapped = await _snapToRoad(rawPos);

      onPosition(snapped);

      // Live updates as player walks
      _posSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen((rawP) async {
        final snapped = await _snapToRoad(rawP);
        onPosition(snapped);
      });
    } catch (e, st) {
      debugPrint("Error in _initLocation: $e\n$st");
      onLocationDenied();
    }
  }

  // Map Matching: snap raw GPS to nearest road using Mapbox API
  Future<geo.Position> _snapToRoad(geo.Position raw) async {
    try {
      // Maintain a short history for better matching
      if (_locationHistory.isEmpty ||
          _locationHistory.last.latitude != raw.latitude ||
          _locationHistory.last.longitude != raw.longitude) {
        _locationHistory.add(raw);
      }

      const maxPoints = 3;
      if (_locationHistory.length > maxPoints) {
        _locationHistory.removeRange(0, _locationHistory.length - maxPoints);
      }

      // Build "lon,lat;lon,lat;..." string
      final coords = _locationHistory
          .map((p) => "${p.longitude},${p.latitude}")
          .join(";");

      final uri = Uri.parse(
        "https://api.mapbox.com/matching/v5/mapbox/walking/$coords"
            "?geometries=geojson&access_token=$_mapboxAccessToken",
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        debugPrint("Map Matching error: ${resp.statusCode} ${resp.body}");
        return raw; // fallback
      }

      final data = convert.json.decode(resp.body) as Map<String, dynamic>;
      final matches = data["matchings"] as List<dynamic>?;
      if (matches == null || matches.isEmpty) {
        debugPrint("No matchings returned, using raw GPS");
        return raw;
      }

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
    } catch (e, st) {
      debugPrint("Error in _snapToRoad: $e\n$st");
      return raw;
    }
  }

  // ---------------- ORIENTATION (GYRO – heading only) ----------------

  // ---------------- ORIENTATION (GYRO – heading only) ----------------

  void _initOrientation() {
    _orientationSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null) {
        // bearing is 0-360, handled by mapbox usually
        // Adjust if needed, but FlutterCompass generally gives direct heading.
        onHeading(heading);
      }
    });
  }

  // ---------------- DISPOSE ----------------

  void dispose() {
    _posSub?.cancel();
    _orientationSub?.cancel();
  }
}
