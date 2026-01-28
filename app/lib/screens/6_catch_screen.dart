import 'package:flutter/material.dart';

class CatchScreen extends StatefulWidget {
  final String mascotName;
  final double rarity; // 0.0 (legendary/rare) to 1.0 (common)

  const CatchScreen({
    Key? key,
    this.mascotName = 'Storky',
    this.rarity = 1.0, 
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
  late double _zoneStart;
  late double _zoneEnd;

  @override
  void initState() {
    super.initState();
    
    // Difficulty logic: 
    // Rarity 0.1 (Rare) -> Harder
    // Rarity 1.0 (Common) -> Easier

    // Zone Width Config
    // Base 12% (0.12) + (18% * rarity)
    // Rarity 0.1 -> 0.138 (13.8%)
    // Rarity 1.0 -> 0.30 (30%)
    double zoneWidth = 0.12 + (0.18 * widget.rarity);
    
    double center = 0.5;
    _zoneStart = center - (zoneWidth / 2);
    _zoneEnd = center + (zoneWidth / 2);

    // Speed Config
    // Base 800ms + (800ms * rarity)
    // Rarity 0.1 -> 880ms (Fast)
    // Rarity 1.0 -> 1600ms (Slow/Normal)
    int durationMs = (800 + (800 * widget.rarity)).toInt();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
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

    final double value = _position.value;
    final bool success = value >= _zoneStart && value <= _zoneEnd;

    setState(() {
      _hasResult = true;
      _success = success;
    });
    _controller.stop();

    _showResultDialog(success);
  }

  void _showResultDialog(bool success) {
    showDialog(
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
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(false); // back to previous
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
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(success);
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
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              // Bar + zone + marker
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
                      // Base bar
                      Container(
                        width: barWidth,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      // Green catch zone
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
                      // Moving marker
                      Positioned(
                        left: markerX - 8, // center the circle
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
                    ? (_success == true
                    ? 'Great timing!'
                    : 'Too early or too late.')
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
