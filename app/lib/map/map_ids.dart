class MapIds {
  static const String styleUrl =
      "mapbox://styles/sanilkatula/cmib4spww003q01sn7rzu63yd";

  static const String playerSourceId = "player-source-id";
  static const String playerModelLayerId = "player-model-layer";

  // Player Path
  static const String playerGlbAsset = 'assets/player/player.glb';

  // Base paths for mascots (Now in assets/ as requested)
  static const String mascotGlbDir = 'assets/3dmascots';
  static const String mascotPngDir = 'assets/mascotimages';

  static const double storkeLat = 34.412640;
  static const double storkeLng = -119.848396;

  static const double minZoom = 14.0;
  static const double maxZoom = 22.0;
  static const double defaultZoom = 18.5;
  static const double autoFollowZoom = 19.0;
  static const double defaultPitch = 80.0;

  static const double maxCameraUpdateHz = 10;

  static const double playerModelHeadingOffset = 180.0;
  static const double mascotModelScale = 10.0;
  static const double mascotModelHeightMeters = 0.0;
  static const double mascotModelHeadingOffset = 0.0;
}
