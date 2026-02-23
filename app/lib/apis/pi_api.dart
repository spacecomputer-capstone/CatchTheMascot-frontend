//TODO: hasn't been tested yet

import 'package:app/models/pi.dart';
import 'package:app/models/mascot.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
// import 'package:app/apis/api_helpers.dart';

//get pi object by pi id
Future<Pi?> getPi(int piId, [BuildContext? context]) async {
  try {
    final projectId = FirebaseFirestore.instance.app.options.projectId;
    final apiKey = FirebaseFirestore.instance.app.options.apiKey;
    final url =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/pis/$piId?key=$apiKey';

    final response = await http
        .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));

    // If mascot not found, show a snackbar and return null.
    if (response.statusCode == 404) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pi with ID $piId not found')));
      }
      print('Pi with ID $piId not found');
      return null;
    }

    // print('REST API response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception(
        'REST API read failed: ${response.statusCode} ${response.body}',
      );
    }
    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = (jsonResponse['fields'] as Map<String, dynamic>?) ?? {};
    final pi = Pi(
      _getIntValue(fields, 'id', 0),
      _getStringValue(fields, 'name', 'Unknown Pi'),
      List<int>.from(
        (fields['mascots']?['arrayValue']?['values'] ?? []).map(
          (item) => int.parse(item['integerValue']),
        ),
      ),
      _getDoubleValue(fields, 'latitude', 0.0),
      _getDoubleValue(fields, 'longitude', 0.0),
    );
    return pi;
  } catch (e) {
    print('Failed to fetch pi: $e');
    return null;
  }
}

//helpers to convert REST API fields to Dart types ----------------------
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
  if (field == null) return defaultValue;

  // If stored as a double
  final doubleVal = field['doubleValue'];
  if (doubleVal != null) {
    if (doubleVal is num) return doubleVal.toDouble();
    if (doubleVal is String) {
      final parsed = double.tryParse(doubleVal);
      if (parsed != null) return parsed;
    }
  }

  // If stored as an integer (Firestore returns integerValue as a string)
  final intStr = field['integerValue'] as String?;
  if (intStr != null) {
    final parsedInt = int.tryParse(intStr);
    if (parsedInt != null) return parsedInt.toDouble();
    final parsedDouble = double.tryParse(intStr);
    if (parsedDouble != null) return parsedDouble;
  }

  return defaultValue;
}
