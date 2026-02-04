import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SimplePresenceClient {
  final String apiBase; // e.g. https://spacescrypt-api.onrender.com or http://172.20.10.7:5001
  final Guid serviceUuid;
  final Guid idCharUuid;
  final Guid signNonceUuid;
  final Guid signRespUuid;

  /// Live logs (like your old PoP client)
  final ValueNotifier<List<String>> logList = ValueNotifier<List<String>>([]);

  SimplePresenceClient({
    required this.apiBase,
    required this.serviceUuid,
    required this.idCharUuid,
    required this.signNonceUuid,
    required this.signRespUuid,
  });

  void _log(String s) {
    logList.value = [...logList.value, s];
  }

  // ---------- Helpers ----------
  static String bytesToHex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, "0")).join();

  static Uint8List hexToBytes(String hex) {
    final h = hex.toLowerCase();
    if (!RegExp(r'^[0-9a-f]*$').hasMatch(h) || h.length % 2 != 0) {
      throw ArgumentError("bad hex");
    }
    final out = Uint8List(h.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static int be64ToMs(Uint8List u8) {
    if (u8.length != 8) throw ArgumentError("ts must be 8 bytes");
    BigInt n = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      n = (n << 8) | BigInt.from(u8[i]);
    }
    // safe for ms timestamps
    return n.toInt();
  }

  // ---------- Main protocol ----------
  Future<Map<String, dynamic>> runOnce({
    Duration scanTimeout = const Duration(seconds: 12),
    Duration notifyTimeout = const Duration(seconds: 6),
  }) async {
    // 1) Get nonce from backend
    _log("GET $apiBase/api/nonce");
    final nonceRes = await http.get(Uri.parse("$apiBase/api/nonce"));
    if (nonceRes.statusCode != 200) {
      throw Exception("nonce failed: ${nonceRes.statusCode} ${nonceRes.body}");
    }
    final nonceJson = jsonDecode(nonceRes.body) as Map<String, dynamic>;
    final nonceHex = (nonceJson["nonceHex"] as String).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(nonceHex)) {
      throw Exception("bad nonceHex from backend: $nonceHex");
    }
    _log("nonceHex = $nonceHex");

    // 2) Scan for the beacon advertising the service UUID
    _log("Scanning for BLE service $serviceUuid ...");
    final sub = FlutterBluePlus.scanResults.listen((results) {});
    await FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: scanTimeout,
    );

    final results = await FlutterBluePlus.scanResults.firstWhere(
          (list) => list.any((r) => r.advertisementData.serviceUuids.contains(serviceUuid)),
      orElse: () => [],
    );

    await FlutterBluePlus.stopScan();
    await sub.cancel();

    final match = results.firstWhere(
          (r) => r.advertisementData.serviceUuids.contains(serviceUuid),
      orElse: () => throw Exception("No beacon found advertising $serviceUuid"),
    );

    final device = match.device;
    _log("Found device: ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}");

    // 3) Connect + discover services/chars
    _log("Connecting...");
    await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);

    try {
      _log("Discovering services...");
      final services = await device.discoverServices();
      final svc = services.firstWhere(
            (s) => s.uuid == serviceUuid,
        orElse: () => throw Exception("Service not found: $serviceUuid"),
      );

      BluetoothCharacteristic idChar = svc.characteristics.firstWhere(
            (c) => c.uuid == idCharUuid,
        orElse: () => throw Exception("ID characteristic not found: $idCharUuid"),
      );

      BluetoothCharacteristic signNonceChar = svc.characteristics.firstWhere(
            (c) => c.uuid == signNonceUuid,
        orElse: () => throw Exception("SIGN_NONCE characteristic not found: $signNonceUuid"),
      );

      BluetoothCharacteristic signRespChar = svc.characteristics.firstWhere(
            (c) => c.uuid == signRespUuid,
        orElse: () => throw Exception("SIGN_RESP characteristic not found: $signRespUuid"),
      );

      // 4) Read beaconId (8 bytes)
      _log("Reading Beacon ID...");
      final idBytes = await idChar.read();
      final beaconIdHex = bytesToHex(idBytes).toLowerCase();
      _log("beaconIdHex = $beaconIdHex");

      // 5) Subscribe to notify and wait for 72 bytes response
      _log("Subscribing to SIGN_RESP notify...");
      await signRespChar.setNotifyValue(true);

      final completer = Completer<Uint8List>();
      late final StreamSubscription<List<int>> notifSub;

      notifSub = signRespChar.onValueReceived.listen((value) {
        final raw = Uint8List.fromList(value);
        if (raw.length == 72 && !completer.isCompleted) {
          completer.complete(raw);
        }
      });

      // 6) Write nonce (16 raw bytes)
      final nonceBytes = hexToBytes(nonceHex);
      _log("Writing nonce (16B) to SIGN_NONCE...");
      await signNonceChar.write(nonceBytes, withoutResponse: true);

      _log("Waiting for 72B notify...");
      final raw = await completer.future.timeout(
        notifyTimeout,
        onTimeout: () => throw Exception("Verification timed out waiting for beacon notify"),
      );

      await notifSub.cancel();

      // Parse notify: ts(8) || sig(64)
      final tsBytes = raw.sublist(0, 8);
      final sigBytes = raw.sublist(8);
      final tsMs = be64ToMs(tsBytes);
      final sigHex = bytesToHex(sigBytes).toLowerCase();

      _log("tsMs  = $tsMs");
      _log("sigHex= ${sigHex.substring(0, 16)}... (${sigHex.length} hex)");

      // 7) POST verify
      final payload = {
        "beaconIdHex": beaconIdHex,
        "nonceHex": nonceHex,
        "tsMs": tsMs.toString(),
        "sigHex": sigHex,
      };

      _log("POST $apiBase/api/verify");
      final verifyRes = await http.post(
        Uri.parse("$apiBase/api/verify"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final verifyJson = jsonDecode(verifyRes.body) as Map<String, dynamic>;
      final ok = verifyJson["ok"] == true;

      _log("verify -> ok=$ok ${verifyJson["error"] ?? ""}");

      return {
        "ok": ok,
        "error": verifyJson["error"],
        "beaconIdHex": beaconIdHex,
        "nonceHex": nonceHex,
        "tsMs": tsMs.toString(),
        "sigHex": sigHex,
      };
    } finally {
      _log("Disconnecting...");
      await device.disconnect();
    }
  }
}
