import 'package:flutter/material.dart';
import 'dart:math'; // For random dice roll

class CatchScreen extends StatefulWidget {
  final String mascotName;
  final double rarity; // 0.0 to 10.0

  const CatchScreen({
    Key? key,
    this.mascotName = 'Storky',
    this.rarity = 0.0,
  }) : super(key: key);

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position; // 0.0 → 1.0 across the bar

  // For moving zone (Rarity > 8)
  late final AnimationController _zoneController;
  late final Animation<double> _zonePosition;

  bool _hasResult = false;
  bool? _success;
  int? _diceRoll; // 1-6

  // Base zone size (30% of bar)
  static const double _zoneSize = 0.3;

  @override
  void initState() {
    super.initState();

    // 1. Calculate Speed based on Rarity
    // Base duration: 1600ms
    // Max Rarity (10): 600ms
    // Formula: 1600 - (rarity * 100)
    int durationMs = (1600 - (widget.rarity * 100)).clamp(600, 1600).toInt();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat(reverse: true);

    _position = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // 2. Setup Moving Zone (Rarity > 8)
    _zoneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Zone moves slower than marker
    );

    if (widget.rarity > 8) {
      _zoneController.repeat(reverse: true);
    }

    _zonePosition = CurvedAnimation(
      parent: _zoneController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  void _handleCatchTap() {
    if (_hasResult) return;

    final double value = _position.value;
    
    // Calculate current zone Start/End
    double currentZoneStart;
    
    if (widget.rarity > 8) {
      // Zone moves between 0.0 and (1.0 - _zoneSize)
      // _zonePosition.value (0->1) map to allowable range
      final double maxStart = 1.0 - _zoneSize;
      currentZoneStart = _zonePosition.value * maxStart;
    } else {
      // Static middle
      currentZoneStart = 0.35;
    }
    
    final double currentZoneEnd = currentZoneStart + _zoneSize;

    // 1. Check if inside zone
    bool hitZone = value >= currentZoneStart && value <= currentZoneEnd;
    bool finalSuccess = hitZone;

    // 2. Dice Roll Check (Rarity > 9)
    if (hitZone && widget.rarity > 9) {
      final roll = Random().nextInt(6) + 1; // 1-6
      _diceRoll = roll;
      if (roll < 4) {
        finalSuccess = false; // Failed the roll
      }
    }

    setState(() {
      _hasResult = true;
      _success = finalSuccess;
    });
    
    _controller.stop();
    _zoneController.stop();

    _showResultDialog(finalSuccess);
  }

  void _showResultDialog(bool success) {
    String message = success
        ? 'You caught ${widget.mascotName}!'
        : '${widget.mascotName} escaped!';
    
    // Custom messages for dice roll failure
    if (_hasResult && !success && _diceRoll != null && _diceRoll! < 4) {
      message = 'Hit zone, but bad roll ($_diceRoll)! Escaped.';
    } else if (!success) {
      message = '${widget.mascotName} escaped!';
    }

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
                  message,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_diceRoll != null) ...[
                   Text(
                    'Dice Roll: $_diceRoll (Need 4+)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _diceRoll! >= 4 ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  success
                      ? 'Nice timing! 🎯'
                      : 'Better luck next time!',
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
                    const SizedBox(height: 12),
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
      _diceRoll = null;
    });
    
    _controller.reset();
    _controller.repeat(reverse: true);
    
    if (widget.rarity > 8) {
      _zoneController.reset();
      _zoneController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Catch ${widget.mascotName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
           Center(
             child: Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.white24,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   'Rarity ${widget.rarity}',
                   style: const TextStyle(fontWeight: FontWeight.bold),
                 ),
               ),
             ),
           )
        ],
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
                Text(
                  widget.rarity > 9 
                      ? 'Legendary difficulty! Green zone moves AND needs a 4+ roll.'
                      : (widget.rarity > 8 
                          ? 'High difficulty! The green zone is moving.'
                          : 'When the white marker is inside the green zone,\npress the CATCH button.'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildTimingBar(),
                const SizedBox(height: 32),
                
                // Dice Visual for Legendary
                if (widget.rarity > 9) ...[
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.white30),
                     ),
                     child: Column(
                       children: [
                         const Text('LUCK CHECK', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
                         const SizedBox(height: 8),
                         Icon(Icons.casino, color: Colors.white.withOpacity(0.8), size: 40),
                         const SizedBox(height: 4),
                         const Text('Needs 4+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 32),
                ],
                
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
        animation: Listenable.merge([_controller, _zoneController]),
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bar + zone + marker
              LayoutBuilder(
                builder: (context, constraints) {
                  final double barWidth = constraints.maxWidth;
                  final double markerX = _position.value * barWidth;

                  // Dynamic Zone Position
                  double zoneLeft;
                  if (widget.rarity > 8) {
                     final double maxStart = 1.0 - _zoneSize;
                     zoneLeft = (_zonePosition.value * maxStart) * barWidth;
                  } else {
                     zoneLeft = 0.35 * barWidth;
                  }
                  
                  final double zoneWidth = _zoneSize * barWidth; // 30% width

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
                            color: widget.rarity > 8 
                                ? Colors.greenAccent.withOpacity(0.8) 
                                : Colors.greenAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: widget.rarity > 8 ? [
                              BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 10)
                            ] : [],
                          ),
                        ),
                      ),
                      // Moving marker
                      Positioned(
                        left: markerX - 12, // center the circle (24/2)
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
