import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class NetCatchScreen extends StatefulWidget {
  final String mascotName;
  final double catchProbability; // 0.0–1.0
  final String mascotAsset;

  const NetCatchScreen({
    Key? key,
    this.mascotName = 'Storky',
    this.catchProbability = 0.6, // 60% base catch chance
    this.mascotAsset = 'assets/icons/storke-nobackground.png',
  }) : super(key: key);

  @override
  State<NetCatchScreen> createState() => _NetCatchScreenState();
}

class _NetCatchScreenState extends State<NetCatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isThrowing = false;
  bool _hasThrownAtLeastOnce = false;

  final Random _random = Random();

  // normalized positions (0–1 in both directions)
  final Offset _mascotFraction = const Offset(0.5, 0.3);
  final Offset _netStartFraction = const Offset(0.2, 0.85);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onThrowFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _throwNet() {
    if (_isThrowing) return;

    setState(() {
      _isThrowing = true;
      _hasThrownAtLeastOnce = true;
    });

    _controller.forward(from: 0);
  }

  void _onThrowFinished() async {
    // Decide catch result based on probability
    final bool caught =
        _random.nextDouble() < widget.catchProbability.clamp(0.0, 1.0);

    setState(() {
      _isThrowing = false;
    });

    await _showResultDialog(caught);

    if (!mounted) return;

    // Return result to previous screen
    Navigator.of(context).pop(caught);
  }

  Future<void> _showResultDialog(bool caught) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  caught ? Icons.check_circle : Icons.close_rounded,
                  size: 64,
                  color: caught ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  caught
                      ? 'You caught ${widget.mascotName} with your net!'
                      : '${widget.mascotName} escaped the net!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  caught
                      ? 'Nice throw! 🎯'
                      : 'Try again — time your throw when ${widget.mascotName} is still.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hintText() {
    if (_isThrowing) return 'Throwing the net...';
    if (!_hasThrownAtLeastOnce) {
      return 'Tap "Throw Net" to try to catch ${widget.mascotName}.';
    }
    return 'Tap "Throw Net" again to try another catch.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Net Catch: ${widget.mascotName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;

          // Helpers to convert normalized coords to pixels
          Offset toPixels(Offset fraction) =>
              Offset(fraction.dx * width, fraction.dy * height);

          final Offset mascotCenter = toPixels(_mascotFraction);
          final Offset netStart = toPixels(_netStartFraction);

          // Net position during animation
          final double t = _controller.value; // 0→1
          final Offset netPos = _isThrowing
              ? _computeNetPosition(netStart, mascotCenter, t)
              : netStart;

          final double mascotSize = min(width, height) * 0.18;
          final double netSize = min(width, height) * 0.16;

          return Container(
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
            child: Stack(
              children: [
                // Mascot sprite
                Positioned(
                  left: mascotCenter.dx - mascotSize / 2,
                  top: mascotCenter.dy - mascotSize / 2,
                  child: Column(
                    children: [
                      Container(
                        width: mascotSize * 1.2,
                        height: mascotSize * 1.2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.25),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            widget.mascotAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.mascotName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Net
                Positioned(
                  left: netPos.dx - netSize / 2,
                  top: netPos.dy - netSize / 2,
                  child: Transform.rotate(
                    angle: _isThrowing ? -0.4 : -0.2,
                    child: _buildNetWidget(netSize),
                  ),
                ),

                // Throw button + hint
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _hintText(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isThrowing ? null : _throwNet,
                          icon: const Icon(Icons.network_check),
                          label: const Text('Throw Net'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Offset _computeNetPosition(Offset start, Offset target, double t) {
    // Simple parabolic arc from start to target.
    final double dx = lerpDouble(start.dx, target.dx, t)!;
    final double dy = lerpDouble(start.dy, target.dy, t)!;

    // Raise the net up in a small arc: peak at t = 0.5
    final double arcHeight = 60.0;
    final double arc = -arcHeight * sin(pi * t);

    return Offset(dx, dy + arc);
  }

  Widget _buildNetWidget(double size) {
    // Simple visual net made from a rounded rect + grid lines.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: Colors.white70,
          width: 2,
        ),
      ),
      child: CustomPaint(
        painter: _NetGridPainter(),
      ),
    );
  }
}

class _NetGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;

    const int rows = 4;
    const int cols = 4;

    final double rowStep = size.height / (rows + 1);
    final double colStep = size.width / (cols + 1);

    for (int i = 1; i <= rows; i++) {
      final double y = rowStep * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    for (int j = 1; j <= cols; j++) {
      final double x = colStep * j;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetGridPainter oldDelegate) => false;
}
