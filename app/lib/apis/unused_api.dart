import 'package:app/models/mascot.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

//this function is unused because we have replaced it with MascotStorageService in mascot.dart
//this is a locally stored highest mascotId service - no need to fetch from firestore every time
// fetch all mascots from firestore, then get the highest mascotId and return +1
Future<int> getNextMascotId() async {
  int mascotId = 0;
  //get the highest mascotId from firestore using REST API
  print('Fetching highest mascotId from Firestore via REST API...');
  try {
    final projectId = FirebaseFirestore.instance.app.options.projectId;
    final apiKey = FirebaseFirestore.instance.app.options.apiKey;
    final url =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/mascots?orderBy=mascotId%20desc&pageSize=1&key=$apiKey';

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

    if (documents.isNotEmpty) {
      final docData = documents.first as Map<String, dynamic>;
      final fields = (docData['fields'] as Map<String, dynamic>?) ?? {};
      mascotId = _getIntValue(fields, 'mascotId', 0) + 1;
      print('Highest mascotId found: ${mascotId - 1}, new mascotId: $mascotId');
    } else {
      print('No existing mascots found, starting mascotId at 0');
    }
  } catch (e) {
    print('Failed to fetch highest mascotId: $e');
  }
  return mascotId;
}

//add or remove to caught mascots (using mascot Id)
// addOrRemove: true = add, false = remove
// Future<void> updateCaughtMascot({
//   required String username,
//   required int mascotId,
//   bool addOrRemove = true,
// }) async {
//   if (mascotId < 0) {
//     throw Exception('Invalid mascotId: $mascotId');
//   }

//   // Fetch existing user data
//   final projectId = FirebaseFirestore.instance.app.options.projectId;
//   final url =
//       'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

//   // Get the API key from Firebase config
//   final apiKey = FirebaseFirestore.instance.app.options.apiKey;

//   final getResponse = await http
//       .get(
//         Uri.parse('$url?key=$apiKey'),
//         headers: {'Content-Type': 'application/json'},
//       )
//       .timeout(const Duration(seconds: 15));

//   if (getResponse.statusCode != 200) {
//     throw Exception(
//       'Error fetching user data: ${getResponse.statusCode} ${getResponse.body}',
//     );
//   }

//   final userData = jsonDecode(getResponse.body) as Map<String, dynamic>;
//   final fields = userData['fields'] as Map<String, dynamic>;

//   // Update caughtMascots list
//   List<int> caughtMascots = List<int>.from(
//     fields['caughtMascots']?['arrayValue']?['values']?.map(
//           (item) => int.parse(item['integerValue']),
//         ) ??
//         [],
//   );

//   if (addOrRemove && !caughtMascots.contains(mascotId)) {
//     caughtMascots.add(mascotId);
//   } else if (!addOrRemove) {
//     caughtMascots.remove(mascotId);
//   }

//   // Write updated data back to Firestore
//   // Update user data while keeping other fields
//   final updatedData = {
//     'username': _getStringValue(fields, 'username', ''),
//     'password': _getStringValue(fields, 'password', ''),
//     'caughtMascots': caughtMascots,
//     'uncaughtMascots': List<int>.from(
//       (fields['uncaughtMascots']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'visitedPis': List<int>.from(
//       (fields['visitedPis']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'coins': _getIntValue(fields, 'coins', 0),
//     'lastPiVisited': _getIntValue(fields, 'lastPiVisited', 0),
//     'lastCheckInDate': _getStringValue(
//       fields,
//       'lastCheckInDate',
//       DateTime.now().toIso8601String(),
//     ),
//   };

//   await _writeUserViaRestApi(username, updatedData);
// }

// //add or remove a mascot to uncaught mascots
// // addOrRemove: true = add, false = remove
// Future<void> updateUncaughtMascot({
//   required String username,
//   required int mascotId,
//   bool addOrRemove = true,
// }) async {
//   if (mascotId < 0) {
//     throw Exception('Invalid mascotId: $mascotId');
//   }

//   // Fetch existing user data
//   final projectId = FirebaseFirestore.instance.app.options.projectId;
//   final url =
//       'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

//   // Get the API key from Firebase config
//   final apiKey = FirebaseFirestore.instance.app.options.apiKey;

//   final getResponse = await http
//       .get(
//         Uri.parse('$url?key=$apiKey'),
//         headers: {'Content-Type': 'application/json'},
//       )
//       .timeout(const Duration(seconds: 15));

//   if (getResponse.statusCode != 200) {
//     throw Exception(
//       'Error fetching user data: ${getResponse.statusCode} ${getResponse.body}',
//     );
//   }

//   final userData = jsonDecode(getResponse.body) as Map<String, dynamic>;
//   final fields = userData['fields'] as Map<String, dynamic>;

//   // Update uncaughtMascots list
//   List<int> uncaughtMascots = List<int>.from(
//     fields['uncaughtMascots']?['arrayValue']?['values']?.map(
//           (item) => int.parse(item['integerValue']),
//         ) ??
//         [],
//   ); //get current list
//   if (addOrRemove && !uncaughtMascots.contains(mascotId)) {
//     //add mascot
//     uncaughtMascots.add(mascotId);
//   } else if (!addOrRemove) {
//     //remove mascot
//     uncaughtMascots.remove(mascotId);
//   }

//   // Write updated data back to Firestore
//   final updatedData = {
//     'username': _getStringValue(fields, 'username', ''),
//     'password': _getStringValue(fields, 'password', ''),
//     'caughtMascots': List<int>.from(
//       (fields['caughtMascots']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'uncaughtMascots': uncaughtMascots,
//     'visitedPis': List<int>.from(
//       (fields['visitedPis']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'coins': _getIntValue(fields, 'coins', 0),
//     'lastPiVisited': _getIntValue(fields, 'lastPiVisited', 0),
//     'lastCheckInDate': _getStringValue(
//       fields,
//       'lastCheckInDate',
//       DateTime.now().toIso8601String(),
//     ),
//   };

//   await _writeUserViaRestApi(username, updatedData);
// }

// //add to visited pis
// // addOrRemove: true = add, false = remove
// Future<void> updateVisitedPi({
//   required String username,
//   required int piId,
//   bool addOrRemove = true,
// }) async {
//   if (piId < 0) {
//     throw Exception('Invalid mascotId: $piId');
//   }
//   // Fetch existing user data
//   final projectId = FirebaseFirestore.instance.app.options.projectId;
//   final url =
//       'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

//   // Get the API key from Firebase config
//   final apiKey = FirebaseFirestore.instance.app.options.apiKey;

//   final getResponse = await http
//       .get(
//         Uri.parse('$url?key=$apiKey'),
//         headers: {'Content-Type': 'application/json'},
//       )
//       .timeout(const Duration(seconds: 15));

//   if (getResponse.statusCode != 200) {
//     throw Exception(
//       'Error fetching user data: ${getResponse.statusCode} ${getResponse.body}',
//     );
//   }

//   final userData = jsonDecode(getResponse.body) as Map<String, dynamic>;
//   final fields = userData['fields'] as Map<String, dynamic>;

//   // Update visitedPis list
//   List<int> visitedPis = List<int>.from(
//     fields['visitedPis']?['arrayValue']?['values']?.map(
//           (item) => int.parse(item['integerValue']),
//         ) ??
//         [],
//   );
//   if (addOrRemove && !visitedPis.contains(piId)) {
//     visitedPis.add(piId);
//   } else if (!addOrRemove) {
//     visitedPis.remove(piId);
//   }

//   // Write updated data back to Firestore
//   final updatedData = {
//     'username': _getStringValue(fields, 'username', ''),
//     'password': _getStringValue(fields, 'password', ''),
//     'caughtMascots': List<int>.from(
//       (fields['caughtMascots']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'uncaughtMascots': List<int>.from(
//       (fields['uncaughtMascots']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'visitedPis': visitedPis,
//     'coins': _getIntValue(fields, 'coins', 0),
//     'lastPiVisited': _getIntValue(fields, 'lastPiVisited', 0),
//     'lastCheckInDate': _getStringValue(
//       fields,
//       'lastCheckInDate',
//       DateTime.now().toIso8601String(),
//     ),
//   };

//   await _writeUserViaRestApi(username, updatedData);
// }

// //change the number of coins a user has
// // coinsToAdd can be negative to subtract coins - but total coins cannot go below 0
// Future<void> updateUserCoins({
//   required String username,
//   required int coinsToAdd,
// }) async {
//   // Fetch existing user data
//   final projectId = FirebaseFirestore.instance.app.options.projectId;
//   final url =
//       'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

//   // Get the API key from Firebase config
//   final apiKey = FirebaseFirestore.instance.app.options.apiKey;

//   final getResponse = await http
//       .get(
//         Uri.parse('$url?key=$apiKey'),
//         headers: {'Content-Type': 'application/json'},
//       )
//       .timeout(const Duration(seconds: 15));

//   if (getResponse.statusCode != 200) {
//     throw Exception(
//       'Error fetching user data: ${getResponse.statusCode} ${getResponse.body}',
//     );
//   }

//   final userData = jsonDecode(getResponse.body) as Map<String, dynamic>;
//   final fields = userData['fields'] as Map<String, dynamic>;

//   // Update coins
//   int currentCoins = _getIntValue(fields, 'coins', 0);
//   int updatedCoins = currentCoins + coinsToAdd;

//   if (updatedCoins < 0) {
//     //return error and return without updating
//     throw Exception('Insufficient coins. Cannot have negative coins.');
//     // updatedCoins = 0; // Prevent negative coins
//   }

//   // Write updated data back to Firestore
//   final updatedData = {
//     'username': _getStringValue(fields, 'username', ''),
//     'password': _getStringValue(fields, 'password', ''),
//     'caughtMascots': List<int>.from(
//       (fields['caughtMascots']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'uncaughtMascots': List<int>.from(
//       (fields['uncaughtMascots']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'visitedPis': List<int>.from(
//       (fields['visitedPis']?['arrayValue']?['values'] ?? []).map(
//         (item) => int.parse(item['integerValue']),
//       ),
//     ),
//     'coins': updatedCoins,
//     'lastPiVisited': _getIntValue(fields, 'lastPiVisited', 0),
//     'lastCheckInDate': _getStringValue(
//       fields,
//       'lastCheckInDate',
//       DateTime.now().toIso8601String(),
//     ),
//   };

//   await _writeUserViaRestApi(username, updatedData);
// }
