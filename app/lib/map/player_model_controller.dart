import 'dart:convert' as convert;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

class PlayerModelController {
  PlayerModelController({
    required this.map,
    required this.sourceId,
    required this.layerId,
    required this.modelHeadingOffset,
  });

  final mb.MapboxMap map;
  final String sourceId;
  final String layerId;
  final double modelHeadingOffset;

  bool _modelAdded = false;

  bool get isAdded => _modelAdded;

  Future<void> addOrMove({required double lat, required double lng}) async {
    final point = mb.Point(coordinates: mb.Position(lng, lat));
    final data = convert.json.encode(point);

    if (!_modelAdded) {
      await map.style.addSource(
        mb.GeoJsonSource(id: sourceId, data: data),
      );

      final layer = mb.ModelLayer(id: layerId, sourceId: sourceId)
        ..modelId = "asset://assets/player/player.glb"
        ..modelScale = const [20.0, 20.0, 20.0]
        ..modelRotation = const [0.0, 0.0, 0.0]
        ..modelType = mb.ModelType.COMMON_3D;

      await map.style.addLayer(layer);
      _modelAdded = true;
      return;
    }

    // Move existing model by updating GeoJSON source data
    await map.style.setStyleSourceProperty(sourceId, 'data', data);
  }

  Future<void> setHeading(double gyroBearing) async {
    if (!_modelAdded) return;

    final yaw = ((gyroBearing + modelHeadingOffset) % 360 + 360) % 360;

    await map.style.setStyleLayerProperty(
      layerId,
      "model-rotation",
      [0.0, 0.0, yaw],
    );
  }
}
