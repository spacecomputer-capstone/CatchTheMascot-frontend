import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

class MascotAnnotations {
  MascotAnnotations({
    required this.map,
    required this.assetPath,
    required this.lat,
    required this.lng,
    required this.onTap,
  });

  final mb.MapboxMap map;
  final String assetPath;
  final double lat;
  final double lng;
  final VoidCallback onTap;

  mb.PointAnnotationManager? _mgr;
  Uint8List? _imageBytes;

  Future<void> init() async {
    _mgr = await map.annotations.createPointAnnotationManager();
    await _loadAsset();
    await _createMarker();
  }

  Future<void> dispose() async {
    if (_mgr != null) {
      map.annotations.removeAnnotationManager(_mgr!);
    }
  }

  Future<void> _loadAsset() async {
    final data = await rootBundle.load(assetPath);
    _imageBytes = data.buffer.asUint8List();
  }

  Future<void> _createMarker() async {
    if (_mgr == null) return;

    await _mgr!.deleteAll();

    final options = mb.PointAnnotationOptions(
      geometry: mb.Point(coordinates: mb.Position(lng, lat)),
      iconSize: 0.9,
    );

    if (_imageBytes != null) {
      options.image = _imageBytes!;
    } else {
      options.iconImage = "marker-15";
    }

    final mascot = await _mgr!.create(options);

    _mgr!.addOnPointAnnotationClickListener(_Listener((annotation) {
      if (annotation.id == mascot.id) onTap();
    }));
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
