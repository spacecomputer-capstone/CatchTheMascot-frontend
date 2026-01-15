import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

Future<void> updateGesturesSettings(mb.MapboxMap map, {required bool isAutoFollow}) {
  return map.gestures.updateSettings(
    mb.GesturesSettings(
      scrollEnabled: !isAutoFollow,
      rotateEnabled: !isAutoFollow,
      pitchEnabled: !isAutoFollow,
      pinchToZoomEnabled: true,
      doubleTapToZoomInEnabled: true,
      doubleTouchToZoomOutEnabled: true,
    ),
  );
}
