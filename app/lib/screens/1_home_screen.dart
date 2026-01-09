import 'package:flutter/material.dart';
import '../utils/routes.dart';
import 'dart:ui';
import 'package:app/state/current_user.dart';
import 'package:app/apis/user_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = false;

  final TextEditingController registerUsernameController =
      TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();

  final TextEditingController loginUsernameController =
      TextEditingController();
  final TextEditingController loginPasswordController =
      TextEditingController();

  static bool debug = true; //set to true to show API test button

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
                      usernameController: registerUsernameController,
                      passwordController: registerPasswordController,
                      onPressed: () async {
                        final username = registerUsernameController.text.trim();
                        final password = registerPasswordController.text.trim();

                        if (username.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Fill all fields")),
                          );
                          return;
                        }

                        setState(() => isLoading = true);
                        final user =
                            await addUserAndReturnUser(username, password, context);

                        setState(() => isLoading = false);

                        if (user != null) {
                          CurrentUser.set(user);
                          Navigator.pushReplacementNamed(
                              context, Routes.locationPermission);
                        }
                      },
                    ),

                    const SizedBox(height: 25),

                    _formBox(
                      title: "Log In",
                      buttonText: "Log In",
                      usernameController: loginUsernameController,
                      passwordController: loginPasswordController,
                      onPressed: () async {
                        final username = loginUsernameController.text.trim();
                        final password = loginPasswordController.text.trim();

                        setState(() => isLoading = true);

                        final user =
                            await loginUserAndReturnUser(username, password, context);

                        setState(() => isLoading = false);

                        if (user != null) {
                          CurrentUser.set(user);
                          Navigator.pushReplacementNamed(
                              context, Routes.locationPermission);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invalid credentials")),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Welcome to Catch the Mascot!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.pushNamed(context, Routes.locationPermission);
                    //   },
                    //   child: const Text('Start Game'),
                    // ),

                    if (CurrentUser.isLoggedIn)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.locationPermission);
                        },
                        child: const Text('Continue Game'),
                      )
                    else
                      const Text(
                        "Please log in to start",
                        style: TextStyle(color: Colors.white),
                      ),

                    const SizedBox(height: 60),

                    if (debug == true) ...[
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.apiTest);
                        },
                        child: const Text('Test Mascot API'),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.userApiTest);
                        },
                        child: const Text('Test User API'),
                      ),

                      const SizedBox(height: 60),
                    ],
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
  // Widget _formBox({
  //   required String title,
  //   required String buttonText,
  //   required VoidCallback onPressed,
  // })
  Widget _formBox({
    required String title,
    required String buttonText,
    required TextEditingController usernameController,
    required TextEditingController passwordController,
    required VoidCallback onPressed,
  })
   {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
