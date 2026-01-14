import 'dart:async'; // for TimeoutException
import 'package:flutter/material.dart';

import '../utils/routes.dart';
import '../services/bluetooth_service.dart';
import '../services/bluetooth_service_factory.dart';

class MascotScreen extends StatefulWidget {
  const MascotScreen({Key? key}) : super(key: key);

  @override
  State<MascotScreen> createState() => _MascotScreenState();
}

class _MascotScreenState extends State<MascotScreen>
    with SingleTickerProviderStateMixin {
  final BluetoothService _bluetoothService = getBluetoothService();

  // Game state
  bool _isVerifying = false;
  String _verificationStatus = 'Tap "Challenge" to start!';
  bool _hasCaughtMascot = false;
  bool _hasAttempted = false;

  int _coins = 5; // TODO: hook this up to your actual player data.

  // Mascot meta
  static const String _mascotName = 'Storky';
  static const String _mascotLocation = 'UCSB Storke Tower';
  static const String _mascotTier = 'Campus Legend • Tier S';
  static const double _catchProbability = 0.65; // currently unused

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _challengeMascot() async {
    if (_isVerifying) return;
    if (_coins < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to challenge!')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _hasAttempted = true;
      _verificationStatus = 'Connecting to Storky beacon...';
      _coins -= 2; // pay to challenge
    });

    try {
      // 10s timeout for BLE + backend verification
      final bool verified = await _bluetoothService
          .verifyPresence(context)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (!verified) {
        setState(() {
          _isVerifying = false;
          _verificationStatus =
          'Verification failed.\nMake sure you\'re near the Storky beacon and try again.';
        });
        return;
      }

      // ✅ Presence verified — Go to Catch Screen!
      if (!mounted) return;
      
      // Navigate to the Catch Screen and wait for result
      final result = await Navigator.pushNamed(
        context, 
        Routes.catchScreen,
        arguments: _mascotName, // pass mascot name if supported, or rely on internal default
      );

      if (!mounted) return;

      if (result == true) {
        // CAUGHT!
        setState(() {
          _isVerifying = false;
          _hasCaughtMascot = true;
          _verificationStatus = 'Verified presence — $_mascotName caught! 🎉';
          _coins += 3; // reward
        });
      } else {
        // ESCAPED!
        setState(() {
            _isVerifying = false;
            _verificationStatus = '$_mascotName escaped! Better luck next time.';
        });
      }

    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verificationStatus =
        'Verification timed out after 10 seconds.\nMake sure you\'re near the Storky beacon and try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verificationStatus =
        'An error occurred during verification: $e';
      });
    }
  }

  void _claimCoin() {
    setState(() {
      _coins += 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You found +1 Campus Coin! 💰'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  Color _statusColor() {
    if (_isVerifying) return Colors.amber.shade300;

    final msg = _verificationStatus;

    // 🔴 Anything that failed / timed out -> red
    if (msg.startsWith('Verification failed') ||
        msg.startsWith('Verification timed out') ||  // NEW
        msg.startsWith('An error')) {
      return Colors.redAccent.shade200;
    }

    // 🟠 Soft fail / escaped vibe
    if (msg.contains('slipped') || msg.contains('escaped')) {
      return Colors.orangeAccent.shade200;
    }

    // 🟢 Success state
    if (_hasCaughtMascot) {
      return Colors.lightGreenAccent.shade400;
    }

    // Default neutral
    return Colors.white70;
  }


  // === UI BUILDERS ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Storky Encounter'),
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
              const Icon(Icons.monetization_on,
                  color: Colors.yellow, size: 20),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Text(
                  '$_coins',
                  key: ValueKey<int>(_coins),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
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
                        _mascotName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mascotTier,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
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
                    color: _hasCaughtMascot
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasCaughtMascot
                            ? Icons.check_circle
                            : Icons.blur_on,
                        size: 18,
                        color: _hasCaughtMascot
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasCaughtMascot ? 'Caught' : 'Not caught',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _hasCaughtMascot
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
                        colors: [
                          Color(0xFF4263EB),
                          Color(0xFFB3C5FF),
                        ],
                        radius: 0.85,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                  ),
                  Hero(
                    tag: 'mascot-$_mascotName',
                    child: _isVerifying
                        ? ScaleTransition(
                      scale: _pulseController,
                      child: Image.asset(
                        'assets/icons/storke-nobackground.png',
                        fit: BoxFit.contain,
                        height: 140,
                      ),
                    )
                        : Image.asset(
                      'assets/icons/storke-nobackground.png',
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
            _buildDetailRow('Coins to Challenge', '2'),
            _buildDetailRow('Respawn Rate', 'Every 2 hours'),
            _buildDetailRow(
              'Base Catch Odds',
              '${(_catchProbability * 100).round()}%',
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
                value: 0.8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.deepPurple.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    final canChallenge = !_isVerifying && _coins >= 2;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canChallenge ? _challengeMascot : null,
            icon: const Icon(Icons.sports_martial_arts),
            label: Text(
              canChallenge ? 'Challenge' : 'Need 2 Coins',
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
            onPressed: _isVerifying ? null : _claimCoin,
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
              style: TextStyle(
                color: _statusColor(),
                fontSize: 14,
              ),
              child: Text(
                showHint
                    ? 'Spend 2 Campus Coins to challenge Storky. We’ll verify your presence with the beacon to catch the mascot!'
                    : _verificationStatus,
                textAlign: TextAlign.left,
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
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
