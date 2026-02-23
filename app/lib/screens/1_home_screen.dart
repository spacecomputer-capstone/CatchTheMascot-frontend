import 'package:flutter/material.dart';
import '../utils/routes.dart';
import 'package:app/state/current_user.dart';
import 'package:app/apis/user_api.dart';
import 'dart:ui' as ui;
import 'package:app/screens/helpers.dart';

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

  final TextEditingController loginUsernameController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  // static bool debug = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF050814),
              Color(0xFF081A3A),
              Color(0xFF233D7B),
              Color(0xFF4263EB),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background mascot glow
              Positioned.fill(
                child: Opacity(
                  opacity: 0.2,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Image.asset(
                      'assets/icons/storke-nobackground.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),

              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        const Text(
                          'Catch the Mascot',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Become a Gaucho Trainer.',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),

                        const SizedBox(height: 40),
                        Center(
                          child: _formBox(
                            title: "Log In",
                            buttonText: "Log In",
                            usernameController: loginUsernameController,
                            passwordController: loginPasswordController,
                            onPressed: _handleLogin,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.register);
                          },
                          child: const Text(
                            "Create Account",
                            style: TextStyle(
                              color: Color(0xFFFFC857),
                              fontSize: 15,
                            ),
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- REGISTER ----------------

  Future<void> _handleRegister() async {
    final username = registerUsernameController.text.trim();
    final password = registerPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    final user = await addUserAndReturnUser(username, password, context);

    setState(() => isLoading = false);

    if (user != null) {
      CurrentUser.set(user);
      Navigator.pushReplacementNamed(context, Routes.tutorial);
    }
  }

  // ---------------- LOGIN ----------------

  Future<void> _handleLogin() async {
    final username = loginUsernameController.text.trim();
    final password = loginPasswordController.text.trim();

    setState(() => isLoading = true);

    final user = await loginUserAndReturnUser(username, password, context);

    setState(() => isLoading = false);

    if (user != null) {
      CurrentUser.set(user);

      //check if the last check-in date is one day before today, if so award daily reward and update last check-in date
      if (DateTime.now().difference(user.lastCheckInDate).inDays >= 1) {
        user.coins += getdailyReward();
        user.lastCheckInDate = DateTime.now();
        await updateUser(user, context);

        // Show a snackbar to inform the user about the daily reward
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Daily Check-in: +${getdailyReward()} coins!"),
          ),
        );
      }

      Navigator.pushReplacementNamed(context, Routes.locationPermission);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid credentials")));
    }
  }

  // ---------------- FORM BOX ----------------
  Widget _formBox({
    required String title,
    required String buttonText,
    required TextEditingController usernameController,
    required TextEditingController passwordController,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          _themedTextField(controller: usernameController, label: "Username"),
          const SizedBox(height: 14),
          _themedTextField(
            controller: passwordController,
            label: "Password",
            obscure: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFFFFC857),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themedTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFFC857)),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
