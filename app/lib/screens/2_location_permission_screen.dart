import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/utils/routes.dart';
import 'package:app/state/current_user.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  Future<void> _requestPermission(BuildContext context) async {
    if (kIsWeb) {
      // --- WEB LOGIC ---
      final allowed = await Geolocator.isLocationServiceEnabled();
      LocationPermission perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        Navigator.pushReplacementNamed(context, Routes.map);
      } else {
        // Web browsers do NOT permanently deny, but can block from the UI
        debugPrint("Web: permission not granted");
      }

      return;
    }

    // --- MOBILE LOGIC (Android + iOS) ---
    final status = await Permission.locationWhenInUse.request();

    if (status.isGranted) {
      Navigator.pushReplacementNamed(context, Routes.map);
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allow Location')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (CurrentUser.isLoggedIn) ...[
              Text(
                'Welcome, ${CurrentUser.user!.username} 👋',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Catch the Mascot needs your location to play.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _requestPermission(context),
              child: const Text('Enable Location'),
            ),
          ],
        ),
      ),
    );
  }
}