import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../map/map_ids.dart';
import '../map/map_gestures.dart';
import '../map/camera_controller.dart';
import '../map/player_model_controller.dart';
import '../map/mascot_annotations.dart';

import '../widgets/map_hud/map_edge_gradient_overlay.dart';
import '../widgets/map_hud/map_follow_controls.dart';
import '../widgets/map_hud/map_top_title.dart';
import '../widgets/map_hud/map_zoom_controls.dart';

import '3.2_player.dart';
import '4_mascot_screen.dart';

class CatchMascotMapboxScreen extends StatefulWidget {
  const CatchMascotMapboxScreen({super.key});

  @override
  State<CatchMascotMapboxScreen> createState() => _CatchMascotMapboxScreenState();
}

class _CatchMascotMapboxScreenState extends State<CatchMascotMapboxScreen> {
  mb.MapboxMap? _map;
  bool _styleLoaded = false;

  late final Player _player;
  geo.Position? _currentPos;
  geo.Position? _lastPos;
  bool _locationDenied = false;

  bool _isAutoFollow = true;

  double _zoom = MapIds.defaultZoom;
  double _pitch = MapIds.defaultPitch;
  double _bearing = 0.0;
  double _gyroBearing = 0.0;

  CameraController? _camera;
  PlayerModelController? _playerModel;
  MascotAnnotations? _mascots;

  bool get _mapReady => _map != null && _styleLoaded;

  @override
  void initState() {
    super.initState();

    _player = Player(
      onPosition: (pos) async {
        if (!mounted) return;

        setState(() {
          _locationDenied = false;
          _lastPos = _currentPos;
          _currentPos = pos;
        });

        if (!_mapReady) return;

        // Move/add 3D model
        await _playerModel?.addOrMove(lat: pos.latitude, lng: pos.longitude);
        if (!mounted) return;

        if (_isAutoFollow && _camera != null) {
          final newBearing = _camera!.alignBearingFromMovement(
            lastPos: _lastPos,
            currentPos: _currentPos,
            currentBearing: _bearing,
          );

          if (!mounted) return;
          setState(() => _bearing = newBearing);

          await _camera!.easeToPosition(
            pos: pos,
            zoom: _zoom,
            pitch: _pitch,
            bearing: _bearing,
          );
        }
      },
      onHeading: (b) async {
        _gyroBearing = b;

        if (_isAutoFollow && _mapReady && _currentPos != null) {
          if (!mounted) return;
          setState(() => _bearing = _gyroBearing);

          await _camera?.easeToPosition(
            pos: _currentPos!,
            zoom: _zoom,
            pitch: _pitch,
            bearing: _bearing,
          );
        }

        await _playerModel?.setHeading(_gyroBearing);
      },
      onLocationDenied: () {
        if (!mounted) return;
        setState(() => _locationDenied = true);
      },
    );

    _player.init();
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _map = map;
    await map.loadStyleURI(MapIds.styleUrl);
  }

  Future<void> _onStyleLoaded(mb.StyleLoadedEventData data) async {
    if (_map == null || !mounted) return;

    setState(() => _styleLoaded = true);

    _camera = CameraController(
      map: _map!,
      maxUpdateHz: MapIds.maxCameraUpdateHz,
      minZoom: MapIds.minZoom,
      maxZoom: MapIds.maxZoom,
    );

    _playerModel = PlayerModelController(
      map: _map!,
      sourceId: MapIds.playerSourceId,
      layerId: MapIds.playerModelLayerId,
      modelHeadingOffset: MapIds.playerModelHeadingOffset,
    );

    await updateGesturesSettings(_map!, isAutoFollow: _isAutoFollow);

    // Mascot annotation
    _mascots = MascotAnnotations(
      map: _map!,
      assetPath: MapIds.fixedMascotImageAsset,
      lat: MapIds.storkeLat,
      lng: MapIds.storkeLng,
      onTap: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MascotScreen()),
        );
      },
    );
    await _mascots!.init();

    // If we already have GPS, place model and camera
    if (_currentPos != null) {
      await _playerModel!.addOrMove(
        lat: _currentPos!.latitude,
        lng: _currentPos!.longitude,
      );

      await _camera!.easeToPosition(
        pos: _currentPos!,
        zoom: _zoom,
        pitch: _pitch,
        bearing: _bearing,
      );
    }
  }

  void _zoomBy(double delta) {
    if (_camera == null) return;

    setState(() => _zoom = _camera!.zoomBy(_zoom, delta));

    _map?.easeTo(
      mb.CameraOptions(zoom: _zoom),
      mb.MapAnimationOptions(duration: 200, startDelay: 0),
    );
  }

  Future<void> _recenterOnPlayer() async {
    if (!_mapReady || _currentPos == null) return;

    setState(() {
      _isAutoFollow = true;
      _zoom = MapIds.autoFollowZoom;
      _bearing = _gyroBearing;
      _pitch = MapIds.defaultPitch;
    });

    await updateGesturesSettings(_map!, isAutoFollow: _isAutoFollow);

    await _camera?.easeToPosition(
      pos: _currentPos!,
      zoom: _zoom,
      pitch: _pitch,
      bearing: _bearing,
    );
  }

  Future<void> _toggleFollowMode() async {
    if (_map == null) return;

    setState(() => _isAutoFollow = !_isAutoFollow);
    await updateGesturesSettings(_map!, isAutoFollow: _isAutoFollow);

    // Optional: if turning auto-follow back on, snap immediately
    if (_isAutoFollow && _currentPos != null) {
      await _camera?.easeToPosition(
        pos: _currentPos!,
        zoom: _zoom,
        pitch: _pitch,
        bearing: _bearing,
      );
    }
  }

  @override
  void dispose() {
    // If your MascotAnnotations.dispose() is Future, you can fire-and-forget:
    _mascots?.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_locationDenied) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text("Location permission required"),
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
          mb.MapWidget(
            styleUri: MapIds.styleUrl,
            cameraOptions: mb.CameraOptions(
              center: mb.Point(
                coordinates: mb.Position(
                  _currentPos!.longitude,
                  _currentPos!.latitude,
                ),
              ),
              zoom: _zoom,
              pitch: _pitch,
              bearing: _bearing,
            ),
            key: const ValueKey('mapWidget'),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),

          // Subtle overlay for legibility
          const MapEdgeGradientOverlay(),

          // HUD
          SafeArea(
            child: Stack(
              children: [
                const MapTopTitle(),
                MapZoomControls(
                  onZoomIn: () => _zoomBy(0.7),
                  onZoomOut: () => _zoomBy(-0.7),
                ),
                MapFollowControls(
                  isAutoFollow: _isAutoFollow,
                  onRecenter: _recenterOnPlayer,
                  onToggleFollow: _toggleFollowMode,
                  playerName: "You",
                  playerSubtitle: "Lv. 1 • 0.0 km walked",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
