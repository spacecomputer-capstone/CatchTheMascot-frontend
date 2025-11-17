import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  Marker? _playerMarker;
  Set<Marker> _gauchoMarkers = {};
  BitmapDescriptor? _gauchoIcon;

  @override
    void initState() {
    super.initState();

    _initMap();
    }

    Future<void> _initMap() async {
    await _loadCurrentLocation();
    await _loadGauchoIcon();     // <-- wait for the icon to load
    _loadMockGauchos();          // <-- THEN load markers
    }

  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentLatLng = latLng;
        _playerMarker = Marker(
          markerId: const MarkerId("player"),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
      });
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

    Future<void> _loadGauchoIcon() async {
        final byteData = await rootBundle.load('assets/icons/storke-nobackground.png');

        final codec = await ui.instantiateImageCodec(
            byteData.buffer.asUint8List(),
            targetWidth: 200,  // <-- ADJUST SIZE HERE
            targetHeight: 200,
        );

        final frame = await codec.getNextFrame();
        final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);

        _gauchoIcon = BitmapDescriptor.fromBytes(resized!.buffer.asUint8List());
    }

    void _loadMockGauchos() {
        final mockPositions = [
            LatLng(34.4140, -119.8480),
            LatLng(34.4128, -119.8472),
            LatLng(34.4151, -119.8459),
        ];

        _gauchoMarkers = mockPositions
            .asMap()
            .entries
            .map((entry) => Marker(
                    markerId: MarkerId("gaucho_${entry.key}"),
                    position: entry.value,
                    icon: _gauchoIcon!,     // NOW SAFE
                ))
            .toSet();

        setState(() {});
    }

  @override
  Widget build(BuildContext context) {
    if (_currentLatLng == null || _gauchoIcon == null) {
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
                    ..._gauchoMarkers,
                },
            ),

            Center(
                child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 1.0, end: 1.2),
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                    return Transform.scale(
                        scale: scale,
                        child: child,
                    );
                    },
                    child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                        // SHADOW
                        Positioned(
                            bottom: -6,
                            right: 12,
                            child: Container(
                                width: 32,
                                height: 12,
                                decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                                ),
                            ),
                        ),

                        // POINTER TRIANGLE
                        Positioned(
                            bottom: -14,
                            right: 14,
                            child: Transform.rotate(
                                angle: 3.14159, // upside-down triangle
                                child: Icon(
                                Icons.arrow_drop_up,
                                size: 28,
                                color: Colors.black.withOpacity(0.35),
                                ),
                            ),
                        ),

                        // PLAYER ICON
                        Image.asset(
                            'lib/assets/icons/player.png',
                            width: 48,
                        ),
                    ],
                    ),
                ),
                )
            ],
        ),
    );
  }
}