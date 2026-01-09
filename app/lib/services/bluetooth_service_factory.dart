import 'package:flutter/foundation.dart' show kIsWeb;

import 'bluetooth_service.dart';
import 'bluetooth_service_mobile.dart';
import 'bluetooth_service_web.dart';

BluetoothService getBluetoothService() {
  if (kIsWeb) {
    return BluetoothServiceWeb();
  } else {
    return BluetoothServiceMobile();
  }
}
