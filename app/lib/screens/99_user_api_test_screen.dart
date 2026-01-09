import 'package:flutter/material.dart';
import '../utils/routes.dart';
import 'dart:ui';
import 'package:app/models/user.dart';
import 'package:app/apis/user_api.dart';

class UserApiTestScreen extends StatefulWidget {
  const UserApiTestScreen({super.key});
  // static bool debug = true; //set to true to show API test button

  @override
  State<UserApiTestScreen> createState() => _UserApiTestScreenState();
}

class _UserApiTestScreenState extends State<UserApiTestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Registration and Login')),
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

                    _registrationFormBox(
                      title: "Register",
                      buttonText: "Register",
                      // onPressed: () {},
                      context: context,
                    ),

                    const SizedBox(height: 25),

                    _loginFormBox(
                      title: "Log In",
                      buttonText: "Log In",
                      onPressed: () {},
                    ),

                    const SizedBox(height: 30),

                    _editUserFormBox(),

                    const SizedBox(height: 60),

                    // if (debug == true) ...[
                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.pushNamed(context, Routes.apiTest);
                    //   },
                    //   child: const Text('Test API'),
                    // ),

                    // const SizedBox(height: 60),
                    // ],
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
  Widget _registrationFormBox({
    required String title,
    required String buttonText,
    // required VoidCallback onPressed,
    required BuildContext context,
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

          const SizedBox(height: 10),

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
              onPressed: () async {
                // Registration logic here
                if (usernameController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  // Show error message if username or password is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill in both username and password',
                      ),
                    ),
                  );
                  return;
                }

                // Proceed with registration (e.g., call API)
                String username = usernameController.text.trim();
                String password = passwordController.text.trim();
                int startingCoins = 0;

                User newUser = User(
                  username,
                  password,
                  [],
                  [],
                  [],
                  startingCoins,
                );

                await addUser(newUser, context);

                setState(() {});

                //clear text fields
                usernameController.clear();
                passwordController.clear();
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginFormBox({
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

          const SizedBox(height: 10),

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
              onPressed: () async {
                // Login logic here
                String username = usernameController.text.trim();
                String password = passwordController.text.trim();

                bool success = await loginUser(username, password, context);

                if (success) {
                  // Navigate to home screen or show success message
                  //show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login successful!')),
                  );
                } else {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid username or password'),
                    ),
                  );
                }

                //clear text fields
                usernameController.clear();
                passwordController.clear();
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editUserFormBox() {
    final usernameController = TextEditingController();
    final addCaughtMascotController = TextEditingController();
    final removeCaughtMascotController = TextEditingController();
    final addUncaughtMascotController = TextEditingController();
    final removeUncaughtMascotController = TextEditingController();
    final addPiController = TextEditingController();
    final removePiController = TextEditingController();
    final coinsController = TextEditingController();

    String title = "Edit User";
    String buttonText = "Update User";

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

          const SizedBox(height: 10),

          TextField(
            controller: addCaughtMascotController,
            decoration: const InputDecoration(
              labelText: 'add a caught mascot (mascotId)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: removeCaughtMascotController,
            decoration: const InputDecoration(
              labelText: 'remove a caught mascot (mascotId)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: addUncaughtMascotController,
            decoration: const InputDecoration(
              labelText: 'add an uncaught mascot (mascotId)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: removeUncaughtMascotController,
            decoration: const InputDecoration(
              labelText: 'remove an uncaught mascot (mascotId)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: addPiController,
            decoration: const InputDecoration(
              labelText: 'add a visited Pi (piId)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: removePiController,
            decoration: const InputDecoration(
              labelText: 'remove a visited Pi (piId)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: coinsController,
            decoration: const InputDecoration(
              labelText: 'add coins (int)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: () async {
                // Login logic here
                String username = usernameController.text.trim();
                int addCaughtMascotId =
                    int.tryParse(addCaughtMascotController.text.trim()) ?? -1;
                int removeCaughtMascotId =
                    int.tryParse(removeCaughtMascotController.text.trim()) ??
                    -1;
                int addUncaughtMascotId =
                    int.tryParse(addUncaughtMascotController.text.trim()) ?? -1;
                int removeUncaughtMascotId =
                    int.tryParse(removeUncaughtMascotController.text.trim()) ??
                    -1;
                int addVisitedPiId =
                    int.tryParse(addPiController.text.trim()) ?? -1;
                int removeVisitedPiId =
                    int.tryParse(removePiController.text.trim()) ?? -1;
                String coinsToAddStr = coinsController.text.trim();
                int coinsToAdd = int.tryParse(coinsToAddStr) ?? 0;

                if (username.isEmpty) {
                  // Show error message if username is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a username')),
                  );
                  return;
                }

                if (addCaughtMascotId != -1) {
                  try {
                    await updateCaughtMascot(
                      username: username,
                      mascotId: addCaughtMascotId,
                      addOrRemove: true,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mascot added successfully!'),
                      ),
                    );
                  } catch (e) {
                    print('exception thrown: \n$e');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                if (removeCaughtMascotId != -1) {
                  try {
                    await updateCaughtMascot(
                      username: username,
                      mascotId: removeCaughtMascotId,
                      addOrRemove: false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mascot removed successfully!'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                if (addUncaughtMascotId != -1) {
                  try {
                    await updateUncaughtMascot(
                      username: username,
                      mascotId: addUncaughtMascotId,
                      addOrRemove: true,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mascot added successfully!'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                if (removeUncaughtMascotId != -1) {
                  try {
                    await updateUncaughtMascot(
                      username: username,
                      mascotId: removeUncaughtMascotId,
                      addOrRemove: false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mascot removed successfully!'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                if (addVisitedPiId != -1) {
                  try {
                    await updateVisitedPi(
                      username: username,
                      piId: addVisitedPiId,
                      addOrRemove: true,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pi added successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                if (removeVisitedPiId != -1) {
                  try {
                    await updateVisitedPi(
                      username: username,
                      piId: removeVisitedPiId,
                      addOrRemove: false,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pi removed successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                if (coinsToAdd != 0) {
                  try {
                    await updateUserCoins(
                      username: username,
                      coinsToAdd: coinsToAdd,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coins updated successfully!'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }

                //clear text fields
                // usernameController.clear();
                addCaughtMascotController.clear();
                removeCaughtMascotController.clear();
                addUncaughtMascotController.clear();
                removeUncaughtMascotController.clear();
                addPiController.clear();
                removePiController.clear();
                coinsController.clear();
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}
