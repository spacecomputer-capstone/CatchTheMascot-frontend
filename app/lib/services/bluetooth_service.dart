import 'package:flutter/material.dart';

abstract class BluetoothService {
  Future<void> connectToDevice(BuildContext context, String serviceUuid);

  /// Runs the full nonce handshake with the connected beacon.
  /// Returns true if backend verifies the signature.
  Future<bool> verifyPresence(BuildContext context);
}
