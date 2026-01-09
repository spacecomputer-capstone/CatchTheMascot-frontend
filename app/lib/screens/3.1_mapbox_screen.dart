// 3.1 mapbox_screen.dart

import 'dart:typed_data';
import 'dart:convert' as convert;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '5_mascot_screen.dart';
import '3.2_player.dart';

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
  // ---------------- CONSTANTS ----------------

  static const String _styleUrl =
      "mapbox://styles/sanilkatula/cmib4spww003q01sn7rzu63yd";

  static const String _playerSourceId = "player-source-id";        // NEW
  static const String _playerModelLayerId = "player-model-layer";  // NEW

  static const String _fixedMascotSourceId = "fixed-mascot-source-id";
  static const String _fixedMascotImageAsset =
      'assets/icons/storke-nobackground.png';

  // FIXED Storke Tower location (UCSB)
  static const double _storkeLat = 34.412640;
  static const double _storkeLng = -119.848396;

  static const double _minZoom = 14.0;
  static const double _maxZoom = 22.0;
  static const double _defaultZoom = 18.5;
  static const double _autoFollowZoom = 19.0;
  static const double _defaultPitch = 80.0;
  static const double _maxCameraUpdateHz = 10;
  static const double _playerModelHeadingOffset = 180.0;

  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _annotationManager;

  late final Player _player;

  geo.Position? _currentPos; // snapped position from Player
  geo.Position? _lastPos;    // NEW – for bearing estimation / smoothing
  bool _locationDenied = false;

  // Camera state
  double _currentZoom = _defaultZoom;
  double _currentPitch = _defaultPitch;
  double _currentBearing = 0.0;

  // Last heading from gyro (degrees 0–360)
  double _gyroBearing = 0.0;

  // 3D model state
  bool _styleLoaded = false;
  bool _modelAdded = false;

  // Follow vs manual camera
  bool _isAutoFollow = true;

  // Storky mascot image
  Uint8List? _storkeBytes;

  DateTime _lastCamUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _mapReady => _mapboxMap != null && _styleLoaded; // NEW

  @override
  void initState() {
    super.initState();
    _loadStorkeImage();

    // Wire Player callbacks to our local state
    _player = Player(
      onPosition: (pos) {
        setState(() {
          _locationDenied = false;
          _lastPos = _currentPos;
          _currentPos = pos;
        });

        // Move or add the 3D player model to follow the player
        _updatePlayerModel(); // NEW

        // Keep camera following if auto
        if (_isAutoFollow) {
          _alignCameraToMovement(); // NEW – smarter bearing
          _updateCameraCenter();
        }
      },
      onHeading: (bearing) {
        _gyroBearing = bearing;

        // In auto-follow mode, gently align camera with heading
        if (_isAutoFollow && _mapReady) {
          setState(() {
            _currentBearing = _gyroBearing;
          });
          _updateCameraCenter();
        }

        // Optional: also orient player model to heading
        _updatePlayerModelOrientation(); // NEW
      },
      onLocationDenied: () {
        setState(() {
          _locationDenied = true;
        });
      },
    );

    _player.init();
  }

  // ---------------- ASSETS ----------------

  Future<void> _loadStorkeImage() async {
    try {
      final data = await rootBundle.load(_fixedMascotImageAsset);
      setState(() {
        _storkeBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      debugPrint("Error loading storke image: $e");
    }
  }

  // ---------------- MAP CREATED / STYLE LOADED ----------------

  Future<void> _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.loadStyleURI(_styleUrl);
  }

  Future<void> _onStyleLoaded(mb.StyleLoadedEventData data) async {
    _styleLoaded = true;
    if (!_mapReady) return;

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
    _updatePlayerModel(); // NEW – replaces _maybeAddPlayerModelLayer
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

  /// Add or move the player 3D model to the current snapped position.   // NEW
  Future<void> _updatePlayerModel() async {
    if (!_mapReady || _currentPos == null) return;

    final playerLng = _currentPos!.longitude;
    final playerLat = _currentPos!.latitude;

    final playerPoint = mb.Point(
      coordinates: mb.Position(playerLng, playerLat),
    );
    final data = convert.json.encode(playerPoint);

    if (!_modelAdded) {
      debugPrint("Adding 3D player model at $playerLat, $playerLng");

      await _mapboxMap!.style.addSource(
        mb.GeoJsonSource(
          id: _playerSourceId,
          data: data,
        ),
      );

      final modelLayer = mb.ModelLayer(
        id: _playerModelLayerId,
        sourceId: _playerSourceId,
      );

      modelLayer.modelId = "asset://assets/player/player.glb";
      modelLayer.modelScale = const [10.0, 10.0, 10.0];
      modelLayer.modelRotation = const [0.0, 0.0, 0.0];
      modelLayer.modelType = mb.ModelType.COMMON_3D;

      await _mapboxMap!.style.addLayer(modelLayer);

      _modelAdded = true;
    } else {
      // ✅ correct way to move the player point
      try {
        await _mapboxMap!.style.setStyleSourceProperty(
          _playerSourceId,
          'data',
          data,
        );
      } catch (e) {
        debugPrint("Error updating player GeoJSON source: $e");
      }
    }
  }

  /// Rotate the player model to face the user's heading.               // NEW
  Future<void> _updatePlayerModelOrientation() async {
    if (!_mapReady || !_modelAdded) return;

    // Apply offset so model faces the right way
    final yaw = ((_gyroBearing + _playerModelHeadingOffset) % 360 + 360) % 360;

    try {
      await _mapboxMap!.style.setStyleLayerProperty(
        _playerModelLayerId,
        "model-rotation",
        [0.0, 0.0, yaw],
      );
    } catch (e) {
      debugPrint("Error updating player model rotation: $e");
    }
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
    if (!_mapReady || _currentPos == null) return;

    final now = DateTime.now();
    // throttle camera updates a bit
    final minFrameIntervalMs = (1000 / _maxCameraUpdateHz).floor();
    if (now.difference(_lastCamUpdate).inMilliseconds < minFrameIntervalMs) {
      return;
    }
    _lastCamUpdate = now;

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
      mb.MapAnimationOptions(duration: 400, startDelay: 0),
    );
  }

  /// When auto-follow is on, align camera bearing with movement
  /// (fallback to gyro heading if movement is small).                  // NEW
  void _alignCameraToMovement() {
    if (_currentPos == null || _lastPos == null) return;

    final from = _lastPos!;
    final to = _currentPos!;

    final distance = geo.Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    // Only adjust bearing if we actually moved a bit
    if (distance < 1.0) return;

    final bearing = _computeBearing(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    setState(() {
      _currentBearing = bearing;
    });
  }

  double _computeBearing(
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

  void _zoomBy(double delta) {
    if (_mapboxMap == null) return;

    setState(() {
      _currentZoom = (_currentZoom + delta).clamp(_minZoom, _maxZoom);
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
  /// - zooms in tight
  /// - uses gyro heading so map faces where the player is facing
  void _recenterOnPlayer() {
    if (!_mapReady || _currentPos == null) return;

    setState(() {
      _isAutoFollow = true;
      _currentZoom = _autoFollowZoom;
      _currentBearing = _gyroBearing;
      _currentPitch = _defaultPitch;
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

  // ---------------- LIFECYCLE ----------------

  @override
  void dispose() {
    if (_annotationManager != null && _mapboxMap != null) {
      _mapboxMap!.annotations.removeAnnotationManager(_annotationManager!);
    }

    _player.dispose();
    super.dispose();
  }


  // ---------------- HUD WIDGETS ----------------

  Widget _buildTopTitle() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "Catch the Mascot!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Walk around campus to find Storky",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,      // 🔒 only as big as its children
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _smallIconButton(
              icon: Icons.add,
              onTap: () => _zoomBy(0.7),
            ),
            const SizedBox(height: 8),
            _smallIconButton(
              icon: Icons.remove,
              onTap: () => _zoomBy(-0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowControls() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _smallIconButton(
                    icon: Icons.my_location,
                    onTap: _recenterOnPlayer,
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 0.5,
                    color: Colors.white24,
                  ),
                  _smallIconButton(
                    icon: _isAutoFollow ? Icons.lock : Icons.open_with,
                    onTap: _toggleFollowMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildPlayerPill(), // NEW – simple player info pill
          ],
        ),
      ),
    );
  }

  Widget _smallIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }



  /// Pokémon GO–like bottom pill with player info / actions.           // NEW
  Widget _buildPlayerPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "You",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Lv. 1 • 0.0 km walked",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.backpack_outlined,
            size: 18,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeGradientOverlay() {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black26,
              Colors.transparent,
              Colors.transparent,
              Colors.black38,
            ],
            stops: [0.0, 0.25, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------

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
          // MAP
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

          // Subtle top/bottom dark gradient for text legibility
          _buildEdgeGradientOverlay(), // NEW

          // HUD
          SafeArea(
            child: Stack(
              children: [
                _buildTopTitle(),
                _buildZoomControls(),
                _buildFollowControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
