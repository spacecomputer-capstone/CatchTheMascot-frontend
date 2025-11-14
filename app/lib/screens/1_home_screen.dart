import 'package:flutter/material.dart';
import '../utils/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catch the Mascot')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Catch the Mascot!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            //location permission button
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, Routes.locationPermission);
              },
              child: const Text('Start Game'),
            ),

            const SizedBox(height: 10), // Add spacing between buttons

            //test api button
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, Routes.apiTest);
              },
              child: const Text('Test API'),
            ),
          ],
        ),
      ),
    );
  }
}