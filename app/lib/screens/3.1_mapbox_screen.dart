import 'dart:convert' as convert;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
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
import 'package:app/state/current_user.dart';
import 'package:app/utils/routes.dart';
import '8_inventory_screen.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:app/models/mascot.dart';

class CatchMascotMapboxScreen extends StatefulWidget {
  const CatchMascotMapboxScreen({super.key});

  @override
  State<CatchMascotMapboxScreen> createState() =>
      _CatchMascotMapboxScreenState();
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
  DateTime _lastHeadingUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastAppliedHeading = 0.0;

  CameraController? _camera;
  PlayerModelController? _playerModel;

  final List<MascotAnnotations> _mascotMarkers = [];
  
  // Storage for fetched mascot data to keep names consistent
  final Map<int, Mascot> _mascotData = {};

  final List<MascotTarget> _allMascots = [
    MascotTarget(
      idnumber: 5,
      piId: 2,
      id: "storkie_tower",
      name: "Storkie",
      lat: MapIds.storkeLat,
      lng: MapIds.storkeLng + 0.00010, // East of tower (Front)
      glbAssetPath: 'lib/assets/3dmascots/5_storkie.glb',
      pngAssetPath: 'lib/assets/mascotimages/5_storkie.png',
      height: 0.0, 
    ),
    MascotTarget(
      idnumber: 1,
      piId: 3,
      id: "raccoon_henley",
      name: "Raccoon",
      lat: 34.41687562912479,
      lng: -119.8444312386711,
      glbAssetPath: 'lib/assets/3dmascots/1_raccoon.glb',
      pngAssetPath: 'lib/assets/mascotimages/1_raccoon.png',
      height: 25.0, // Significantly increased height to clear Henley Hall terrain
    ),
  ];

  bool get _mapReady => _map != null && _styleLoaded;

  static const String _mapboxAccessToken =
      "pk.eyJ1Ijoic2FuaWxrYXR1bGEiLCJhIjoiY21pYjRoOHZsMDVyZjJpcHFxdmg2OXVicSJ9.JBlvf3X2eEd7TA0u8K5B0Q";

  static const double _nearbyRadiusM = 5000;
  static const String _routesSourceId = "nearby-routes-source";
  static const String _routesLayerId = "nearby-routes-layer";

  List<MascotWithDistance> _nearbyMascots = [];
  String? _activeMascotId;
  DateTime _lastRouteUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadMascotData();
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Reduce 3D tilt on Android to lower rendering workload.
      _pitch = 65.0;
    }

    _player = Player(
      onPosition: (pos) async {
        if (!mounted) return;

        setState(() {
          _locationDenied = false;
          _lastPos = _currentPos;
          _currentPos = pos;
        });

        if (_mapReady) {
          await _playerModel?.addOrMove(lat: pos.latitude, lng: pos.longitude);
          
          if (!mounted) return;

          _recomputeNearbyMascots();

          if (_activeMascotId != null) {
            await _updateSelectedRoutesThrottled();
          }

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
        }
      },
      onHeading: (b) async {
        _gyroBearing = b;
        final now = DateTime.now();
        final minIntervalMs =
            defaultTargetPlatform == TargetPlatform.android ? 140 : 90;
        if (now.difference(_lastHeadingUpdate).inMilliseconds < minIntervalMs) {
          return;
        }
        if (_headingDelta(_lastAppliedHeading, _gyroBearing) < 2.0) return;
        _lastHeadingUpdate = now;
        _lastAppliedHeading = _gyroBearing;

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

  Future<void> _loadMascotData() async {
    for (var target in _allMascots) {
      if (target.idnumber != null) {
        final data = await getMascot(target.idnumber!);
        if (data != null) {
          setState(() {
            _mascotData[target.idnumber!] = data;
          });
        }
      }
    }
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
      maxUpdateHz: defaultTargetPlatform == TargetPlatform.android
          ? 6.0
          : MapIds.maxCameraUpdateHz,
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

    await _initMascotModels();
    await _ensureRoutesLayer();

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

      if (!mounted) return;
      setState(() {
        _recomputeNearbyMascots();
      });
    }
  }

  Future<void> _initMascotModels() async {
    for (final m in _mascotMarkers) {
      await m.dispose();
    }
    _mascotMarkers.clear();

    for (final t in _allMascots) {
      final marker = MascotAnnotations(
        id: t.id,
        map: _map!,
        assetPath: t.pngAssetPath,
        glbAssetPath: t.glbAssetPath,
        lat: t.lat,
        lng: t.lng,
        onTap: () {
          if (!mounted) return;
          if (t.idnumber == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => MascotScreen(
                    mascotId: t.idnumber!,
                    piId: t.piId ?? -1,
                  ),
            ),
          );
        },
        modelScale: MapIds.mascotModelScale,
        modelHeightMeters: t.height,
        modelHeadingOffset: MapIds.mascotModelHeadingOffset,
      );

      await marker.init();
      _mascotMarkers.add(marker);
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
      _pitch = defaultTargetPlatform == TargetPlatform.android
          ? 65.0
          : MapIds.defaultPitch;
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
    if (_isAutoFollow && _currentPos != null) {
      await _camera?.easeToPosition(
        pos: _currentPos!,
        zoom: _zoom,
        pitch: _pitch,
        bearing: _bearing,
      );
    }
  }

  void _recomputeNearbyMascots() {
    if (_currentPos == null) return;
    final p = _currentPos!;
    final items = <MascotWithDistance>[];
    for (final m in _allMascots) {
      final d = geo.Geolocator.distanceBetween(p.latitude, p.longitude, m.lat, m.lng);
      if (d <= _nearbyRadiusM) {
        items.add(MascotWithDistance(target: m, distanceM: d));
      }
    }
    items.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    setState(() {
      _nearbyMascots = items;
    });
  }

  double _headingDelta(double a, double b) {
    var d = (b - a).abs() % 360.0;
    if (d > 180.0) d = 360.0 - d;
    return d;
  }

  Future<void> _showNearbyMascotsOverlay() async {
    if (_currentPos == null) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Nearby mascots",
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(builder: (context, setDialogState) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text("Nearby Mascots",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                      if (_nearbyMascots.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("No mascots within 5km", style: TextStyle(color: Colors.white70)),
                        )
                      else
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _nearbyMascots.length,
                            itemBuilder: (context, index) {
                              final item = _nearbyMascots[index];
                              final isFollowing = _activeMascotId == item.target.id;
                              final mascot = _mascotData[item.target.idnumber];
                              final displayName = mascot?.mascotName ?? item.target.name;

                              Future<void> toggleTracking() async {
                                final newId = isFollowing ? null : item.target.id;
                                setState(() {
                                  _activeMascotId = newId;
                                });
                                setDialogState(() {});
                                await _updateSelectedRoutes();

                                // Update glow on markers
                                for (var m in _mascotMarkers) {
                                  await m.setGlow(m.id == _activeMascotId);
                                }
                              }

                              return GestureDetector(
                                onTap: () {
                                  // Click on mascot card now opens the catch page
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MascotScreen(
                                        mascotId: item.target.idnumber!,
                                        piId: item.target.piId ?? -1,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: isFollowing ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: isFollowing ? Colors.blue : Colors.transparent, width: 2),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            item.target.pngAssetPath,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.pets, color: Colors.white70, size: 40),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Text(displayName,
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      Text(_formatDistance(item.distanceM),
                                          style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                      const SizedBox(height: 4),
                                      // Track Button
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 28,
                                          child: ElevatedButton(
                                            onPressed: toggleTracking,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isFollowing ? Colors.blueGrey : Colors.blue,
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              isFollowing ? "Untrack" : "Track",
                                              style: const TextStyle(fontSize: 10, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return "${meters.round()} m";
    final km = meters / 1000.0;
    return "${km.toStringAsFixed(1)} km";
  }

  Future<void> _ensureRoutesLayer() async {
    if (_map == null) return;
    try {
      await _map!.style.addSource(mb.GeoJsonSource(id: _routesSourceId, data: _emptyFeatureCollection()));
    } catch (_) {}
    try {
      final layer = mb.LineLayer(id: _routesLayerId, sourceId: _routesSourceId)
            ..lineColor = Colors.blue.value
            ..lineWidth = 8.0
            ..lineOpacity = 0.8
            ..lineCap = mb.LineCap.ROUND
            ..lineJoin = mb.LineJoin.ROUND;
      await _map!.style.addLayer(layer);
    } catch (_) {}
  }

  String _emptyFeatureCollection() => convert.jsonEncode({"type": "FeatureCollection", "features": []});

  Future<void> _clearRoutes() async {
    if (_map == null) return;
    await _map!.style.setStyleSourceProperty(_routesSourceId, "data", _emptyFeatureCollection());
  }

  Future<void> _updateSelectedRoutesThrottled() async {
    final now = DateTime.now();
    if (now.difference(_lastRouteUpdate).inMilliseconds < 1200) return;
    _lastRouteUpdate = now;
    await _updateSelectedRoutes();
  }

  Future<void> _updateSelectedRoutes() async {
    if (!_mapReady || _currentPos == null) return;
    await _ensureRoutesLayer();
    if (_activeMascotId == null) {
      await _clearRoutes();
      return;
    }
    final startLat = _currentPos!.latitude;
    final startLng = _currentPos!.longitude;
    final target = _allMascots.firstWhere((m) => m.id == _activeMascotId);
    
    final feature = await _fetchRouteGeoJsonFeature(
        startLat: startLat, startLng: startLng, endLat: target.lat, endLng: target.lng,
        featureId: target.id, featureName: target.name,
      );
    
    if (feature != null) {
      final fc = convert.jsonEncode({"type": "FeatureCollection", "features": [feature]});
      await _map!.style.setStyleSourceProperty(_routesSourceId, "data", fc);
    }
  }

  Future<Map<String, dynamic>?> _fetchRouteGeoJsonFeature({
    required double startLat, required double startLng,
    required double endLat, required double endLng,
    required String featureId, required String featureName,
  }) async {
    try {
      final uri = Uri.parse("https://api.mapbox.com/directions/v5/mapbox/walking/"
        "$startLng,$startLat;$endLng,$endLat"
        "?geometries=geojson&overview=full&access_token=$_mapboxAccessToken");
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      final data = convert.json.decode(resp.body) as Map<String, dynamic>;
      final routes = data["routes"] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final geometry = routes[0]["geometry"] as Map<String, dynamic>?;
      if (geometry == null) return null;
      return {"type": "Feature", "id": featureId, "properties": {"name": featureName}, "geometry": geometry};
    } catch (_) { return null; }
  }

  @override
  void dispose() {
    for (final m in _mascotMarkers) { m.dispose(); }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_locationDenied) {
      return const Scaffold(body: SafeArea(child: Center(child: Text("Location permission required"))));
    }
    if (_currentPos == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final nearbyCount = _nearbyMascots.length;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          mb.MapWidget(
            styleUri: MapIds.styleUrl,
            cameraOptions: mb.CameraOptions(
              center: mb.Point(coordinates: mb.Position(_currentPos!.longitude, _currentPos!.latitude)),
              zoom: _zoom, pitch: _pitch, bearing: _bearing,
            ),
            key: const ValueKey('mapWidget'),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          const MapEdgeGradientOverlay(),
          SafeArea(
            child: Stack(
              children: [
                const MapTopTitle(),
                if (nearbyCount > 0)
                  Positioned(
                    top: 56,
                    right: 14,
                    child: _NearbyMascotCircle(count: nearbyCount, onTap: _showNearbyMascotsOverlay),
                  ),
                MapZoomControls(onZoomIn: () => _zoomBy(0.7), onZoomOut: () => _zoomBy(-0.7)),
                MapFollowControls(
                  isAutoFollow: _isAutoFollow,
                  onRecenter: _recenterOnPlayer,
                  onToggleFollow: _toggleFollowMode,
                  playerName: CurrentUser.user?.username ?? "Player",
                  playerSubtitle: "Lv. 1 • 0.0 km walked",
                  onPlayerPillTap: () => Navigator.pushNamed(context, Routes.profile),
                ),
                Positioned(
                  bottom: 13,
                  left: 230,
                  child: FloatingActionButton(
                    backgroundColor: const Color.fromRGBO(65, 64, 64, 1),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
                    child: const Icon(Icons.menu_book, color: Colors.white),
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

class _NearbyMascotCircle extends StatelessWidget {
  const _NearbyMascotCircle({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.60),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Center(
            child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class MascotTarget {
  const MascotTarget({
    this.idnumber,
    this.piId,
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.glbAssetPath,
    required this.pngAssetPath,
    this.height = 0.0,
  });

  final int? idnumber;
  final int? piId;
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String glbAssetPath;
  final String pngAssetPath;
  final double height;
}

class MascotWithDistance {
  const MascotWithDistance({required this.target, required this.distanceM});
  final MascotTarget target;
  final double distanceM;
}
