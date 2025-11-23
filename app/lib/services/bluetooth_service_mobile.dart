import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'bluetooth_service.dart';

class BluetoothServiceMobile implements BluetoothService {
  // ====== UUIDs (same as your web app) ======
  static const String _serviceUuidStr =
      'eb5c86a4-733c-4d9d-aab2-285c2dab09a1';
  static const String _idCharUuidStr =
      'eb5c86a4-733c-4d9d-aab2-285c2dab09a2';
  static const String _signNonceUuidStr =
      'eb5c86a4-733c-4d9d-aab2-285c2dab09a3';
  static const String _signRespUuidStr =
      'eb5c86a4-733c-4d9d-aab2-285c2dab09a4';

  // ====== Backend config ======
  static const String _apiBase =
      'https://spacescrypt-api.onrender.com';

  final fb.Guid _serviceUuid = fb.Guid(_serviceUuidStr);
  final fb.Guid _idCharUuid = fb.Guid(_idCharUuidStr);
  final fb.Guid _signNonceUuid = fb.Guid(_signNonceUuidStr);
  final fb.Guid _signRespUuid = fb.Guid(_signRespUuidStr);

  fb.BluetoothDevice? _device;

  @override
  Future<void> connectToDevice(
      BuildContext context, String serviceUuid) async {
    // Simple debug helper; the real flow is in verifyPresence.
    try {
      _device = await _scanAndConnect(context);
      if (_device != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${_device!.platformName}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  /// Mirror of your React `verifyPresence`:
  ///
  /// 1. scan + connect
  /// 2. read 8-byte beacon ID (ID_CHAR_UUID)
  /// 3. GET /api/nonce -> nonceHex
  /// 4. write hexToBytes(nonceHex) to SIGN_NONCE_UUID
  /// 5. wait for notify on SIGN_RESP_UUID (72 bytes: ts(8) || sig(64))
  /// 6. /api/verify with beaconIdHex, nonceHex, tsMs, sigHex
  @override
  Future<bool> verifyPresence(BuildContext context) async {
    try {
      // 1) Scan and connect
      _device = await _scanAndConnect(context);
      if (_device == null) {
        throw Exception('Could not find a compatible mascot device.');
      }

      // 2) Discover characteristics
      final characteristics = await _getCharacteristics(_device!);
      final idChar = characteristics['id'];
      final signNonceChar = characteristics['nonce'];
      final signRespChar = characteristics['resp'];

      if (idChar == null ||
          signNonceChar == null ||
          signRespChar == null) {
        throw Exception('Device is missing required characteristics.');
      }

      // 3) Read 8-byte beacon ID
      final List<int> idRaw = await idChar.read();
      final Uint8List idBytes = Uint8List.fromList(idRaw);
      final String beaconIdHex = _bytesToHex(idBytes).toLowerCase();

      // 4) GET /api/nonce
      final nonceResp =
      await http.get(Uri.parse('$_apiBase/api/nonce'));
      if (nonceResp.statusCode != 200) {
        throw Exception(
          'nonce failed: ${nonceResp.statusCode} ${nonceResp.body}',
        );
      }
      final Map<String, dynamic> nonceJson =
      jsonDecode(nonceResp.body) as Map<String, dynamic>;
      final String nonceHex = nonceJson['nonceHex'] as String;
      final Uint8List nonceBytes = _hexToBytes(nonceHex);

      if (nonceBytes.length != 16) {
        throw Exception(
          'Expected 16-byte nonce, got ${nonceBytes.length}',
        );
      }

      // 5) Subscribe to notifications on SIGN_RESP_UUID
      final propsResp = signRespChar.properties;
      if (!propsResp.notify && !propsResp.indicate) {
        throw Exception(
          'Response characteristic is not notifiable/indicatable.',
        );
      }

      final completer = Completer<Uint8List>();
      final sub = signRespChar.onValueReceived.listen((value) {
        // value is List<int>
        if (value.isEmpty) return;
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(value));
        }
      });

      // Enable notifications
      await signRespChar.setNotifyValue(true);

      try {
        // 6) Write nonce to SIGN_NONCE_UUID (without response, like web)
        final propsNonce = signNonceChar.properties;
        if (!propsNonce.writeWithoutResponse &&
            !propsNonce.write) {
          throw Exception(
            'SignNonce characteristic is not writable.',
          );
        }

        final bool useWithoutResponse =
            propsNonce.writeWithoutResponse && !propsNonce.write;

        await signNonceChar.write(
          Uint8List.fromList(nonceBytes),
          withoutResponse: useWithoutResponse,
        );

        // 7) Wait for 72-byte notification: ts(8) || sig(64)
        final Uint8List notifBytes = await completer.future
            .timeout(const Duration(seconds: 10), onTimeout: () {
          throw Exception(
            'Timed out waiting for signature notification.',
          );
        });

        if (notifBytes.length != 72) {
          throw Exception(
            'Expected 72 bytes (ts+sig), got ${notifBytes.length}',
          );
        }

        final Uint8List tsBytes = notifBytes.sublist(0, 8);
        final Uint8List sigBytes = notifBytes.sublist(8);

        final int tsMs = _be64ToMs(tsBytes);
        final String sigHex = _bytesToHex(sigBytes);

        // 8) POST /api/verify
        final verifyResp = await http.post(
          Uri.parse('$_apiBase/api/verify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'beaconIdHex': beaconIdHex,
            'nonceHex': nonceHex,
            'tsMs': tsMs.toString(),
            'sigHex': sigHex,
          }),
        );

        if (verifyResp.statusCode != 200) {
          throw Exception(
            'verify failed: ${verifyResp.statusCode} ${verifyResp.body}',
          );
        }

        final Map<String, dynamic> vJson =
        jsonDecode(verifyResp.body) as Map<String, dynamic>;
        final bool ok = vJson['ok'] == true || vJson['valid'] == true;

        return ok;
      } finally {
        // Clean up notifications listener
        try {
          await signRespChar.setNotifyValue(false);
        } catch (_) {}
        await sub.cancel();
      }
    } finally {
      // Always disconnect when done
      await _device?.disconnect();
      _device = null;
    }
  }

  // ====== BLE helpers ======

  Future<fb.BluetoothDevice?> _scanAndConnect(
      BuildContext context) async {
    if (!await _requestPermissions()) {
      throw Exception('Bluetooth permissions are required.');
    }
    if (!await _isBluetoothOn()) {
      throw Exception('Please turn on Bluetooth.');
    }

    final completer = Completer<fb.BluetoothDevice?>();
    StreamSubscription<List<fb.ScanResult>>? sub;

    sub = fb.FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.advertisementData.serviceUuids.contains(_serviceUuid)) {
          fb.FlutterBluePlus.stopScan();
          sub?.cancel();
          completer.complete(r.device);
          return;
        }
      }
    });

    await fb.FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      withServices: [_serviceUuid],
    );

    final device = await completer.future
        .timeout(const Duration(seconds: 11), onTimeout: () => null);
    await fb.FlutterBluePlus.stopScan();
    await sub?.cancel();

    if (device != null) {
      await device.connect(autoConnect: false);
    }

    return device;
  }

  Future<Map<String, fb.BluetoothCharacteristic>> _getCharacteristics(
      fb.BluetoothDevice device) async {
    final services = await device.discoverServices();
    final service =
    services.firstWhere((s) => s.uuid == _serviceUuid);

    final characteristics = <String, fb.BluetoothCharacteristic>{};
    for (final c in service.characteristics) {
      if (c.uuid == _idCharUuid) characteristics['id'] = c;
      if (c.uuid == _signNonceUuid) characteristics['nonce'] = c;
      if (c.uuid == _signRespUuid) characteristics['resp'] = c;
    }
    return characteristics;
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus =
      await Permission.bluetoothConnect.request();
      return scanStatus.isGranted && connectStatus.isGranted;
    } else if (Platform.isIOS) {
      // iOS uses Info.plist + system dialog; nothing to request here.
      return true;
    } else {
      return true;
    }
  }

  Future<bool> _isBluetoothOn() async {
    final state =
    await fb.FlutterBluePlus.adapterState.first;
    return state == fb.BluetoothAdapterState.on;
  }

  // ====== Byte helpers (mirror TS utils) ======

  Uint8List _hexToBytes(String hex) {
    final cleaned = hex.trim().toLowerCase();
    if (cleaned.length % 2 != 0 ||
        !RegExp(r'^[0-9a-f]*$').hasMatch(cleaned)) {
      throw FormatException('bad hex: $hex');
    }
    final out = Uint8List(cleaned.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      final byteStr = cleaned.substring(i * 2, i * 2 + 2);
      out[i] = int.parse(byteStr, radix: 16);
    }
    return out;
  }

  String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Big-endian 8-byte → ms (like be64ToMs in TS)
  int _be64ToMs(Uint8List buf) {
    if (buf.length != 8) {
      throw Exception('ts must be 8 bytes, got ${buf.length}');
    }
    final bd = ByteData.view(buf.buffer, buf.offsetInBytes, buf.length);
    // getInt64 with big endian matches your JS BigInt accumulate.
    return bd.getInt64(0, Endian.big);
  }
}
