import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

class MascotAnnotations {
  MascotAnnotations({
    required this.id,
    required this.map,
    required this.assetPath,
    required this.glbAssetPath,
    required this.lat,
    required this.lng,
    required this.onTap,
    required this.modelScale,
    required this.modelHeightMeters,
    required this.modelHeadingOffset,
  });

  final String id;
  final mb.MapboxMap map;
  final String assetPath;
  final String glbAssetPath;
  double lat;
  double lng;
  final VoidCallback onTap;

  final double modelScale;
  final double modelHeightMeters;
  final double modelHeadingOffset;

  mb.PointAnnotationManager? _mgr;
  Uint8List? _imageBytes;
  mb.PointAnnotation? _tapPoint;

  String get _sourceId => "mascot-source-$id";
  String get _layerId => "mascot-layer-$id";

  bool _modelAdded = false;

  Future<void> init() async {
    try {
      await rootBundle.load(glbAssetPath);
    } catch (e) {
      debugPrint("Failed to load mascot asset: $glbAssetPath - $e");
    }

    await _addOrUpdate3dModel();

    _mgr = await map.annotations.createPointAnnotationManager();
    await _loadAsset();
    await _createInvisibleTapHitbox();
  }

  Future<void> setGlow(bool active) async {
    final layerExists = await map.style.styleLayerExists(_layerId);
    if (!layerExists) return;
    
    // Scale up slightly to "glow" or emphasize
    final scale = active ? modelScale * 1.5 : modelScale;
    
    await map.style.setStyleLayerProperty(
      _layerId,
      "model-scale",
      [scale, scale, scale],
    );
  }

  Future<void> moveTo(double newLat, double newLng) async {
    lat = newLat;
    lng = newLng;
    await _addOrUpdate3dModel();
    await _createInvisibleTapHitbox();
  }

  Future<void> dispose() async {
    try {
      if (_mgr != null) {
        map.annotations.removeAnnotationManager(_mgr!);
      }
    } catch (_) {}

    try {
      final layerExists = await map.style.styleLayerExists(_layerId);
      if (layerExists) {
        await map.style.removeStyleLayer(_layerId);
      }
      final sourceExists = await map.style.styleSourceExists(_sourceId);
      if (sourceExists) {
        await map.style.removeStyleSource(_sourceId);
      }
    } catch (_) {}
  }

  Future<void> _addOrUpdate3dModel() async {
    final point = mb.Point(coordinates: mb.Position(lng, lat));
    final data = convert.json.encode(point);

    try {
      final sourceExists = await map.style.styleSourceExists(_sourceId);
      
      if (!sourceExists) {
        await map.style.addSource(mb.GeoJsonSource(id: _sourceId, data: data));

        final layer = mb.ModelLayer(id: _layerId, sourceId: _sourceId)
          ..modelId = _modelUri(glbAssetPath)
          ..modelScale = [modelScale, modelScale, modelScale]
          ..modelTranslation = [0.0, 0.0, modelHeightMeters]
          ..modelRotation = [0.0, 0.0, modelHeadingOffset]
          ..modelType = mb.ModelType.COMMON_3D;

        await map.style.addLayer(layer);
        _modelAdded = true;
        return;
      }
    } catch (e) {
      debugPrint("Error checking/adding mascot source: $e");
    }

    await map.style.setStyleSourceProperty(_sourceId, 'data', data);
    _modelAdded = true;
  }

  String _modelUri(String flutterAssetPath) {
    if (flutterAssetPath.startsWith("asset://")) return flutterAssetPath;
    return "asset://$flutterAssetPath";
  }

  Future<void> _loadAsset() async {
    try {
      final data = await rootBundle.load(assetPath);
      _imageBytes = data.buffer.asUint8List();
    } catch (_) {
      _imageBytes = null;
    }
  }

  Future<void> _createInvisibleTapHitbox() async {
    if (_mgr == null) return;

    await _mgr!.deleteAll();

    final options = mb.PointAnnotationOptions(
      geometry: mb.Point(coordinates: mb.Position(lng, lat)),
      iconSize: 2.0,
      iconOpacity: 0.0,
    );

    if (_imageBytes != null) {
      options.image = _imageBytes!;
    } else {
      options.iconImage = "marker-15";
    }

    _tapPoint = await _mgr!.create(options);

    _mgr!.addOnPointAnnotationClickListener(
      _Listener((annotation) {
        if (_tapPoint != null && annotation.id == _tapPoint!.id) onTap();
      }),
    );
  }
}

class _Listener extends mb.OnPointAnnotationClickListener {
  _Listener(this.onClicked);
  final void Function(mb.PointAnnotation annotation) onClicked;

  @override
  void onPointAnnotationClick(mb.PointAnnotation annotation) {
    onClicked(annotation);
  }
}
