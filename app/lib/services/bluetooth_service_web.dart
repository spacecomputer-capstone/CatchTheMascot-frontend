import 'package:flutter/material.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart' hide BluetoothService;

import 'bluetooth_service.dart';

class BluetoothServiceWeb implements BluetoothService {
  static const String _serviceUuidStr = 'eb5c86a4-733c-4d9d-aab2-285c2dab09a1';

  @override
  Future<void> connectToDevice(BuildContext context, String _ignored) async {
    final isAvailable = await FlutterWebBluetooth.instance.isAvailable.first;
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web Bluetooth is not available in this browser'),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Filter by our service UUID so the chooser only shows the beacon
      final options = RequestOptionsBuilder(
        [
          RequestFilterBuilder(
            services: [_serviceUuidStr.toLowerCase()],
          ),
        ],
      );

      final device =
      await FlutterWebBluetooth.instance.requestDevice(options);

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // close loading dialog
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connected to ${device.name ?? "beacon"} (web not fully supported yet)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Web Bluetooth error: $e')),
        );
      }
    }
  }

  @override
  Future<bool> verifyPresence(BuildContext context) async {
    // 👇 Simple stub so web builds; mobile does the real work.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Presence verification is only implemented on Android/iOS for now.',
          ),
        ),
      );
    }
    return false;
  }
}
