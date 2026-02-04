import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../state/current_user.dart';
import 'package:firebase_core/firebase_core.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'mascot-database', // EXACT name from console
);

class CatchScreen extends StatefulWidget {
  final String mascotName;
  final int mascotId;

  const CatchScreen({
    Key? key,
    // required this.mascotId, (for later when we have correct spawning mechanism)
    this.mascotId = 5, // default mascot_5 in our db for current setup
    this.mascotName = 'storkie',
  }) : super(key: key);

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position; // 0.0 → 1.0 across the bar

  bool _hasResult = false;
  bool? _success;

  // Normalized positions (0–1) where the zone is considered a “catch”.
  // Middle 30% of the bar.
  static const double _zoneStart = 0.35;
  static const double _zoneEnd = 0.65;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _position = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCatchTap() {
    if (_hasResult) return;

    final value = _position.value;
    final success = value >= _zoneStart && value <= _zoneEnd;

    // update UI immediately
    setState(() {
      _hasResult = true;
      _success = success;
    });

    _controller.stop();

    // backend async, don't block UI
    if (success) {
      _saveCatchToBackend(); // no await
    }

    _showResultDialog(success);
  }

  void _showResultDialog(bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.close_rounded,
                  size: 64,
                  color: success ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  success
                      ? 'You caught ${widget.mascotName}!'
                      : '${widget.mascotName} escaped!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  success
                      ? 'Nice timing! 🎯'
                      : 'Try to tap while the marker is inside the green zone.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop(); // close dialog
                          Navigator.of(context).pop(false); // return to MascotScreen: escaped
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop(); // close dialog
                          Navigator.of(context).pop(success); // return to MascotScreen with true/false
                        },
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveCatchToBackend() async {
    final u = CurrentUser.user;
    if (u == null) return;

    await _firestore
        .collection('users')
        .doc(u.username)
        .update({
          'caughtMascots': FieldValue.arrayUnion([widget.mascotId]),
          'coins': FieldValue.increment(1),
        });
  }

  void _resetGame() {
    setState(() {
      _hasResult = false;
      _success = null;
    });
    _controller
      ..reset()
      ..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Catch ${widget.mascotName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF001B48),
              Color(0xFF0052A5),
              Color(0xFF00A8E8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Time your tap to catch ${widget.mascotName}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'When the white marker is inside the green zone,\npress the CATCH button.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildTimingBar(),
                const SizedBox(height: 32),
                _buildCatchButton(),
                const Spacer(),
                if (_hasResult)
                  TextButton(
                    onPressed: _resetGame,
                    child: const Text(
                      'Play again',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimingBar() {
    return SizedBox(
      height: 80,
      child: AnimatedBuilder(
        animation: _position,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final double barWidth = constraints.maxWidth;
                  final double markerX = _position.value * barWidth;

                  final double zoneLeft = _zoneStart * barWidth;
                  final double zoneRight = _zoneEnd * barWidth;
                  final double zoneWidth = zoneRight - zoneLeft;

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        width: barWidth,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Positioned(
                        left: zoneLeft,
                        child: Container(
                          width: zoneWidth,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Positioned(
                        left: markerX - 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                _hasResult
                    ? (_success == true ? 'Great timing!' : 'Too early or too late.')
                    : 'Watch the marker...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatchButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleCatchTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: const Text('CATCH!'),
      ),
    );
  }
}