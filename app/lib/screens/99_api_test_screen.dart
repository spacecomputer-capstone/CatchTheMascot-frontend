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
      appBar: AppBar(
        title: const Text('API Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch Mascots',
            onPressed: () {
              getMascots();
            },
          ),
        ],
      ),

      body:
          //shows a list of added mascots in this session
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
    // print("adding mascot to firestore---------------");

    String docName =
        "mascot_${mascot.mascotName}_${mascot.mascotId}"; // print("docName: $docName");

    try {
      var data = Mascot.toMap(mascot);
      //   print("map = $data");

      // Use REST API instead of SDK write to bypass web SDK hang issue
      await _writeViaRestApi(docName, data);

      // use sdk write (hangs on web)
      //   print("Using SDK to write document...");
      //   await FirebaseFirestore.instance
      //       .collection('mascots')
      //       .doc(docName)
      //       .set(data);

      //add mascot to the local list
      mascots.add(mascot);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mascot added successfully')),
      );
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

  // Fetch all mascots from Firestore and update the list
  Future<void> getMascots() async {
    print('Fetching mascots from Firestore via REST API...');
    try {
      final projectId = FirebaseFirestore.instance.app.options.projectId;
      final apiKey = FirebaseFirestore.instance.app.options.apiKey;
      final url =
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/mascots?key=$apiKey';

      print('REST API URL: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('REST API response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
          'REST API read failed: ${response.statusCode} ${response.body}',
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final documents = (jsonResponse['documents'] as List<dynamic>?) ?? [];

      print('Fetched ${documents.length} mascots');

      setState(() {
        mascots.clear();
        for (final doc in documents) {
          try {
            final docData = doc as Map<String, dynamic>;
            final fields = (docData['fields'] as Map<String, dynamic>?) ?? {};

            // Convert REST API format back to Dart types
            final mascot = Mascot(
              _getStringValue(fields, 'mascotName', 'Unknown'),
              _getIntValue(fields, 'mascotId', 0),
              _getDoubleValue(fields, 'rarity', 0.0),
              _getIntValue(fields, 'piId', 0),
              _getIntValue(fields, 'respawnTime', 0),
            );
            mascots.add(mascot);
            print('Added mascot: ${mascot.mascotName}');
          } catch (e) {
            print('Error parsing mascot document: $e');
          }
        }
      });

      if (mascots.isEmpty) {
        print('No mascots found in Firestore');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No mascots found')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetched ${mascots.length} mascots')),
        );
      }
    } catch (e) {
      print('Failed to fetch mascots: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch mascots: $e')));
    }
  }

  // Helper to extract string value from REST API field
  String _getStringValue(
    Map<String, dynamic> fields,
    String key,
    String defaultValue,
  ) {
    final field = fields[key] as Map<String, dynamic>?;
    return (field?['stringValue'] as String?) ?? defaultValue;
  }

  // Helper to extract int value from REST API field
  int _getIntValue(Map<String, dynamic> fields, String key, int defaultValue) {
    final field = fields[key] as Map<String, dynamic>?;
    final value = field?['integerValue'] as String?;
    return value != null ? int.parse(value) : defaultValue;
  }

  // Helper to extract double value from REST API field
  double _getDoubleValue(
    Map<String, dynamic> fields,
    String key,
    double defaultValue,
  ) {
    final field = fields[key] as Map<String, dynamic>?;
    final value = field?['doubleValue'] as num?;
    return value?.toDouble() ?? defaultValue;
  }

  //TODO: test the mascot getting functions
  // move to apis folder
  // set up the user database: getters, setters
  // write tests for everything
}
