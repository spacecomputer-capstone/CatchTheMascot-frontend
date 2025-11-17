import 'package:firebase_core/firebase_core.dart'; //firebase
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/1_home_screen.dart';
import 'screens/2_location_permission_screen.dart';
// import 'screens/3_map_screen.dart';
// import 'screens/4_verification_screen.dart';
// import 'screens/5_verification_result_screen.dart';
// import 'screens/6_catch_screen.dart';
// import 'screens/7_catch_result_screen.dart';
// import 'screens/8_inventory_screen.dart';
import 'screens/99_api_test_screen.dart';
import 'utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; //firebasefirestore

// void main() => runApp(const CatchTheMascotApp());

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Firebase initialized");
  print(
    'Firebase projectId: ${FirebaseFirestore.instance.app.options.projectId}',
  );

  // On web, disable persistence IMMEDIATELY before any Firestore operations
  // This must happen before any .get(), .add(), .set(), etc.
  if (kIsWeb) {
    print("Running on web; disabling Firestore persistence.");
    try {
      await FirebaseFirestore.instance.disableNetwork();
      FirebaseFirestore.instance.settings = Settings(persistenceEnabled: false);
      await FirebaseFirestore.instance.enableNetwork();
      print('Web: Firestore persistence disabled and network re-enabled');
    } catch (e) {
      print('Could not disable persistence: $e');
    }
  }

  try {
    var snapshot =
        await FirebaseFirestore.instance
            .collection('templatemascot0')
            .limit(1)
            .get();
    print('Firestore works: ${snapshot.docs.length} docs');
  } catch (e) {
    print('Firestore failed: $e');
  }

  print("Initialization complete -------------------");
  print("");

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
        // Routes.inventory: (context) => const InventoryScreen(),
        Routes.apiTest: (context) => ApiTestScreen(),
      },
    );
  }
}
