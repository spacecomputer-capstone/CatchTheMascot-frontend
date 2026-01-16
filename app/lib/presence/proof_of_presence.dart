// lib/presence/proof_of_presence.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;

class ProofOfPresenceClient {
  ProofOfPresenceClient({
    required this.baseUrl,
    required this.userId,
    required this.piId,
    this.scanTimeout = const Duration(seconds: 10),
    this.connectTimeout = const Duration(seconds: 12),
    this.protocolTimeout = const Duration(seconds: 25),
    this.tokenChunkSize = 180,
  });

  final String baseUrl;
  final String userId;
  final String piId;

  final Duration scanTimeout;
  final Duration connectTimeout;
  final Duration protocolTimeout;
  final int tokenChunkSize;

  // ---- UUIDs (BASIC ONLY) ----
  static final Guid serviceUuid =
  Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a1");

  static final Guid idCharUuid =
  Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a2");

  static final Guid attemptTokenUuid =
  Guid("8c0b8f3e-1b7a-4e58-9b9e-6fbb4e3d2b01");

  static final Guid resultUuid =
  Guid("8c0b8f3e-1b7a-4e58-9b9e-6fbb4e3d2b02");

  // ---- Live Logs (UI + console) ----
  final ValueNotifier<List<String>> logList = ValueNotifier<List<String>>([]);

  void _log(String msg) {
    final line = "[${DateTime.now().toIso8601String()}] $msg";
    debugPrint(line);
    final cur = List<String>.from(logList.value);
    cur.add(line);
    logList.value = cur;
  }

  // ---- BLE state ----
  BluetoothDevice? _device;
  BluetoothCharacteristic? _idChar;
  BluetoothCharacteristic? _attemptTokenChar;
  BluetoothCharacteristic? _resultChar;

  StreamSubscription<List<int>>? _resultSub;

  Uint8List _resultBuf = Uint8List(0);
  Completer<Map<String, dynamic>>? _resultCompleter;

  bool _running = false;

  /// BASIC PoP:
  /// POST /presence/attempt -> BLE write attempt token -> wait RESULT notify -> GET proof
  Future<Map<String, dynamic>> run() async {
    if (_running) throw StateError("PoP already running");
    _running = true;

    _resultBuf = Uint8List(0);
    _resultCompleter = Completer<Map<String, dynamic>>();

    _log("PoP start (BASIC): baseUrl=$baseUrl user=$userId pi_id=$piId");

    try {
      _device = await _scanAndConnect();
      await _discover(_device!);

      final attempt = await _createAttempt();
      final attemptId = attempt["attempt_id"] as String?;
      final attemptToken = attempt["attempt_token"] as String?;

      if (attemptId == null || attemptToken == null) {
        throw StateError("Backend missing attempt_id/attempt_token");
      }

      _log("Attempt OK: attempt_id=$attemptId token_bytes=${utf8.encode(attemptToken).length}");

      await _subscribeResultNotify();
      await _sendAttemptToken(attemptToken);

      _log("Waiting for RESULT notify… (timeout=${protocolTimeout.inSeconds}s)");
      final result = await _resultCompleter!.future.timeout(protocolTimeout);
      _log("RESULT: ${jsonEncode(result)}");

      Map<String, dynamic>? proof;
      if (result["ok"] == true && result["proof_id"] is String) {
        final proofId = result["proof_id"] as String;
        _log("Fetching proof $proofId …");
        proof = await _fetchProof(proofId);
        _log("PROOF: ${jsonEncode(proof)}");
      }

      return {
        "attempt": attempt,
        "result": result,
        if (proof != null) "proof": proof,
      };
    } finally {
      await _cleanup();
      _running = false;
      _log("PoP finished");
    }
  }

  // ---------------- Backend ----------------

  Future<Map<String, dynamic>> _createAttempt() async {
    final uri = Uri.parse("$baseUrl/presence/attempt");
    _log("POST $uri");

    final resp = await http
        .post(
      uri,
      headers: {
        "accept": "application/json",
        "Content-Type": "application/json",
        "X-User-Id": userId,
      },
      body: jsonEncode({"pi_id": piId}),
    )
        .timeout(const Duration(seconds: 10));

    _log("Attempt status=${resp.statusCode}");
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError("Attempt failed ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchProof(String proofId) async {
    final uri = Uri.parse("$baseUrl/presence/proof/$proofId");
    _log("GET $uri");

    final resp = await http
        .get(uri, headers: {"accept": "application/json", "X-User-Id": userId})
        .timeout(const Duration(seconds: 10));

    _log("Proof status=${resp.statusCode}");
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError("Proof failed ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ---------------- BLE ----------------

  Future<BluetoothDevice> _scanAndConnect() async {
    _log("Scanning for service ${serviceUuid.str}…");

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    BluetoothDevice? found;

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        found ??= r.device;
        _log("Found device ${r.device.remoteId} name='${r.advertisementData.advName}' rssi=${r.rssi}");
        break;
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: scanTimeout,
      );

      await Future<void>.delayed(scanTimeout);
      await FlutterBluePlus.stopScan();
    } finally {
      await sub.cancel();
    }

    if (found == null) throw StateError("No PoP beacon found (scan timed out)");

    _log("Connecting to ${found!.remoteId}…");
    try {
      await found!.connect(timeout: connectTimeout, autoConnect: false);
    } catch (e) {
      if (!(found!.isConnected)) rethrow;
      _log("Already connected (continuing): $e");
    }

    _log("Connected");
    return found!;
  }

  Future<void> _discover(BluetoothDevice device) async {
    _log("Discovering services/chars…");
    final services = await device.discoverServices();

    BluetoothCharacteristic? findChar(Guid uuid) {
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid == uuid) return c;
        }
      }
      return null;
    }

    _idChar = findChar(idCharUuid);
    _attemptTokenChar = findChar(attemptTokenUuid);
    _resultChar = findChar(resultUuid);

    if (_attemptTokenChar == null || _resultChar == null) {
      throw StateError("Missing PoP characteristics (attemptToken/result)");
    }

    if (_idChar != null) {
      try {
        final v = await _idChar!.read();
        _log("Beacon ID read: '${utf8.decode(v, allowMalformed: true)}'");
      } catch (e) {
        _log("ID read failed (ok to ignore): $e");
      }
    }

    _log("Discovery complete");
  }

  Future<void> _subscribeResultNotify() async {
    _log("Subscribing to RESULT…");
    await _resultChar!.setNotifyValue(true);
    _resultSub = _resultChar!.onValueReceived.listen(_onResultChunk);
    _log("RESULT notifications active");
  }

  Future<void> _sendAttemptToken(String token) async {
    final tokenBytes = utf8.encode(token);
    final header = utf8.encode("LEN:${tokenBytes.length}\n");

    _log("Writing LEN header…");
    await _attemptTokenChar!.write(header, withoutResponse: false);

    int offset = 0;
    final total = tokenBytes.length;

    _log("Writing token chunks ($tokenChunkSize bytes)… total=$total");
    while (offset < total) {
      final end = (offset + tokenChunkSize < total) ? offset + tokenChunkSize : total;
      final chunk = tokenBytes.sublist(offset, end);

      try {
        await _attemptTokenChar!.write(chunk, withoutResponse: true);
      } catch (_) {
        await _attemptTokenChar!.write(chunk, withoutResponse: false);
      }

      offset = end;
      _log("Token progress $offset/$total");
    }

    _log("Token write complete");
  }

  void _onResultChunk(List<int> data) {
    try {
      final incoming = Uint8List.fromList(data);
      final merged = Uint8List(_resultBuf.length + incoming.length);
      merged.setAll(0, _resultBuf);
      merged.setAll(_resultBuf.length, incoming);
      _resultBuf = merged;

      if (_resultBuf.length > 64 * 1024) {
        throw StateError("RESULT buffer too large (bad framing?)");
      }

      final txt = utf8.decode(_resultBuf, allowMalformed: true);
      final parsed = jsonDecode(txt);

      if (parsed is Map<String, dynamic> &&
          _resultCompleter != null &&
          !_resultCompleter!.isCompleted) {
        _resultCompleter!.complete(parsed);
      }
    } catch (_) {
      // partial JSON; keep buffering
    }
  }

  // ---------------- Cleanup ----------------

  Future<void> _cleanup() async {
    try {
      await _resultSub?.cancel();
    } catch (_) {}

    try {
      if (_resultChar != null) {
        await _resultChar!.setNotifyValue(false);
      }
    } catch (_) {}

    try {
      if (_device != null) {
        _log("Disconnecting BLE…");
        await _device!.disconnect();
      }
    } catch (_) {}
  }
}
