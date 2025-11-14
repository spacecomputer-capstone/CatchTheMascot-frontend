import 'package:flutter/material.dart';
import '../utils/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catch the Mascot')),
      body: Center(
        child: Transform.translate(
          offset: const Offset(0, -55), // middle of the screen
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'lib/assets/icons/storke.png',
                height: 400,
              ),

              const SizedBox(height: 30),

              const Text(
                'Welcome to Catch the Mascot!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.locationPermission);
                },
                child: const Text('Start Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}