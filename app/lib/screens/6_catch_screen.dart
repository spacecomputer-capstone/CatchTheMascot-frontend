import 'package:flutter/material.dart';
import '../services/rng_service.dart';

class CatchScreen extends StatefulWidget {
  final String mascotName;

  const CatchScreen({
    Key? key,
    this.mascotName = 'Storky',
  }) : super(key: key);

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _position;

  bool _hasResult = false;
  bool? _success;
  bool _isConsultingRng = false; // New state for loading

  // Normalized positions (0–1) where the zone is considered a “catch”.
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

    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 1),
       lowerBound: 0.95,
       upperBound: 1.05,
     )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCatchTap() async {
    if (_hasResult || _isConsultingRng) return;

    final double value = _position.value;
    final bool skillSuccess = value >= _zoneStart && value <= _zoneEnd;

    _controller.stop();
    setState(() {
      _hasResult = true; // Temporary lock
    });

    if (!skillSuccess) {
      // Failed skill check immediately
      setState(() {
        _success = false;
      });
      _showResultDialog(false);
      return;
    }

    // Passed Skill Check! consulting RNG...
    setState(() {
      _isConsultingRng = true;
    });

    // 1. Fetch RNG
    final nonce = await RngService.getNonce();
    
    if (!mounted) return;

    setState(() {
      _isConsultingRng = false;
    });

    // 2. Determine Outcome
    // If API fails (null), we default to Success (don't punish user for connection error)
    // Or we could fallback to Dart Random. Let's be generous.
    bool finalSuccess = true; 

    if (nonce != null) {
      final double rngVal = RngService.nonceToProbability(nonce);
      // 65% catch rate if skill passed
      finalSuccess = rngVal < 0.65; 
      print("SpaceComputer RNG: $rngVal (Threshold < 0.65) -> Catch: $finalSuccess");
    } else {
      print("SpaceComputer unreachable, defaulting to skill-based success.");
    }

    setState(() {
      _success = finalSuccess;
    });

    _showResultDialog(finalSuccess);
  }

  void _showResultDialog(bool success) {
    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.black.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    'Verified presence!\n${widget.mascotName} caught!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ScaleTransition(
                      scale: _pulseController,
                      child: Hero(
                        tag: 'mascot-${widget.mascotName}',
                        child: Image.asset(
                          'assets/icons/storke-nobackground.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '+3 Campus Coins\n+1 Mascot in Collection',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC857),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Nice!'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
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
                  const Icon(
                    Icons.close_rounded,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.mascotName} escaped!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                   'The cosmic winds were not in your favor.\nSpace Computer says: Unlucky!',
                    style: TextStyle(
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
                            Navigator.of(context).pop(false);
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
                             _resetGame();
                             Navigator.of(context).pop();
                          },
                          child: const Text('Try Again'),
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
                if (_isConsultingRng)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                const Spacer(),
                if (_hasResult && !_isConsultingRng)
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
                    ? (_isConsultingRng 
                        ? 'Consulting Space Computer...' 
                        : (_success == true ? 'Great timing + Good RNG!' : (_success == false && _isConsultingRng == false && _hasResult == true && (_position.value >= _zoneStart && _position.value <= _zoneEnd)) ? 'Timed right, but escaped!' : 'Too early or too late.'))
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
        onPressed: (_hasResult || _isConsultingRng) ? null : _handleCatchTap,
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
