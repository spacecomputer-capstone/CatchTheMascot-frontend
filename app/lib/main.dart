import 'package:flutter/material.dart';
import 'screens/1_home_screen.dart';
import 'screens/2_location_permission_screen.dart';
// import 'screens/3_map_screen.dart';
// import 'screens/4_verification_screen.dart';
// import 'screens/5_verification_result_screen.dart';
// import 'screens/6_catch_screen.dart';
// import 'screens/7_catch_result_screen.dart';
// import 'screens/8_inventory_screen.dart';
import 'utils/routes.dart';

void main() => runApp(const CatchTheMascotApp());

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
        Routes.locationPermission: (context) => const LocationPermissionScreen(),
        // Routes.map: (context) => const MapScreen(),
        // Routes.verification: (context) => const VerificationScreen(),
        // Routes.verificationResult: (context) => const VerificationResultScreen(),
        // Routes.catchScreen: (context) => const CatchScreen(),
        // Routes.catchResult: (context) => const CatchResultScreen(),
        // Routes.inventory: (context) => const InventoryScreen(),
      },
    );
  }
}
