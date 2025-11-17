import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;

  Set<Marker> _gauchoMarkers = {};
  BitmapDescriptor? _gauchoIcon;

  Marker? _playerMarker;
  BitmapDescriptor? _playerIcon;

  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  /// -----------------------------------------------------------
  /// LOAD EVERYTHING IN CORRECT ORDER
  /// 1. icons
  /// 2. location
  /// 3. markers
  /// 4. GPS stream
  /// -----------------------------------------------------------
  Future<void> _initMap() async {
    await _loadGauchoIcon();
    await _loadPlayerIcon();
    await _loadCurrentLocation();
    _loadMockGauchos();
    _startLocationStream();
  }

  /// -----------------------------------------------------------
  /// LOAD CURRENT LOCATION AND CREATE PLAYER MARKER
  /// -----------------------------------------------------------
  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentLatLng = latLng;
        _playerMarker = Marker(
          markerId: const MarkerId("player"),
          position: latLng,
          icon: _playerIcon!, // always loaded before this call
        );
      });
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  /// -----------------------------------------------------------
  /// LIVE GPS UPDATES
  /// -----------------------------------------------------------
  void _startLocationStream() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);

      // Update player marker position
      setState(() {
        _currentLatLng = latLng;
        _playerMarker = Marker(
          markerId: const MarkerId("player"),
          position: latLng,
          icon: _playerIcon!,
        );
      });

      // Keep map centered on player as they move
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(latLng),
      );
    });
  }

  /// -----------------------------------------------------------
  /// CUSTOM GAUCHO ICON
  /// -----------------------------------------------------------
  Future<void> _loadGauchoIcon() async {
    final byteData =
        await rootBundle.load('assets/icons/storke-nobackground.png');

    final codec = await ui.instantiateImageCodec(
      byteData.buffer.asUint8List(),
      targetWidth: 200,
      targetHeight: 200,
    );

    final frame = await codec.getNextFrame();
    final resized =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);

    _gauchoIcon = BitmapDescriptor.fromBytes(resized!.buffer.asUint8List());
  }

  // CUSTOM PLAYER ICON
  Future<void> _loadPlayerIcon() async {
  final byteData = await rootBundle.load('lib/assets/icons/player.png');
  final originalBytes = byteData.buffer.asUint8List();

  final codec = await ui.instantiateImageCodec(
    originalBytes,
    targetWidth: 220,
    targetHeight: 220,
  );
  final frame = await codec.getNextFrame();
  final ui.Image playerImg = frame.image;

  // ----- Create canvas -----
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(200, 200);

  // ----- Draw soft shadow -----
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.28)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);

  canvas.drawOval(
    Rect.fromLTWH(
      size.width / 2 - 35, // center shadow
      size.height - 55,
      70,
      22,
    ),
    shadowPaint,
  );

  // ----- Draw player image -----
  final imgOffset = Offset(
    (size.width - playerImg.width) / 2,
    (size.height - playerImg.height) / 2 - 10,
  );

  canvas.drawImage(playerImg, imgOffset, Paint());

  // ----- Draw directional arrow (optional) -----
  final arrowPaint = Paint()..color = Colors.blueAccent;

  final arrowPath = Path()
    ..moveTo(size.width / 2, 20)
    ..lineTo(size.width / 2 - 12, 45)
    ..lineTo(size.width / 2 + 12, 45)
    ..close();

  canvas.drawPath(arrowPath, arrowPaint);

  // Finish image
  final picture = recorder.endRecording();
  final img = await picture.toImage(200, 200);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

  _playerIcon = BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
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
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLatLng!,
          zoom: 17,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        zoomControlsEnabled: true,
        markers: {
          if (_playerMarker != null) _playerMarker!,
          ..._gauchoMarkers,
        },
      ),
    );
  }
}