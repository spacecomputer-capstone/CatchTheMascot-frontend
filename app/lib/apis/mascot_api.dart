import 'package:app/models/mascot.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';

addMascot(Mascot mascot, BuildContext context, List<Mascot> mascots) async {
  // print("adding mascot to firestore---------------");

  String docName =
      "mascot_${mascot.mascotName}_${mascot.mascotId}"; // print("docName: $docName");

  try {
    var data = Mascot.toMap(mascot);
    //   print("map = $data");

    // Use REST API instead of SDK write to bypass web SDK hang issue
    await _writeViaRestApi(docName, data);

    //add mascot to the local list
    mascots.add(mascot);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mascot added successfully')));
  } catch (e, s) {
    print("failed to add mascot: $e");
    if (e is FirebaseException) {
      print('FirebaseException code=${e.code}, message=${e.message}');
    }
    print(s);
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

// Fetch all mascots from Firestore and update the list mascots
Future<void> getMascots(List<Mascot> mascots) async {
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
            _getIntValue(fields, 'coins', 0),
          );
          mascots.add(mascot);
          print('Added mascot: ${mascot.mascotName}');
        } catch (e) {
          print('Error parsing mascot document: $e');
        }
      }

  } catch (e) {
    print('Failed to fetch mascots: $e');
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
