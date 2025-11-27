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
