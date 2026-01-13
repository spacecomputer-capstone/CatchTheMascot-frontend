import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/1_home_screen.dart';
import 'screens/2_location_permission_screen.dart';
import 'screens/3.1_mapbox_screen.dart'; // ✅ MAPBOX SCREEN
import 'screens/5_mascot_screen.dart'; // Added by me previously, ensuring it's available if needed, though routes use string keys usually.
import 'screens/99_mascot_api_test_screen.dart';
import 'screens/99_user_api_test_screen.dart';

import 'utils/routes.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:app/models/mascot.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapboxOptions.setAccessToken(
    "pk.eyJ1Ijoic2FuaWxrYXR1bGEiLCJhIjoiY21pYjRoOHZsMDVyZjJpcHFxdmg2OXVicSJ9.JBlvf3X2eEd7TA0u8K5B0Q",
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  List<Mascot> mascots = [];
  await getMascots(mascots);

  runApp(const CatchTheMascotApp());
}

class CatchTheMascotApp extends StatelessWidget {
  const CatchTheMascotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Catch The Mascot',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: Routes.home,
      routes: {
        Routes.home: (context) => const HomeScreen(),
        Routes.locationPermission: (context) =>
            const LocationPermissionScreen(),

        // 👇 Map route now uses Mapbox screen
        Routes.map: (context) => const CatchMascotMapboxScreen(),

        Routes.apiTest: (context) => ApiTestScreen(),
        Routes.userApiTest: (context) => const UserApiTestScreen(),
      },
    );
  }
}
