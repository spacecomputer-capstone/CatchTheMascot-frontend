import 'dart:convert' as convert;
import 'dart:math' as math;

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

  // You can have multiple mascots visible on map:
  final List<MascotAnnotations> _mascotMarkers = [];

  bool get _mapReady => _map != null && _styleLoaded;

  // ---------------- Nearby mascots + routes ----------------

  // Mapbox token for Directions API
  // (Use your same token; feel free to move this into MapIds)
  static const String _mapboxAccessToken =
      "pk.eyJ1Ijoic2FuaWxrYXR1bGEiLCJhIjoiY21pYjRoOHZsMDVyZjJpcHFxdmg2OXVicSJ9.JBlvf3X2eEd7TA0u8K5B0Q";

  // Nearby detection radius (meters)
  static const double _nearbyRadiusM = 1200;

  // Route rendering ids
  static const String _routesSourceId = "nearby-routes-source";
  static const String _routesLayerId = "nearby-routes-layer";

  // In-memory mascot list (you can later replace with server-driven list)
  // Add more mascots here.
  final List<MascotTarget> _allMascots = [
    MascotTarget(
      id: "storky",
      name: "Storky Tower",
      lat: MapIds.storkeLat,
      lng: MapIds.storkeLng,
      glbAssetPath: MapIds.fixedMascotGlbAsset,
      pngAssetPath: MapIds.fixedMascotImageAsset,
    ),
    // Example extras (replace with real):
    // MascotTarget(
    //   id: "m2",
    //   name: "Mascot #2",
    //   lat: 34.4132,
    //   lng: -119.8476,
    //   glbAssetPath: MapIds.fixedMascotGlbAsset,
    //   pngAssetPath: MapIds.fixedMascotImageAsset,
    // ),
  ];

  // computed
  List<MascotWithDistance> _nearbyMascots = [];

  // selection (ids)
  final Set<String> _selectedMascotIds = {};

  // avoid spamming API while user walks
  DateTime _lastRouteUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------- Lifecycle ----------------

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

        if (_mapReady) {
          await _playerModel?.addOrMove(lat: pos.latitude, lng: pos.longitude);
          if (!mounted) return;

          _recomputeNearbyMascots();

          // If user selected mascots, keep refreshing routes (throttled)
          if (_selectedMascotIds.isNotEmpty) {
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

    // 1) Add mascot 3D models (all mascots in list)
    await _initMascotModels();

    // 2) Prepare empty routes layer
    await _ensureRoutesLayer();

    // If we already have GPS, place player + compute nearby
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
    // clear any existing
    for (final m in _mascotMarkers) {
      await m.dispose();
    }
    _mascotMarkers.clear();

    // Create one MascotAnnotations per mascot
    for (final t in _allMascots) {
      final marker = MascotAnnotations(
        map: _map!,
        assetPath: t.pngAssetPath,       // invisible hitbox
        glbAssetPath: t.glbAssetPath,    // visible model
        lat: t.lat,
        lng: t.lng,
        onTap: () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MascotScreen()),
          );
        },
        modelScale: MapIds.mascotModelScale,
        modelHeightMeters: MapIds.mascotModelHeightMeters,
        modelHeadingOffset: MapIds.mascotModelHeadingOffset,
      );

      await marker.init();
      _mascotMarkers.add(marker);
    }
  }

  // ---------------- Zoom / follow controls ----------------

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

    if (_isAutoFollow && _currentPos != null) {
      await _camera?.easeToPosition(
        pos: _currentPos!,
        zoom: _zoom,
        pitch: _pitch,
        bearing: _bearing,
      );
    }
  }

  // ---------------- Nearby mascots + selection UI ----------------

  void _recomputeNearbyMascots() {
    if (_currentPos == null) return;

    final p = _currentPos!;
    final items = <MascotWithDistance>[];

    for (final m in _allMascots) {
      final d = geo.Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        m.lat,
        m.lng,
      );

      if (d <= _nearbyRadiusM) {
        items.add(MascotWithDistance(target: m, distanceM: d));
      }
    }

    items.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    _nearbyMascots = items;
  }

  Future<void> _openNearbyMascotsSheet() async {
    if (_currentPos == null) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121212),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Nearby mascots",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${_nearbyMascots.length}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_nearbyMascots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          "No mascots nearby yet.",
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _nearbyMascots.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withOpacity(0.08),
                          ),
                          itemBuilder: (_, i) {
                            final item = _nearbyMascots[i];
                            final selected = _selectedMascotIds.contains(item.target.id);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.target.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _formatDistance(item.distanceM),
                                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                              ),
                              trailing: Checkbox(
                                value: selected,
                                onChanged: (v) async {
                                  final newVal = v ?? false;
                                  setSheetState(() {
                                    if (newVal) {
                                      _selectedMascotIds.add(item.target.id);
                                    } else {
                                      _selectedMascotIds.remove(item.target.id);
                                    }
                                  });

                                  // Update routes immediately
                                  await _updateSelectedRoutes();
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),
                              onTap: () async {
                                setSheetState(() {
                                  if (selected) {
                                    _selectedMascotIds.remove(item.target.id);
                                  } else {
                                    _selectedMascotIds.add(item.target.id);
                                  }
                                });
                                await _updateSelectedRoutes();
                                if (!mounted) return;
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              setSheetState(() {
                                _selectedMascotIds.clear();
                              });
                              await _clearRoutes();
                              if (!mounted) return;
                              setState(() {});
                            },
                            child: const Text("Clear paths"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Keep map centered on player; just show paths.
                              Navigator.of(ctx).pop();
                            },
                            child: const Text("Done"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return "${meters.round()} m";
    final km = meters / 1000.0;
    return "${km.toStringAsFixed(2)} km";
  }

  // ---------------- Routes rendering (Mapbox Directions + LineLayer) ----------------

  Future<void> _ensureRoutesLayer() async {
    if (_map == null) return;

    // Add empty source if not present
    try {
      await _map!.style.addSource(
        mb.GeoJsonSource(
          id: _routesSourceId,
          data: _emptyFeatureCollection(),
        ),
      );
    } catch (_) {
      // source may already exist
    }

    // Add line layer if not present
    try {
      final layer = mb.LineLayer(id: _routesLayerId, sourceId: _routesSourceId)
        ..lineWidth = 5.0
        ..lineOpacity = 0.85;
      await _map!.style.addLayer(layer);
    } catch (_) {
      // layer may already exist
    }
  }

  String _emptyFeatureCollection() => convert.jsonEncode({
    "type": "FeatureCollection",
    "features": [],
  });

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

    if (_selectedMascotIds.isEmpty) {
      await _clearRoutes();
      return;
    }

    final startLat = _currentPos!.latitude;
    final startLng = _currentPos!.longitude;

    final selected = _allMascots.where((m) => _selectedMascotIds.contains(m.id)).toList();

    // Fetch routes in parallel
    final futures = selected.map((m) => _fetchRouteGeoJsonFeature(
      startLat: startLat,
      startLng: startLng,
      endLat: m.lat,
      endLng: m.lng,
      featureId: m.id,
      featureName: m.name,
    ));

    final features = (await Future.wait(futures)).whereType<Map<String, dynamic>>().toList();

    final fc = convert.jsonEncode({
      "type": "FeatureCollection",
      "features": features,
    });

    await _map!.style.setStyleSourceProperty(_routesSourceId, "data", fc);
  }

  Future<Map<String, dynamic>?> _fetchRouteGeoJsonFeature({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String featureId,
    required String featureName,
  }) async {
    try {
      final uri = Uri.parse(
        "https://api.mapbox.com/directions/v5/mapbox/walking/"
            "$startLng,$startLat;$endLng,$endLat"
            "?geometries=geojson&overview=full&access_token=$_mapboxAccessToken",
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;

      final data = convert.json.decode(resp.body) as Map<String, dynamic>;
      final routes = data["routes"] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final geometry = routes[0]["geometry"] as Map<String, dynamic>?;
      if (geometry == null) return null;

      // geometry is a GeoJSON LineString
      return {
        "type": "Feature",
        "id": featureId,
        "properties": {
          "name": featureName,
        },
        "geometry": geometry,
      };
    } catch (_) {
      return null;
    }
  }

  // ---------------- Dispose ----------------

  @override
  void dispose() {
    for (final m in _mascotMarkers) {
      m.dispose();
    }
    _player.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

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

    final nearbyCount = _nearbyMascots.length;

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

                // ✅ Small circular pill (top-right), placed lower so it doesn't collide with your title.
                if (nearbyCount > 0)
                  Positioned(
                    top: 56,  // pushes below your Catch the mascot pill area
                    right: 14,
                    child: _NearbyMascotCircle(
                      count: nearbyCount,
                      onTap: _openNearbyMascotsSheet,
                    ),
                  ),

                MapZoomControls(
                  onZoomIn: () => _zoomBy(0.7),
                  onZoomOut: () => _zoomBy(-0.7),
                ),
                MapFollowControls(
                  isAutoFollow: _isAutoFollow,
                  onRecenter: _recenterOnPlayer,
                  onToggleFollow: _toggleFollowMode,
                  playerName: CurrentUser.user?.username ?? "Player",
                  playerSubtitle: "Lv. 1 • 0.0 km walked",
                  onPlayerPillTap: () {
                    Navigator.pushNamed(context, Routes.profile);
                  },
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
  const _NearbyMascotCircle({
    required this.count,
    required this.onTap,
  });

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
            child: Text(
              "$count",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Simple data models
class MascotTarget {
  const MascotTarget({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.glbAssetPath,
    required this.pngAssetPath,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String glbAssetPath;
  final String pngAssetPath;
}

class MascotWithDistance {
  const MascotWithDistance({
    required this.target,
    required this.distanceM,
  });

  final MascotTarget target;
  final double distanceM;
}
