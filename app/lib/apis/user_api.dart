import 'package:app/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';

import 'package:app/screens/helpers.dart';

// REGISTER + RETURN USER
Future<User?> addUserAndReturnUser(
  String username,
  String password,
  BuildContext context,
) async {
  try {
    final user = User(
      username,
      password,
      [],
      [],
      [],
      startingCoins,
      0,
      DateTime.now(),
    );
    await addUser(user, context);
    return user;
  } catch (e) {
    return null;
  }
}

// LOGIN + RETURN USER
Future<User?> loginUserAndReturnUser(
  String username,
  String password,
  BuildContext context,
) async {
  final success = await loginUser(username, password, context);
  if (!success) return null;

  // Fetch full user profile after successful login
  return await fetchUserByUsername(username);
}

// add user
Future<User> addUser(User user, BuildContext context) async {
  if (await checkUserExists(user.username)) {
    //show error message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${user.username} already exists!')),
      );
    }
    throw Exception('User ${user.username} already exists');
  }

  String docName = user.username;

  try {
    var data = User.toMap(user);

    await _writeUserViaRestApi(docName, data);

    //show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${user.username} added successfully!')),
      );
    }
  } catch (e) {
    //show error message
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding user: $e')));
    }
  }

  return user;
}

//check if user exists
Future<bool> checkUserExists(String username) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final url =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

  // Get the API key from Firebase config
  final apiKey = FirebaseFirestore.instance.app.options.apiKey;

  final response = await http
      .get(
        Uri.parse('$url?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
      )
      .timeout(const Duration(seconds: 15));

  if (response.statusCode == 200) {
    return true; // User exists
  } else if (response.statusCode == 404) {
    return false; // User does not exist
  } else {
    throw Exception(
      'Error checking user existence: ${response.statusCode} ${response.body}',
    );
  }
}

//check that username and password match
Future<bool> loginUser(
  String username,
  String password,
  BuildContext context,
) async {
  try {
    if (username.isEmpty || password.isEmpty) {
      throw Exception('Username and password cannot be empty');
    }
    User? user = await fetchUserByUsername(username);
    if (user != null && user.password == password) {
      return true; //login successful
    } else {
      return false; //login failed
    }
  } catch (e) {
    // Show error message
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error during login: $e')));
    return false;
  }
}

// fetch user by username
Future<User?> fetchUserByUsername(String username) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final url =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

  // Get the API key from Firebase config
  final apiKey = FirebaseFirestore.instance.app.options.apiKey;

  final response = await http
      .get(
        Uri.parse('$url?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
      )
      .timeout(const Duration(seconds: 15));

  if (response.statusCode == 200) {
    final userData = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = userData['fields'] as Map<String, dynamic>;

    return User(
      _getStringValue(fields, 'username', ''),
      _getStringValue(fields, 'password', ''),
      List<int>.from(
        (fields['caughtMascots']?['arrayValue']?['values'] ?? []).map(
          (item) => int.parse(item['integerValue']),
        ),
      ),
      List<int>.from(
        (fields['uncaughtMascots']?['arrayValue']?['values'] ?? []).map(
          (item) => int.parse(item['integerValue']),
        ),
      ),
      List<int>.from(
        (fields['visitedPis']?['arrayValue']?['values'] ?? []).map(
          (item) => int.parse(item['integerValue']),
        ),
      ),
      _getIntValue(fields, 'coins', 0),
      _getIntValue(fields, 'lastPiVisited', 0),
      DateTime.parse(
        _getStringValue(
          fields,
          'lastCheckInDate',
          DateTime.now().toIso8601String(),
        ),
      ),
    );
  } else if (response.statusCode == 404) {
    return null; // User not found
  } else {
    throw Exception(
      'Error fetching user: ${response.statusCode} ${response.body}',
    );
  }
}

//update user (used for updating coins, caught/uncaught mascots, visited pis, last check-in date, etc.)
Future<void> updateUser(User user, BuildContext context) async {
  try {
    String docName = user.username;
    var data = User.toMap(user);
    // print('Updating user with data: $data');
    await _writeUserViaRestApi(docName, data);
  } catch (e) {
    //show error message
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating user: $e')));
    }
  }
}

//get the caught mascots of a user
Future<List<int>> getCaughtMascotsOfUser(String username) async {
  final user = await fetchUserByUsername(username);
  if (user != null) {
    return user.caughtMascots;
  } else {
    throw Exception('User $username not found');
  }
}

// helpter functions ---------------------------------
Future<void> _writeUserViaRestApi(
  String docId,
  Map<String, dynamic> data,
) async {
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final url =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$docId';

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
  if (value is List) {
    return {
      'arrayValue': {
        'values':
            value.map((item) => _dartValueToFirestoreValue(item)).toList(),
      },
    };
  } else if (value is String) {
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
    return {'stringValue': value.toString()};
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
