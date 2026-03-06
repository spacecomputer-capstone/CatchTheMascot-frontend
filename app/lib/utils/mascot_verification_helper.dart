import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MascotVerificationHelper {
  MascotVerificationHelper({required this.widgetPiId});

  final int widgetPiId;

  static const String _jwtApiBase = "https://jwt-verification-sk0m.onrender.com";
  static const String _legacyApiBase = "https://spacescrypt-api.onrender.com";
  static const String _jwtUserId = "user1";
  static const Duration _bridgeProbeTimeout = Duration(milliseconds: 3000);
  static const Duration _jwtBackendTimeout = Duration(seconds: 3);
  static const List<String> _defaultBridgeCandidates = [
    "http://127.0.0.1:8080",
    "http://10.0.2.2:8080",
    "http://localhost:8080",
    "http://raspberrypi.local:8080",
    "http://pi.local:8080",
  ];
  static const String _jwtUserSeedHex =
      "3ef871ad732fc316c2dcd8baef06a49d4097de4e98ea746d9a31c605412b8105";

  static final Guid _serviceUuid =
      Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a1");
  static final Guid _idCharUuid =
      Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a2");
  static final Guid _signNonceUuid =
      Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a3");
  static final Guid _signRespUuid =
      Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a4");

  Future<bool> runJwtPrimaryFlow() async {
    try {
      final preferredPiId = await _getStoredPiJwtId();
      final resolved = await _resolveBridgeFromBackend(preferredPiId);
      final resolvedPiId = (resolved?["pi_id"] as String?) ?? preferredPiId;
      final packet = await _fetchPiSignedChallenge(
        resolvedPiId,
        resolvedBridge: resolved?["bridge_url"] as String?,
      );
      final piId = packet["pi_id"] as String? ?? resolvedPiId;
      final challenge = packet["challenge"] as String? ?? "";
      final piSignature = packet["pi_signature"] as String? ?? "";

      if (challenge.isEmpty || piSignature.isEmpty) {
        throw Exception("Pi returned empty challenge/signature");
      }

      await _storePiJwtId(piId);

      final userSignature = await _signChallengeWithAppKey(challenge);
      return _postJwtExchange(
        piId: piId,
        challenge: challenge,
        piSignature: piSignature,
        userSignature: userSignature,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> runLegacyFallbackFlow(Duration budget) async {
    BluetoothDevice? device;
    StreamSubscription<List<int>>? notifSub;
    final deadline = DateTime.now().add(budget);

    Duration remaining() {
      final left = deadline.difference(DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }

    try {
      final nonceHex = await _fetchNonceHex().timeout(
        remaining(),
        onTimeout: () => throw Exception("Legacy nonce timed out"),
      );
      final scanBudget = remaining();
      if (scanBudget == Duration.zero) return false;

      device = await _scanForBeacon(timeout: scanBudget);

      final connectBudget = remaining();
      if (connectBudget == Duration.zero) return false;
      await device.connect(timeout: connectBudget, autoConnect: false);

      final services = await device.discoverServices().timeout(
        remaining(),
        onTimeout: () => throw Exception("Service discovery timed out"),
      );
      final svc = services.firstWhere((s) => s.uuid == _serviceUuid);

      final idChar = svc.characteristics.firstWhere((c) => c.uuid == _idCharUuid);
      final signNonceChar = svc.characteristics.firstWhere(
        (c) => c.uuid == _signNonceUuid,
      );
      final signRespChar = svc.characteristics.firstWhere(
        (c) => c.uuid == _signRespUuid,
      );

      final idBytes = await idChar.read().timeout(
        remaining(),
        onTimeout: () => throw Exception("Beacon read timed out"),
      );
      final beaconIdHex = _bytesToHex(idBytes).toLowerCase();

      await signRespChar.setNotifyValue(true).timeout(
        remaining(),
        onTimeout: () => throw Exception("Notification setup timed out"),
      );

      final completer = Completer<Uint8List>();
      notifSub = signRespChar.onValueReceived.listen((value) {
        final raw = Uint8List.fromList(value);
        if (raw.length == 72 && !completer.isCompleted) {
          completer.complete(raw);
        }
      });

      final nonceBytes = _hexToBytes(nonceHex);
      await signNonceChar.write(nonceBytes, withoutResponse: true).timeout(
        remaining(),
        onTimeout: () => throw Exception("Nonce write timed out"),
      );

      final responseBudget = remaining();
      if (responseBudget == Duration.zero) return false;
      final raw = await completer.future.timeout(
        responseBudget,
        onTimeout: () => throw Exception("Legacy verification timed out"),
      );

      final tsBytes = raw.sublist(0, 8);
      final sigBytes = raw.sublist(8);
      final tsMs = _be64ToMs(tsBytes);
      final sigHex = _bytesToHex(sigBytes).toLowerCase();

      return _postVerifyLegacy(
        beaconIdHex: beaconIdHex,
        nonceHex: nonceHex,
        tsMs: tsMs.toString(),
        sigHex: sigHex,
      ).timeout(
        remaining(),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    } finally {
      try {
        await notifSub?.cancel();
      } catch (_) {}
      try {
        if (device != null) await device.disconnect();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _fetchPiSignedChallenge(
    String preferredPiId, {
    String? resolvedBridge,
  }) async {
    final candidates = await _bridgeCandidates(
      preferredPiId,
      resolvedBridge: resolvedBridge,
    );

    for (final base in candidates) {
      try {
        final uriWithPi = Uri.parse(
          "$base/challenge"
          "?user_id=$_jwtUserId&pi_id=${Uri.encodeQueryComponent(preferredPiId)}",
        );
        http.Response response =
            await http.get(uriWithPi).timeout(_bridgeProbeTimeout);

        if (response.statusCode != 200) {
          final uriNoPi = Uri.parse("$base/challenge?user_id=$_jwtUserId");
          response = await http.get(uriNoPi).timeout(_bridgeProbeTimeout);
        }

        if (response.statusCode != 200) {
          continue;
        }

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final challenge = payload["challenge"] as String? ?? "";
        final piSig = payload["pi_signature"] as String? ?? "";
        if (challenge.isEmpty || piSig.isEmpty) {
          continue;
        }
        await _storeBridgeBase(base);
        return payload;
      } catch (_) {
        continue;
      }
    }

    throw Exception("No Pi bridge reachable");
  }

  Future<Map<String, dynamic>?> _resolveBridgeFromBackend(String piId) async {
    try {
      final withPi = Uri.parse(
        "$_jwtApiBase/presence/pi/resolve?pi_id=${Uri.encodeQueryComponent(piId)}",
      );
      final r1 = await http.get(withPi).timeout(_bridgeProbeTimeout);
      if (r1.statusCode == 200) {
        final payload = jsonDecode(r1.body) as Map<String, dynamic>;
        final bridge = payload["bridge_url"] as String?;
        if (bridge != null && bridge.isNotEmpty) return payload;
      }

      final withoutPi = Uri.parse("$_jwtApiBase/presence/pi/resolve");
      final r2 = await http.get(withoutPi).timeout(_bridgeProbeTimeout);
      if (r2.statusCode != 200) return null;

      final payload = jsonDecode(r2.body) as Map<String, dynamic>;
      final bridge = payload["bridge_url"] as String?;
      if (bridge == null || bridge.isEmpty) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  Future<String> _signChallengeWithAppKey(String challenge) async {
    final algorithm = Ed25519();
    final seed = _hexToBytes(_jwtUserSeedHex);
    final keyPair = await algorithm.newKeyPairFromSeed(seed);
    final sig = await algorithm.sign(utf8.encode(challenge), keyPair: keyPair);
    return _bytesToHex(sig.bytes).toLowerCase();
  }

  Future<bool> _postJwtExchange({
    required String piId,
    required String challenge,
    required String piSignature,
    required String userSignature,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_jwtApiBase/presence/exchange"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "user_id": _jwtUserId,
              "pi_id": piId,
              "challenge": challenge,
              "pi_signature": piSignature,
              "user_signature": userSignature,
            }),
          )
          .timeout(_jwtBackendTimeout);

      if (response.statusCode != 200) {
        if (response.statusCode == 401 &&
            response.body.contains("Invalid Pi signature")) {
          await _clearPiBridgeCache();
        }
        throw Exception("JWT exchange failed (${response.statusCode})");
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final jwt = (payload["presence_jwt"] as String?) ?? "";
      final sid = (payload["sid"] as String?) ?? "";
      if (jwt.isEmpty) {
        throw Exception("JWT missing in response");
      }
      await _storePresenceJwt(jwt, sid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _storePresenceJwt(String jwt, String sid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("presence_jwt", jwt);
    await prefs.setString("presence_sid", sid);
  }

  String _piJwtPrefKey() => "jwt_pi_id_for_widget_pi_$widgetPiId";

  String _piBridgePrefKey() => "jwt_pi_bridge_for_widget_pi_$widgetPiId";

  String _defaultPiJwtId() => "pi$widgetPiId";

  Future<String> _getStoredPiJwtId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_piJwtPrefKey()) ?? _defaultPiJwtId();
  }

  Future<void> _storePiJwtId(String piId) async {
    if (piId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_piJwtPrefKey(), piId);
  }

  Future<List<String>> _bridgeCandidates(
    String preferredPiId, {
    String? resolvedBridge,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_piBridgePrefKey());
    final merged = <String>[
      if (resolvedBridge != null && resolvedBridge.isNotEmpty) resolvedBridge,
      if (stored != null && stored.isNotEmpty) stored,
      "http://$preferredPiId.local:8080",
      ..._defaultBridgeCandidates,
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final base in merged) {
      if (seen.add(base)) out.add(base);
    }
    return out;
  }

  Future<void> _storeBridgeBase(String base) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_piBridgePrefKey(), base);
  }

  Future<void> _clearPiBridgeCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_piBridgePrefKey());
    await prefs.remove(_piJwtPrefKey());
  }

  Future<String> _fetchNonceHex() async {
    final response = await http.get(Uri.parse("$_legacyApiBase/api/nonce"));
    if (response.statusCode != 200) throw Exception("nonce failed");
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload["nonceHex"] as String).toLowerCase();
  }

  Future<bool> _postVerifyLegacy({
    required String beaconIdHex,
    required String nonceHex,
    required String tsMs,
    required String sigHex,
  }) async {
    final response = await http.post(
      Uri.parse("$_legacyApiBase/api/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "beaconIdHex": beaconIdHex,
        "nonceHex": nonceHex,
        "tsMs": tsMs,
        "sigHex": sigHex,
      }),
    );
    return jsonDecode(response.body)["ok"] == true;
  }

  Future<BluetoothDevice> _scanForBeacon({required Duration timeout}) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    BluetoothDevice? found;
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.advertisementData.serviceUuids.contains(_serviceUuid)) {
          found = result.device;
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [_serviceUuid],
        timeout: timeout,
      );
      await Future.delayed(timeout);
      await FlutterBluePlus.stopScan();
      if (found == null) throw Exception("No beacon found");
      return found!;
    } finally {
      await sub.cancel();
    }
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, "0")).join();

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static int _be64ToMs(Uint8List bytes) {
    BigInt value = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      value = (value << 8) | BigInt.from(bytes[i]);
    }
    return value.toInt();
  }
}
