//screen to test apis

import 'package:flutter/material.dart';
// import '../utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

class ApiTestScreen extends StatelessWidget {
  const ApiTestScreen({super.key});

  //TODO: https://www.youtube.com/watch?v=pXH_sfXtThk

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test API Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            //location permission button
            ElevatedButton(
              onPressed: () async {
                print('Adding data to Firestore...');

                final options = Firebase.app().options;
                print('Firebase projectId: ${options.projectId}');
                print('Firebase appId: ${options.appId}');
                print('Firebase apiKey: ${options.apiKey}');
                print('Firebase collections: ${options.apiKey}');
                try {
                  print('About to add document to mascots collection');

                  // Wrap add in a timeout so we can detect hangs
                  final docRef = await FirebaseFirestore.instance
                      .collection('mascots')
                      .add({
                        'name': 'Test Mascot',
                        'location': 'Test Location',
                        'captured': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      })
                      .timeout(const Duration(seconds: 10));

                  print('Add returned, document id: ${docRef.id}');

                  // Check local cache immediately
                  try {
                    final cacheSnap = await FirebaseFirestore.instance
                        .collection('mascots')
                        .doc(docRef.id)
                        .get(const GetOptions(source: Source.cache));
                    print(
                      'Cache get: exists=${cacheSnap.exists}, data=${cacheSnap.data()}',
                    );
                  } catch (e) {
                    print('Cache get failed: $e');
                  }

                  // Try a server read (may fail if offline or rules block)
                  try {
                    final serverSnap = await FirebaseFirestore.instance
                        .collection('mascots')
                        .doc(docRef.id)
                        .get(const GetOptions(source: Source.server))
                        .timeout(const Duration(seconds: 10));
                    print(
                      'Server get: exists=${serverSnap.exists}, data=${serverSnap.data()}',
                    );
                  } catch (e) {
                    print('Server get failed or timed out: $e');
                  }

                  print('Data added successfully (local).');
                } catch (e, s) {
                  // Print full stack trace to help debugging
                  print('Add failed or timed out');
                  print('Error adding data: $e');
                  print(s);
                }
              },
              child: const Text('Add Data'),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                // The client SDK doesn't provide a cross-platform API to list all
                // top-level collections. We can, however, probe a list of
                // candidate collection names and check whether they contain
                // any documents. Note: an empty collection (no docs) won't be
                // discoverable this way.
                final candidates = [
                  'mascots',
                  'users',
                  'inventory',
                  'sessions',
                ];

                final buffer = StringBuffer();
                for (final name in candidates) {
                  try {
                    final snap =
                        await FirebaseFirestore.instance
                            .collection(name)
                            .limit(1)
                            .get();
                    final exists = snap.docs.isNotEmpty;
                    buffer.writeln(
                      '$name: ${exists ? 'has documents' : 'no documents or does not exist'}',
                    );
                  } catch (e) {
                    buffer.writeln('$name: error - $e');
                  }
                }

                final result = buffer.toString();
                // Print to console for the developer
                print('Collection probe results:\n$result');

                // Show the results in the UI (SnackBar) — long results go to console
                // Print the full results to the console for the developer
                print('Collection probe results:\n$result');
              },
              child: const Text('List Collections (probe)'),
            ),
          ],
        ),
      ),
    );
  }
}
