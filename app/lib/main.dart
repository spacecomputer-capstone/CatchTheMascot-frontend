import 'package:firebase_core/firebase_core.dart'; //firebase
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'screens/1_home_screen.dart';
import 'screens/2_location_permission_screen.dart';
// import 'screens/3_map_screen.dart';
// import 'screens/4_verification_screen.dart';
// import 'screens/5_verification_result_screen.dart';
// import 'screens/6_catch_screen.dart';
// import 'screens/7_catch_result_screen.dart';
import 'screens/8_inventory_screen.dart';
import 'screens/3.1_mapbox_screen.dart';
import 'screens/1_home_screen.dart';
import 'screens/2_location_permission_screen.dart';
import 'screens/99_mascot_api_test_screen.dart';
import 'utils/routes.dart';
//firebasefirestore
import 'package:app/apis/mascot_api.dart';
import 'package:app/models/mascot.dart';
import 'screens/99_user_api_test_screen.dart';
import 'package:app/state/current_user.dart';
import 'package:app/state/current_user.dart';
import 'screens/tutorial_screen.dart';

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //restore the logged in user
  await CurrentUser.restoreIfPossible();

  //load mascots from firestore and save highest mascotId locally
  List<Mascot> mascots = [];
  await getMascots(mascots);

  // Then run the app
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
        Routes.locationPermission:
            (context) => const LocationPermissionScreen(),
        // Routes.map: (context) => const MapScreen(),
        // Routes.verification: (context) => const VerificationScreen(),
        // Routes.verificationResult: (context) => const VerificationResultScreen(),
        // Routes.catchScreen: (context) => const CatchScreen(),
        // Routes.catchResult: (context) => const CatchResultScreen(),
        Routes.inventory: (context) => const InventoryScreen(),
        // Routes.caughtMascots: (context) => const CaughtMascotsScreen(),
        Routes.map: (context) => const CatchMascotMapboxScreen(),
        Routes.apiTest: (context) => ApiTestScreen(),
        Routes.userApiTest: (context) => const UserApiTestScreen(),
        Routes.tutorial: (context) => const TutorialScreen(),
      },
    );
  }
}
