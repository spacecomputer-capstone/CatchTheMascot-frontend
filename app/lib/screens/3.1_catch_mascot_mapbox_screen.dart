import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// Aliased so we don't collide on Position / LocationSettings
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:motion_sensors/motion_sensors.dart' as motion;
import 'package:http/http.dart' as http;

import '5_mascot_screen.dart';

/// Listener for mascot taps
class _MascotClickListener extends mb.OnPointAnnotationClickListener {
  _MascotClickListener(this.onClicked);

  final void Function(mb.PointAnnotation annotation) onClicked;

  @override
  void onPointAnnotationClick(mb.PointAnnotation annotation) {
    onClicked(annotation);
  }
}

class CatchMascotMapboxScreen extends StatefulWidget {
  const CatchMascotMapboxScreen({super.key});

  @override
  State<CatchMascotMapboxScreen> createState() =>
      _CatchMascotMapboxScreenState();
}

class _CatchMascotMapboxScreenState extends State<CatchMascotMapboxScreen> {
  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _annotationManager;

  geo.Position? _currentPos; // snapped position
  StreamSubscription<geo.Position>? _posSub;
  StreamSubscription<motion.AbsoluteOrientationEvent>? _orientationSub;

  // Small history of raw GPS for map matching
  final List<geo.Position> _locationHistory = [];

  // Camera state
  double _currentZoom = 18.5;
  double _currentPitch = 60.0; // fixed tilt – we don't change this with gyro
  double _currentBearing = 0.0;

  // Last heading from gyro (degrees 0–360)
  double _gyroBearing = 0.0;

  bool _locationDenied = false;

  // 3D model state
  bool _styleLoaded = false;
  bool _modelAdded = false;

  // Follow vs manual camera
  bool _isAutoFollow = true;

  // Storky mascot image
  Uint8List? _storkeBytes;

  // Your custom Mapbox style
  static const String _styleUrl =
      "mapbox://styles/sanilkatula/cmib4spww003q01sn7rzu63yd";

  // FIXED Storke Tower location (UCSB)
  static const double _storkeLat = 34.412640;
  static const double _storkeLng = -119.848396;

  // Mapbox access token (you can also read this from env/config if you want)
  static const String _mapboxAccessToken =
      "pk.eyJ1Ijoic2FuaWxrYXR1bGEiLCJhIjoiY21pYjRoOHZsMDVyZjJpcHFxdmg2OXVicSJ9.JBlvf3X2eEd7TA0u8K5B0Q";

  DateTime _lastCamUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadStorkeImage();
    _initLocation();
    _initOrientation(); // gyro – for heading only
  }

  // ---------------- ASSETS ----------------

  Future<void> _loadStorkeImage() async {
    try {
      final data =
      await rootBundle.load('assets/icons/storke-nobackground.png');
      setState(() {
        _storkeBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      debugPrint("Error loading storke image: $e");
    }
  }

  // ---------------- LOCATION ----------------

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled");
        setState(() => _locationDenied = true);
        return;
      }

      geo.LocationPermission perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }

      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        debugPrint("Location permission denied by user");
        setState(() => _locationDenied = true);
        return;
      }

      final rawPos = await geo.Geolocator.getCurrentPosition();
      final snapped = await _snapToRoad(rawPos);

      setState(() => _currentPos = snapped);

      // Once we have GPS + style, add the 3D model at this position
      _maybeAddPlayerModelLayer();

      // Live updates as player walks
      _posSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen((rawP) async {
        final snapped = await _snapToRoad(rawP);
        _currentPos = snapped;

        if (_isAutoFollow) {
          _updateCameraCenter(); // keep player in center, snapped to road
        }
      });
    } catch (e, st) {
      debugPrint("Error in _initLocation: $e\n$st");
      setState(() => _locationDenied = true);
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

  void _initOrientation() {
    // ~80ms update interval (microseconds)
    motion.motionSensors.absoluteOrientationUpdateInterval = 80000;

    _orientationSub =
        motion.motionSensors.absoluteOrientation.listen((event) {
          // yaw in radians → degrees
          final yawDeg = event.yaw * 180.0 / math.pi;

          // Invert yaw so turning phone right rotates camera bearing right.
          // If it feels backwards on device, change to (yawDeg + 360) % 360.
          final bearing = (-yawDeg + 360.0) % 360.0;
          _gyroBearing = bearing;
        });
  }

  // ---------------- MAP CREATED / STYLE LOADED ----------------

  Future<void> _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.loadStyleURI(_styleUrl);
  }

  Future<void> _onStyleLoaded(mb.StyleLoadedEventData data) async {
    _styleLoaded = true;

    if (_mapboxMap == null) return;

    await _updateGesturesSettings();

    // Initial camera if we already know where we are
    if (_currentPos != null) {
      await _mapboxMap!.setCamera(
        mb.CameraOptions(
          center: mb.Point(
            coordinates: mb.Position(
              _currentPos!.longitude,
              _currentPos!.latitude,
            ),
          ),
          zoom: _currentZoom,
          pitch: _currentPitch,
          bearing: _currentBearing,
        ),
      );
    }

    // 2D mascot annotations (fixed Storky at tower)
    _annotationManager =
    await _mapboxMap!.annotations.createPointAnnotationManager();
    await _createFixedStorky();

    // If we already have GPS, add the 3D model now
    _maybeAddPlayerModelLayer();
  }

  Future<void> _updateGesturesSettings() async {
    if (_mapboxMap == null) return;

    // AUTO: no pan/rotate; MANUAL: free pan/rotate
    await _mapboxMap!.gestures.updateSettings(
      mb.GesturesSettings(
        scrollEnabled: !_isAutoFollow,
        rotateEnabled: !_isAutoFollow,
        pitchEnabled: !_isAutoFollow,
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
      ),
    );
  }

  // ---------------- 3D PLAYER MODEL LAYER ----------------

  Future<void> _maybeAddPlayerModelLayer() async {
    if (_mapboxMap == null ||
        !_styleLoaded ||
        _currentPos == null ||
        _modelAdded) {
      return;
    }

    final playerLng = _currentPos!.longitude;
    final playerLat = _currentPos!.latitude;

    debugPrint("Adding 3D player model at $playerLat, $playerLng");

    // 1. GeoJSON source with the player's position (snapped)
    final playerPoint = mb.Point(
      coordinates: mb.Position(playerLng, playerLat),
    );

    await _mapboxMap!.style.addSource(
      mb.GeoJsonSource(
        id: "player-source-id",
        data: convert.json.encode(playerPoint),
      ),
    );

    // 2. Model layer that references the local GLB asset
    final modelLayer = mb.ModelLayer(
      id: "player-model-layer",
      sourceId: "player-source-id",
    );

    // Local asset GLB: refer directly via "asset://" URI
    modelLayer.modelId = "asset://assets/player/player.glb";

    // Player size – you said 10.0 is perfect
    modelLayer.modelScale = const [10.0, 10.0, 10.0];
    modelLayer.modelRotation = const [0.0, 0.0, 0.0];
    modelLayer.modelType = mb.ModelType.COMMON_3D;

    await _mapboxMap!.style.addLayer(modelLayer);

    debugPrint("3D player model layer added.");

    _modelAdded = true;
  }

  // ---------------- FIXED STORKY (2D) ----------------

  Future<void> _createFixedStorky() async {
    if (_annotationManager == null) return;

    await _annotationManager!.deleteAll();

    final options = mb.PointAnnotationOptions(
      geometry: mb.Point(
        coordinates: mb.Position(_storkeLng, _storkeLat),
      ),
      iconSize: 0.9, // tweak to taste
    );

    if (_storkeBytes != null) {
      options.image = _storkeBytes!;
    } else {
      options.iconImage = "marker-15";
    }

    final mascot = await _annotationManager!.create(options);

    _annotationManager!.addOnPointAnnotationClickListener(
      _MascotClickListener((annotation) {
        if (annotation.id == mascot.id) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MascotScreen(),
            ),
          );
        }
      }),
    );
  }

  // ---------------- CAMERA UPDATES ----------------

  void _updateCameraCenter() {
    if (_mapboxMap == null || _currentPos == null) return;

    _mapboxMap!.easeTo(
      mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(
            _currentPos!.longitude,
            _currentPos!.latitude,
          ),
        ),
        zoom: _currentZoom,
        pitch: _currentPitch,
        bearing: _currentBearing,
      ),
      mb.MapAnimationOptions(duration: 500, startDelay: 0),
    );
  }

  void _zoomBy(double delta) {
    if (_mapboxMap == null) return;

    setState(() {
      _currentZoom = (_currentZoom + delta).clamp(14.0, 22.0);
    });

    _mapboxMap!.easeTo(
      mb.CameraOptions(
        zoom: _currentZoom,
      ),
      mb.MapAnimationOptions(duration: 200, startDelay: 0),
    );
  }

  /// Recenter:
  /// - goes back to AUTO-follow
  /// - centers on snapped GPS
  /// - zooms in tight (~100ft-ish feel)
  /// - uses gyro heading so map faces where the player is facing
  void _recenterOnPlayer() {
    if (_mapboxMap == null || _currentPos == null) return;

    setState(() {
      _isAutoFollow = true;
      // Tight-ish zoom; tweak 19.0 / 19.5 / 20.0 to taste
      _currentZoom = 19.0;
      _currentBearing = _gyroBearing;
      _currentPitch = 60.0; // keep that nice 3D tilt
    });

    _updateGesturesSettings();
    _updateCameraCenter();
  }

  void _toggleFollowMode() {
    setState(() {
      _isAutoFollow = !_isAutoFollow;
    });
    _updateGesturesSettings();
    if (_isAutoFollow) {
      _updateCameraCenter();
    }
  }

  // ---------------- LIFECYCLE / UI ----------------

  @override
  void dispose() {
    _posSub?.cancel();
    _orientationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_locationDenied) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.location_off, size: 64),
                  SizedBox(height: 16),
                  Text(
                    "Location permission required",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Go to Settings → Privacy → Location Services → "
                        "this app and allow location so you can walk around "
                        "the world and catch the mascot.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_currentPos == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: mb.MapWidget(
              styleUri: _styleUrl,
              cameraOptions: mb.CameraOptions(
                center: mb.Point(
                  coordinates: mb.Position(
                    _currentPos!.longitude,
                    _currentPos!.latitude,
                  ),
                ),
                zoom: _currentZoom,
                pitch: _currentPitch,
                bearing: _currentBearing,
              ),
              key: const ValueKey<String>('mapWidget'),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            ),
          ),

          // HUD
          SafeArea(
            child: Stack(
              children: [
                // Title
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "Catch the Mascot!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Zoom controls
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: "zoom_in",
                          mini: true,
                          onPressed: () => _zoomBy(0.7),
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: "zoom_out",
                          mini: true,
                          onPressed: () => _zoomBy(-0.7),
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recenter + auto/manual toggle
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: "recenter",
                          mini: true,
                          onPressed: _recenterOnPlayer,
                          child: const Icon(Icons.my_location),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: "mode_toggle",
                          mini: true,
                          onPressed: _toggleFollowMode,
                          child: Icon(
                            _isAutoFollow
                                ? Icons.lock       // AUTO follow
                                : Icons.open_with, // MANUAL pan/rotate
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
