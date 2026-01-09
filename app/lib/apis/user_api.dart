import 'package:app/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';

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
      List<String>.from(
          (fields['caughtMascots']?['arrayValue']?['values'] ?? [])
              .map((item) => item['stringValue'])),
      List<String>.from(
          (fields['uncaughtMascots']?['arrayValue']?['values'] ?? [])
              .map((item) => item['stringValue'])),
      List<int>.from(
          (fields['visitedPis']?['arrayValue']?['values'] ?? [])
              .map((item) => int.parse(item['integerValue']))),
      _getIntValue(fields, 'coins', 0),
    );
  } else if (response.statusCode == 404) {
    return null; // User not found
  } else {
    throw Exception(
      'Error fetching user: ${response.statusCode} ${response.body}',
    );
  }
}

//add to caught mascots
Future<void> addCaughtMascot(
  String username,
  String mascotId,
) async {
  // Fetch existing user data
  final projectId = FirebaseFirestore.instance.app.options.projectId;
  final url =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/mascot-database/documents/users/$username';

  // Get the API key from Firebase config
  final apiKey = FirebaseFirestore.instance.app.options.apiKey;

  final getResponse = await http
      .get(
        Uri.parse('$url?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
      )
      .timeout(const Duration(seconds: 15));

  if (getResponse.statusCode != 200) {
    throw Exception(
      'Error fetching user data: ${getResponse.statusCode} ${getResponse.body}',
    );
  }

  final userData = jsonDecode(getResponse.body) as Map<String, dynamic>;
  final fields = userData['fields'] as Map<String, dynamic>;

  // Update caughtMascots list
  List<String> caughtMascots =
      List<String>.from(fields['caughtMascots']?['arrayValue']?['values']
              ?.map((item) => item['stringValue']) ??
          []);
  if (!caughtMascots.contains(mascotId)) {
    caughtMascots.add(mascotId);
  }

  // Write updated data back to Firestore
  await _writeUserViaRestApi(
    username,
    {
      'caughtMascots': caughtMascots,
    },
  );
}


//add to uncaught mascots
// Future<void> addUncaughtMascot(
//   String username,
//   String mascotId,
// ) async {
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
//   List<String> uncaughtMascots =
//       List<String>.from(fields['uncaughtMascots']?['arrayValue']?['values']
//               ?.map((item) => item['stringValue']) ??
//           []);
//   if (!uncaughtMascots.contains(mascotId)) {
//     uncaughtMascots.add(mascotId);
//   }

//   // Write updated data back to Firestore
//   await _writeUserViaRestApi(
//     username,
//     {
//       'uncaughtMascots': uncaughtMascots,
//     },
//   );
// }

// //remove mascot from uncaught mascots
// Future<void> removeUncaughtMascot(
//   String username,
//   String mascotId,
// ) async {
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
//   List<String> uncaughtMascots =
//       List<String>.from(fields['uncaughtMascots']?['arrayValue']?['values']
//               ?.map((item) => item['stringValue']) ??
//           []);
//   uncaughtMascots.remove(mascotId);

//   // Write updated data back to Firestore
//   await _writeUserViaRestApi(
//     username,
//     {
//       'uncaughtMascots': uncaughtMascots,
//     },
//   );
// }

// //add to visited pis
// Future<void> addVisitedPi(
//   String username,
//   int piId,
// ) async {
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
//   List<int> visitedPis =
//       List<int>.from(fields['visitedPis']?['arrayValue']?['values']
//               ?.map((item) => int.parse(item['integerValue'])) ??
//           []);
//   if (!visitedPis.contains(piId)) {
//     visitedPis.add(piId);
//   }

//   // Write updated data back to Firestore
//   await _writeUserViaRestApi(
//     username,
//     {
//       'visitedPis': visitedPis,
//     },
//   );
// }

// //change number of coins
// Future<void> updateUserCoins(
//   String username,
//   int newCoinAmount,
// ) async {
//   await _writeUserViaRestApi(
//     username,
//     {
//       'coins': newCoinAmount,
//     },
//   );
// }

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
  //TODO: if value is an array, return as arrayValue
  // if (value is List) {
  //   return {
  //     'arrayValue': {
  //       'values': value.map((item) => _dartValueToFirestoreValue(item)).toList(),
  //     },
  //   };
  // }
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
