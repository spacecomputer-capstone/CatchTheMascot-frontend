import 'package:flutter/material.dart';
import '../utils/routes.dart';
import 'dart:ui';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catch the Mascot')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // BACKGROUND MASCOT (blurred + centered)
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 1, // adjustable
                child: Image.asset(
                  'lib/assets/icons/storke.png',
                  height: 1000,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),

          // add blur layer on top of image
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.transparent),
            ),
          ),

          // FOREGROUND: Scrollable login/register boxes
          Center(
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    _formBox(
                      title: "Register",
                      buttonText: "Register",
                      onPressed: () {},
                    ),

                    const SizedBox(height: 25),

                    _formBox(
                      title: "Log In",
                      buttonText: "Log In",
                      onPressed: () {},
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

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // REUSABLE BOX WITH USERNAME, PASSWORD, AND BUTTON
  // ----------------------------------------------------
  Widget _formBox({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}