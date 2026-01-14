import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RngService {
  // Base URL is defined in SpaceScrypt/frontend/src/App.tsx and SpaceScrypt/api/src/index.ts
  // Default port is 8787.
  static String get _baseUrl {
    // For Android Emulator, use 10.0.2.2 to access the host's localhost.
    // For iOS Simulator, 'localhost' works (maps to host).
    // For Linux/Desktop, 'localhost' works.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://localhost:8787';
  }

  /// Fetches a 16-byte random nonce from the SpaceComputer API
  /// Returns null if the fetch fails.
  static Future<String?> getNonce() async {
    try {
      final url = Uri.parse('$_baseUrl/api/nonce');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['nonceHex'] as String?;
      } else {
        print('Failed to fetch nonce: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching nonce: $e');
      return null;
    }
  }

  /// Converts the first byte of the hex nonce to a probability (0.0 to 1.0).
  /// A higher first byte value means a higher "roll".
  /// returns a double between 0.0 and 1.0
  static double nonceToProbability(String nonceHex) {
    if (nonceHex.length < 2) return 0.0;
    
    // Take first byte (2 hex chars)
    final firstByteHex = nonceHex.substring(0, 2);
    final firstByteVal = int.tryParse(firstByteHex, radix: 16) ?? 0;
    
    // Normalize 0-255 to 0.0-1.0
    return firstByteVal / 255.0;
  }
}
