import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '5_mascot_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;

  // single mascot
  Set<Marker> _gauchoMarkers = {};
  BitmapDescriptor? _gauchoIcon;

  // player
  Marker? _playerMarker;
  BitmapDescriptor? _playerIcon;

  // “catch radius”
  Set<Circle> _circles = {};

  StreamSubscription<Position>? _positionSub;

  /// Game-like style (no labels, soft colors).
  static const String _gameMapStyle = '''
  [
    {
      "featureType": "poi",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "transit",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        { "color": "#ffffff" },
        { "weight": 1.2 }
      ]
    },
    {
      "featureType": "road.highway",
      "stylers": [
        { "color": "#ffd96a" }
      ]
    },
    {
      "featureType": "landscape",
      "stylers": [
        { "color": "#c7f1bf" }
      ]
    },
    {
      "featureType": "water",
      "stylers": [
        { "color": "#9fd4ff" }
      ]
    },
    {
      "elementType": "labels.text",
      "stylers": [
        { "visibility": "off" }
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    await _loadGauchoIcon();
    await _loadPlayerIcon();
    await _loadCurrentLocation();
    _spawnMascotNearPlayer();
    _startLocationStream();
  }

  // ---------------- LOCATION / PLAYER ----------------

  /// -----------------------------------------------------------
  /// LOAD CURRENT LOCATION AND CREATE PLAYER MARKER
  /// -----------------------------------------------------------
  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);

      _updatePlayer(latLng, pos.heading);
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  void _startLocationStream() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      _updatePlayer(latLng, pos.heading);

      // keep camera behind the player like a game
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: latLng,
            zoom: 18.5,
            tilt: 60,      // angle like Pokémon Go
            bearing: 45,   // rotate world a bit
          ),
        ),
      );
    });
  }

  void _updatePlayer(LatLng latLng, double heading) {
    setState(() {
      _currentLatLng = latLng;

      _playerMarker = Marker(
        markerId: const MarkerId("player"),
        position: latLng,
        icon: _playerIcon!,
        anchor: const Offset(0.5, 0.9), // feet on the ground
        rotation: heading,
        flat: true,
      );

      // update “catch radius”
      _circles = {
        Circle(
          circleId: const CircleId("catch_radius"),
          center: latLng,
          radius: 40, // meters
          strokeWidth: 1,
          strokeColor: Colors.blue.withOpacity(0.5),
          fillColor: Colors.blue.withOpacity(0.12),
        ),
      };
    });
  }

  // ---------------- ICONS ----------------

  Future<void> _loadGauchoIcon() async {
    final byteData =
    await rootBundle.load('assets/icons/storke-nobackground.png');

    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: 120, // smaller than before
      targetHeight: 120,
    );

    final frame = await codec.getNextFrame();
    final resized =
    await frame.image.toByteData(format: ui.ImageByteFormat.png);

    _gauchoIcon = BitmapDescriptor.fromBytes(resized!.buffer.asUint8List());
  }

  Future<void> _loadPlayerIcon() async {
    final byteData = await rootBundle.load('lib/assets/icons/player.png');
    final originalBytes = byteData.buffer.asUint8List();

    final codec = await ui.instantiateImageCodec(
      originalBytes,
      targetWidth: 180,
      targetHeight: 180,
    );
    final frame = await codec.getNextFrame();
    final ui.Image playerImg = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(180, 180);

    // shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14);

    canvas.drawOval(
      Rect.fromLTWH(
        size.width / 2 - 30,
        size.height - 52,
        60,
        22,
      ),
      shadowPaint,
    );

    // player
    final imgOffset = Offset(
      (size.width - playerImg.width) / 2,
      (size.height - playerImg.height) / 2 - 10,
    );
    canvas.drawImage(playerImg, imgOffset, Paint());

    // arrow
    final arrowPaint = Paint()..color = Colors.blueAccent;
    final arrowPath = Path()
      ..moveTo(size.width / 2, 16)
      ..lineTo(size.width / 2 - 11, 40)
      ..lineTo(size.width / 2 + 11, 40)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(180, 180);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    _playerIcon = BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
  }

  // ---------------- MASCOT ----------------

  void _spawnMascotNearPlayer() {
    if (_currentLatLng == null || _gauchoIcon == null) return;

    // single mascot 80–100m away
    const double meters = 90;
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;

    final dLat = (meters * math.cos(angle)) / 111000.0;
    final dLng = (meters * math.sin(angle)) /
        (111000.0 * math.cos(_currentLatLng!.latitude * math.pi / 180));

    final mascotPos = LatLng(
      _currentLatLng!.latitude + dLat,
      _currentLatLng!.longitude + dLng,
    );

    setState(() {
      _gauchoMarkers = {
        Marker(
          markerId: const MarkerId("gaucho"),
          position: mascotPos,
          icon: _gauchoIcon!,
          anchor: const Offset(0.5, 0.9),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MascotScreen(),
              ),
            );
          },
        ),
      };
    });
  }

  // ---------------- LIFECYCLE / UI ----------------

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _loadMockGauchos() {
    final mockPositions = [
      LatLng(34.4140, -119.8480),
      LatLng(34.4128, -119.8472),
      LatLng(34.4151, -119.8459),
    ];

    setState(() {
      _gauchoMarkers = mockPositions
          .asMap()
          .entries
          .map(
            (entry) => Marker(
              markerId: MarkerId("gaucho_${entry.key}"),
              position: entry.value,
              icon: _gauchoIcon!,
            ),
          )
          .toSet();
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    if (_currentLatLng == null || _gauchoIcon == null || _playerIcon == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng!,
              zoom: 18.5,
              tilt: 60,
              bearing: 45,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle(_gameMapStyle);
            },
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            buildingsEnabled: true,
            circles: _circles,
            markers: {
              if (_playerMarker != null) _playerMarker!,
              ..._gauchoMarkers,
            },
          ),

          // HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "Catch the Mascot!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
