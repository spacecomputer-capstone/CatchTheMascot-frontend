class MapIds {
  static const String styleUrl =
      "mapbox://styles/sanilkatula/cmib4spww003q01sn7rzu63yd";

  static const String playerSourceId = "player-source-id";
  static const String playerModelLayerId = "player-model-layer";

  // PNG (still used as invisible click-hitbox)
  static const String fixedMascotImageAsset =
      'assets/icons/storke-nobackground.png';

  // GLB (the visible mascot)
  static const String fixedMascotGlbAsset =
      'assets/icons/storke-nobackground.glb';

  static const double storkeLat = 34.412640;
  static const double storkeLng = -119.848396;

  static const double minZoom = 14.0;
  static const double maxZoom = 22.0;
  static const double defaultZoom = 18.5;
  static const double autoFollowZoom = 19.0;
  static const double defaultPitch = 80.0;

  static const double maxCameraUpdateHz = 10;

  // Player faces backwards in your setup, so you offset 180
  static const double playerModelHeadingOffset = 180.0;

  // Mascot model tuning – MATCH PLAYER SCALE
  // Your PlayerModelController uses [10,10,10]
  static const double mascotModelScale = 10.0;

  // Player doesn't translate upward, so keep 0.0 for "same height"
  static const double mascotModelHeightMeters = 0.0;

  // If your storky faces backwards, set 180.0; otherwise keep 0.0
  static const double mascotModelHeadingOffset = 0.0;
}
