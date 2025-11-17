//screen to test apis

import 'package:app/models/mascot.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';

class ApiTestScreen extends StatefulWidget {
  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  //   ApiTestScreen({super.key});

  var nameController = TextEditingController();
  var mascIDController = TextEditingController();
  var rarityController = TextEditingController();
  var piIDController = TextEditingController();
  var respawnTimeController = TextEditingController();

  final List<Mascot> mascots = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Test')),

      body:
          mascots.isEmpty
              ? const Center(child: Text('No mascots available.'))
              : ListView.builder(
                itemCount: mascots.length,
                itemBuilder: (context, index) {
                  final mascot = mascots[index];
                  return ListTile(
                    title: Text(
                      'Name: ${mascot.mascotName}, ID: ${mascot.mascotId.toString()}',
                    ),
                    subtitle: Text(
                      'Location: ${mascot.piId}, Rarity: ${mascot.rarity}',
                    ),
                    trailing: Text('Respawn: ${mascot.respawnTime} min'),
                  );
                },
              ),

      //button to add a mascot
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Add Mascot'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,

                    //input text fields for mascot details
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Mascot Name',
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: mascIDController,
                        decoration: const InputDecoration(
                          hintText: 'Mascot ID',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: rarityController,
                        decoration: const InputDecoration(hintText: 'Rarity'),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: piIDController,
                        decoration: const InputDecoration(hintText: 'PI ID'),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: respawnTimeController,
                        decoration: const InputDecoration(
                          hintText: 'Respawn Time (min)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),

                  //buttons to cancel or add mascot
                  actions: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        String name = nameController.text.trim();
                        int mascID = int.parse(mascIDController.text.trim());
                        double rarity = double.parse(
                          rarityController.text.trim(),
                        );
                        int piID = int.parse(piIDController.text.trim());
                        int respawnTime = int.parse(
                          respawnTimeController.text.trim(),
                        );

                        // print("trying to add mascot: $name, $mascID, $rarity, $piID, $respawnTime");

                        Mascot newMascot = Mascot(
                          name,
                          mascID,
                          rarity,
                          piID,
                          respawnTime,
                        );

                        //add mascot to firestore
                        await addMascot(newMascot, context);
                        print("after mascot added to firestore");

                        //when a property of a stateless widget changes, we need to call
                        //setState to rebuild the widget with the new data
                        setState(() {});

                        //clear text fields
                        // nameController.clear();
                        // mascIDController.clear();
                        // rarityController.clear();
                        // piIDController.clear();
                        // respawnTimeController.clear();

                        Navigator.pop(context);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  addMascot(Mascot mascot, BuildContext context) async {
    print("adding mascot to firestore---------------");

    //debug
    print("Checking Firebase initialization...");
    // print("app: ${Firebase.app().name}");

    print("testing quick Firestore read for collection mascots...");
    try {
      print(
        'Firebase projectId: ${FirebaseFirestore.instance.app.options.projectId}',
      );
      var snapshot =
          await FirebaseFirestore.instance.collection('mascots').limit(1).get();
      print('Firestore works: ${snapshot.docs.length} docs');
    } catch (e) {
      print('Firestore failed: $e');
    }

    //doesn't work if the collection doesn't exist
    // print("Testing quick Firestore read for collection test...");
    // try {
    //   await FirebaseFirestore.instance
    //       .collection('test')
    //       .limit(1)
    //       .get()
    //       .timeout(Duration(seconds: 10));
    //   print("Firestore READ works");
    // } catch (e) {
    //   print("Firestore READ FAILED: $e");
    // }
    //----------------

    print("");
    print(
      "mascot to add: ${mascot.mascotName}, ${mascot.mascotId}---------------",
    );
    String docName = "mascot_${mascot.mascotName}_${mascot.mascotId}";
    print("docName: $docName");
    try {
      print("before mascot add await");
      //await db.collection('mascots').doc(docName).set(Mascot.toMap(mascot));
      //   print("got collection reference");
      var data = Mascot.toMap(mascot);
      print("map = $data");

      // Use REST API instead of SDK write to bypass web SDK hang issue
      print("Using REST API to write document...");
      await _writeViaRestApi(docName, data);
      print("after REST API write");

      // use sdk write (may hang on web)
      // print("Using SDK to write document...");
      // await FirebaseFirestore.instance
      //     .collection('mascots')
      //     .doc(docName)
      //     .set(data);

      print("after mascot add await");
      if (!mounted) return;
      print("try before snackbar");
      print("mascot added successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mascot added successfully')),
      );
      print("mascot added successfully");
    } catch (e, s) {
      if (!mounted) return;
      print("failed to add mascot: $e");
      if (e is FirebaseException) {
        print('FirebaseException code=${e.code}, message=${e.message}');
      }
      print(s);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add mascot: $e')));
      print("failed to add mascot: $e");
    }

    print("after add attempt -------------------");
    print("");
  }

  // REST API helper to bypass web SDK write hang
  Future<void> _writeViaRestApi(String docId, Map<String, dynamic> data) async {
    final projectId = FirebaseFirestore.instance.app.options.projectId;
    final url =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/mascots/$docId';

    // Get the API key from Firebase config
    final apiKey = FirebaseFirestore.instance.app.options.apiKey;

    // Prepare the request body in Firestore REST format
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _dartValueToFirestoreValue(value);
    });

    final body = jsonEncode({'fields': fields});

    print('REST API URL: $url?key=$apiKey');

    final response = await http
        .patch(
          Uri.parse('$url?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    print('REST API response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception(
        'REST API write failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Convert Dart values to Firestore REST format
  Map<String, dynamic> _dartValueToFirestoreValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    } else if (value is int) {
      return {'integerValue': value.toString()};
    } else if (value is double) {
      return {'doubleValue': value};
    } else if (value is bool) {
      return {'booleanValue': value};
    } else if (value is DateTime) {
      return {'timestampValue': value.toIso8601String()};
    } else if (value == null) {
      return {'nullValue': 'NULL_VALUE'};
    } else {
      // Default: treat as string
      return {'stringValue': value.toString()};
    }
  }
}
