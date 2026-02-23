// 4_mascot_screen.dart
//
// Smooth/simple version (no log sheet, no extra UI).
// Footer status text updates as the verification progresses.
//
// Protocol (same as your web frontend):
// 1) GET  /api/nonce  -> { nonceHex }
// 2) BLE: scan/connect to SERVICE_UUID
// 3) Read beaconId from ID_CHAR_UUID (8 bytes)
// 4) Write raw 16-byte nonce to SIGN_NONCE_UUID (writeWithoutResponse)
// 5) Wait notify 72 bytes on SIGN_RESP_UUID: ts_be64(8) || sig(64)
// 6) POST /api/verify { beaconIdHex, nonceHex, tsMs, sigHex }
// 7) If ok=true -> navigate to Catch screen
//
// Requires deps in pubspec.yaml:
//   http: ^1.2.0
//   flutter_blue_plus: ^1.34.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;

//to get current user info
import 'package:app/state/current_user.dart';

//user and mascot APIs
import 'package:app/apis/user_api.dart';
// import 'package:app/models/user.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:app/models/mascot.dart';
import 'package:app/screens/helpers.dart';

import '6_catch_screen.dart';

class MascotScreen extends StatefulWidget {
  //mascot information
  final int mascotId;
  final int piId;

  const MascotScreen({super.key, required this.mascotId, required this.piId});

  @override
  State<MascotScreen> createState() => _MascotScreenState();
}

class _MascotScreenState extends State<MascotScreen>
    with SingleTickerProviderStateMixin {
  // Game state
  bool _isVerifying = false;
  String _verificationStatus = 'Tap "Challenge" to start!';
  bool _hasCaughtMascot =
      false; //TODO: check backend if user already caught this mascot
  bool _hasAttempted = false;

  //get user info
  String username = CurrentUser.user?.username ?? "Player";
  int _coins = CurrentUser.user?.coins ?? 0;

  //get mascot info from mascot id: Future<Mascot?> getMascot(int mascotId, [BuildContext? context]) async
  Mascot? _mascot;
  bool _isLoading = true; //show loading spinner until mascot info is fetched
  late final String _mascotLocation =
      'UCSB Storke Tower'; //TODO: get from backend

  late final AnimationController _pulseController;

  // ---- API + BLE constants (match your web frontend UUIDs) ----
  static const String _apiBase = "https://spacescrypt-api.onrender.com";
  // For LAN testing:
  // static const String _apiBase = "http://172.20.10.7:5001";

  static final Guid _serviceUuid = Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a1");
  static final Guid _idCharUuid = Guid("eb5c86a4-733c-4d9d-aab2-285c2dab09a2");
  static final Guid _signNonceUuid = Guid(
    "eb5c86a4-733c-4d9d-aab2-285c2dab09a3",
  );
  static final Guid _signRespUuid = Guid(
    "eb5c86a4-733c-4d9d-aab2-285c2dab09a4",
  );

  @override
  void initState() {
    super.initState();
    _loadMascot();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true); // makes it pulse
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _challengeMascot() async {
    if (_isVerifying) return;

    if (_coins < coinsToChallenge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to challenge!')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _hasAttempted = true;
      _verificationStatus = 'Getting nonce…';
      _coins -= coinsToChallenge;
    });

    //subtract coins in the backend
    CurrentUser.user!.coins -= coinsToChallenge;
    updateUser(CurrentUser.user!, context);

    BluetoothDevice? device;
    StreamSubscription<List<int>>? notifSub;

    try {
      //DEBUGGING - SKIPPING LOCATION VERIFICATION----------------------------------
      //   // 1) GET nonce
      //   final nonceHex = await _fetchNonceHex();
      //   if (!mounted) return;

      //   setState(() {
      //     _verificationStatus = 'Connecting to beacon…';
      //   });

      //   // 2) Scan for device advertising our service UUID
      //   device = await _scanForBeacon(_serviceUuid);
      //   if (!mounted) return;

      //   // 3) Connect + discover characteristics
      //   setState(() {
      //     _verificationStatus = 'Verifying presence…';
      //   });

      //   await device.connect(
      //     timeout: const Duration(seconds: 10),
      //     autoConnect: false,
      //   );

      //   final services = await device.discoverServices();
      //   final svc = services.firstWhere(
      //     (s) => s.uuid == _serviceUuid,
      //     orElse: () => throw Exception("Service not found on beacon"),
      //   );

      //   final idChar = svc.characteristics.firstWhere(
      //     (c) => c.uuid == _idCharUuid,
      //     orElse: () => throw Exception("ID characteristic not found"),
      //   );

      //   final signNonceChar = svc.characteristics.firstWhere(
      //     (c) => c.uuid == _signNonceUuid,
      //     orElse: () => throw Exception("Nonce characteristic not found"),
      //   );

      //   final signRespChar = svc.characteristics.firstWhere(
      //     (c) => c.uuid == _signRespUuid,
      //     orElse: () => throw Exception("Response characteristic not found"),
      //   );

      //   // 4) Read beaconId
      //   final idBytes = await idChar.read();
      //   final beaconIdHex = _bytesToHex(idBytes).toLowerCase();

      //   // 5) Subscribe to notify (wait for exactly 72 bytes)
      //   await signRespChar.setNotifyValue(true);

      //   final completer = Completer<Uint8List>();
      //   notifSub = signRespChar.onValueReceived.listen((value) {
      //     final raw = Uint8List.fromList(value);
      //     if (raw.length == 72 && !completer.isCompleted) {
      //       completer.complete(raw);
      //     }
      //   });

      //   // 6) Write nonce (16 bytes) without response
      //   final nonceBytes = _hexToBytes(nonceHex);
      //   await signNonceChar.write(nonceBytes, withoutResponse: true);

      //   // 7) Wait for notify
      //   final raw = await completer.future.timeout(
      //     const Duration(seconds: 6),
      //     onTimeout: () => throw Exception("Verification timed out"),
      //   );

      //   // Parse notify: ts(8) || sig(64)
      //   final tsBytes = raw.sublist(0, 8);
      //   final sigBytes = raw.sublist(8);
      //   final tsMs = _be64ToMs(tsBytes);
      //   final sigHex = _bytesToHex(sigBytes).toLowerCase();

      //   // 8) POST verify
      //   final ok = await _postVerify(
      //     beaconIdHex: beaconIdHex,
      //     nonceHex: nonceHex,
      //     tsMs: tsMs.toString(),
      //     sigHex: sigHex,
      //   );
      // --------------------------------------------------------
      final ok = true; //DEBUGGING - SKIP VERIFICATION

      if (!mounted) return;

      if (ok) {
        setState(() {
          _verificationStatus = 'Presence verified — start catching!';
        });

        print(
          "Verification successful, navigating to Catch screen with mascotId ${widget.mascotId}...",
        );

        // give coins if visiting a new location
        if (!CurrentUser.user!.visitedPis.contains(widget.piId)) {
          claimCoin(
            newLocationReward,
            message: "New location visited! +$newLocationReward coins! 🎉",
          );
          CurrentUser.user!.visitedPis.add(widget.piId);
          CurrentUser.user!.lastPiVisited = widget.piId;
          await updateUser(CurrentUser.user!, context);
        }

        if (CurrentUser.user!.lastPiVisited != widget.piId) {
          claimCoin(
            changeLocationReward,
            message:
                "Different location visited! +$changeLocationReward coins! 🎉",
          );
          CurrentUser.user!.lastPiVisited = widget.piId;
          await updateUser(CurrentUser.user!, context);
        }

        final didCatch = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => CatchScreen(
                  mascot:
                      _mascot ??
                      Mascot(
                        'Unknown',
                        widget.mascotId,
                        0.5,
                        0,
                        120,
                        2,
                      ), //pass the mascot object to the catch screen
                ),
          ),
        );

        if (!mounted) return;

        setState(() {
          _isVerifying = false;

          final success = didCatch == true;
          _hasCaughtMascot = success;

          _verificationStatus =
              success
                  ? '$commonMascotName caught! 🎉'
                  : '$commonMascotName escaped! 😭';

          //   if (success) _coins += 3;
        });
      } else {
        setState(() {
          _isVerifying = false;
          _verificationStatus = 'Verification failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verificationStatus = 'Verification error: $e';
      });
    } finally {
      try {
        await notifSub?.cancel();
      } catch (_) {}
      try {
        if (device != null) {
          await device.disconnect();
        }
      } catch (_) {}
    }
  }

  // -------------------- Backend helpers --------------------

  Future<String> _fetchNonceHex() async {
    final r = await http.get(Uri.parse("$_apiBase/api/nonce"));
    if (r.statusCode != 200) {
      throw Exception("nonce failed: ${r.statusCode}");
    }
    final json = jsonDecode(r.body) as Map<String, dynamic>;
    final nonceHex = (json["nonceHex"] as String).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(nonceHex)) {
      throw Exception("bad nonceHex");
    }
    return nonceHex;
  }

  Future<bool> _postVerify({
    required String beaconIdHex,
    required String nonceHex,
    required String tsMs,
    required String sigHex,
  }) async {
    final payload = {
      "beaconIdHex": beaconIdHex,
      "nonceHex": nonceHex,
      "tsMs": tsMs,
      "sigHex": sigHex,
    };

    final r = await http.post(
      Uri.parse("$_apiBase/api/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    final json = jsonDecode(r.body) as Map<String, dynamic>;
    return json["ok"] == true;
  }

  // -------------------- BLE helpers --------------------

  Future<BluetoothDevice> _scanForBeacon(Guid serviceUuid) async {
    // ensure not already scanning
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    BluetoothDevice? found;

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.advertisementData.serviceUuids.contains(serviceUuid)) {
          found = r.device;
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: const Duration(seconds: 12),
    );

    // wait until scan timeout ends
    await Future.delayed(const Duration(seconds: 12));
    await FlutterBluePlus.stopScan();
    await sub.cancel();

    if (found == null) {
      throw Exception("No beacon found");
    }
    return found!;
  }

  // -------------------- bytes helpers --------------------

  static String _bytesToHex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, "0")).join();

  static Uint8List _hexToBytes(String hex) {
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

  static int _be64ToMs(Uint8List u8) {
    if (u8.length != 8) throw ArgumentError("ts must be 8 bytes");
    BigInt n = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      n = (n << 8) | BigInt.from(u8[i]);
    }
    return n.toInt();
  }

  // -------------------- UI helpers --------------------

  void claimCoin(int numCoins, {String? message}) {
    setState(() {
      _coins += numCoins;
    });
    CurrentUser.user!.coins += numCoins;
    updateUser(CurrentUser.user!, context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'You found +$numCoins Campus Coins! 💰'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _statusColor() {
    if (_isVerifying) return Colors.amber.shade300;

    final msg = _verificationStatus;

    if (msg.startsWith('Verification failed') ||
        msg.startsWith('Verification timed out') ||
        msg.startsWith('Verification error') ||
        msg.startsWith('An error')) {
      return Colors.redAccent.shade200;
    }

    if (msg.contains('escaped')) {
      return Colors.orangeAccent.shade200;
    }

    if (_hasCaughtMascot) {
      return Colors.lightGreenAccent.shade400;
    }

    return Colors.white70;
  }

  Future<void> _loadMascot() async {
    print("Loading mascot info for id ${widget.mascotId}...");
    final mascot = await getMascot(widget.mascotId);

    setState(() {
      _mascot = mascot; // now this is the REAL mascot
      _isLoading = false; // stop loading
    });
  }

  // getter functions

  String get mascotName => _mascot?.mascotName ?? "Unknown Mascot";

  String get commonMascotName {
    return mascotName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  double get catchProbability =>
      _mascot?.rarity != null ? (1.0 - _mascot!.rarity) : 0.5;

  int get coinsToChallenge => _mascot?.coins ?? 2;

  String get mascotTier => getRarityTier(_mascot?.rarity ?? 0.5);

  Color get rarityColor => getRarityColor(_mascot?.rarity ?? 0.5);

  String get mascotImagePath =>
      "lib/assets/mascotimages/${widget.mascotId}_$mascotName.png";

  int get respawnRate =>
      _mascot?.respawnTime ?? 120; // in minutes, default 2 hours

  double get rarity => _mascot?.rarity ?? 0.5;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_mascot == null) {
      return const Scaffold(body: Center(child: Text("Mascot not found")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$commonMascotName Encounter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF050814),
              Color(0xFF081A3A),
              Color(0xFF233D7B),
              Color(0xFF4263EB),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                Expanded(child: _buildMascotCard()),
                const SizedBox(height: 16),
                _buildActionsRow(),
                const SizedBox(height: 16),
                _buildVerificationStatus(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Icon(Icons.account_circle, color: Colors.white, size: 32),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Gaucho Trainer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder:
                    (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$_coins',
                  key: ValueKey<int>(_coins),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMascotCard() {
    return Card(
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: Colors.white.withOpacity(0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commonMascotName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          mascotTier,
                          style: TextStyle(
                            fontSize: 13,
                            color: rarityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _hasCaughtMascot
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasCaughtMascot ? Icons.check_circle : Icons.blur_on,
                        size: 18,
                        color:
                            _hasCaughtMascot
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasCaughtMascot ? 'Caught' : 'Not caught',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              _hasCaughtMascot
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF4263EB), Color(0xFFB3C5FF)],
                        radius: 0.85,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  Hero(
                    tag: 'mascot-$mascotName',
                    child:
                        _isVerifying
                            ? ScaleTransition(
                              scale: _pulseController,
                              child: Image.asset(
                                mascotImagePath,
                                fit: BoxFit.contain,
                                height: 140,
                              ),
                            )
                            : Image.asset(
                              mascotImagePath,
                              fit: BoxFit.contain,
                              height: 140,
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 24),
            _buildDetailRow('Location', _mascotLocation),
            _buildDetailRow('Coins to Challenge', '$coinsToChallenge'),
            _buildDetailRow('Respawn Rate', 'Every $respawnRate minutes'),
            _buildDetailRow(
              'Base Catch Odds',
              '${(catchProbability * 100).round()}%',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Difficulty',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: rarity,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    final canChallenge =
        !_isVerifying &&
        _coins >= coinsToChallenge; //TODO: && !_hasCaughtMascot;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canChallenge ? _challengeMascot : null,
            icon: const Icon(Icons.sports_martial_arts),
            label: Text(
              canChallenge ? 'Challenge' : 'Need $coinsToChallenge Coin(s)',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor:
                  canChallenge ? const Color(0xFFFFC857) : Colors.grey,
              foregroundColor:
                  canChallenge ? Colors.black : Colors.grey.shade200,
              elevation: canChallenge ? 4 : 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isVerifying ? null : () => claimCoin(1),
            icon: const Icon(Icons.monetization_on),
            label: const Text('Claim Coin (+1)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStatus() {
    final showHint = !_hasAttempted && !_isVerifying && !_hasCaughtMascot;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isVerifying) ...[
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Icon(
              _hasCaughtMascot
                  ? Icons.stars
                  : (showHint ? Icons.lightbulb_outline : Icons.info_outline),
              color: _statusColor(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(color: _statusColor(), fontSize: 14),
              child: Text(
                showHint
                    ? 'Spend $coinsToChallenge Campus Coin(s) to challenge $commonMascotName. We’ll verify your presence, then you can try to catch it!'
                    : _verificationStatus,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
