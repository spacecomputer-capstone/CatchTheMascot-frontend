class MapIds {
  static const String styleUrl =
      "mapbox://styles/sanilkatula/cmib4spww003q01sn7rzu63yd";

  static const String playerSourceId = "player-source-id";
  static const String playerModelLayerId = "player-model-layer";

  // Player Path
  static const String playerGlbAsset = 'assets/player/player.glb';

  // Base paths for mascots
  static const String mascotGlbDir = 'lib/assets/3dmascots';
  static const String mascotPngDir = 'lib/assets/mascotimages';

  static const double storkeLat = 34.412640;
  static const double storkeLng = -119.848396;

  // Henley Hall
  static const double henleyLat = 34.41687562912479;
  static const double henleyLng = -119.8444312386711;

  static const double minZoom = 14.0;
  static const double maxZoom = 22.0;
  static const double defaultZoom = 18.5;
  static const double autoFollowZoom = 19.0;
  static const double defaultPitch = 80.0;

  static const double maxCameraUpdateHz = 10;

  static const double playerModelHeadingOffset = 180.0;
  static const double mascotModelScale = 25.0;
  
  // Increased height from 0.0 to 3.0 meters to prevent mascots from being buried in the ground/terrain
  static const double mascotModelHeightMeters = 3.0;
  
  static const double mascotModelHeadingOffset = 0.0;
}
