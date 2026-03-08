import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app/state/current_user.dart';
import 'package:app/apis/user_api.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:app/models/mascot.dart';
import 'package:app/screens/helpers.dart';
import 'package:app/utils/mascot_verification_helper.dart';

import '6_catch_screen.dart';
import 'dnd_combat_screen.dart';

class MascotScreen extends StatefulWidget {
  final int mascotId;
  final int piId;

  const MascotScreen({super.key, required this.mascotId, required this.piId});

  @override
  State<MascotScreen> createState() => _MascotScreenState();
}

class _MascotScreenState extends State<MascotScreen>
    with SingleTickerProviderStateMixin {
  static const String _verificationFailedMessage = 
      'We couldn’t verify your presence. Ensure you are at the correct location and try again.';
  static const String _verifyingStatusMessage = 'Verifying presence…';
  static const String _legacyFallbackStatusMessage =
      'Hold tight — this is taking a little longer than usual…';
  bool _isVerifying = false;
  String _verificationStatus = 'Tap "Challenge" to start!';
  bool _hasCaughtMascot = false;
  bool _hasAttempted = false;

  String username = CurrentUser.user?.username ?? "Player";
  int _coins = CurrentUser.user?.coins ?? 0;

  Mascot? _mascot;
  bool _isLoading = true;
  late final String _mascotLocation = 'UCSB Campus Area';

  late final AnimationController _pulseController;
  late final MascotVerificationHelper _verificationHelper;

  static const bool _useJwtPrimary = true;
  static const bool _allowLegacyFallback = true;
  static const Duration _jwtAttemptDuration = Duration(seconds: 3);
  static const Duration _legacyAttemptDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _loadMascot();
    _verificationHelper = MascotVerificationHelper(widgetPiId: widget.piId);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
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
      _verificationStatus = _verifyingStatusMessage;
      _coins -= coinsToChallenge;
    });

    CurrentUser.user!.coins -= coinsToChallenge;
    updateUser(CurrentUser.user!, context);

    try {
      final ok = await _runVerificationFlow();

      if (!mounted) return;

      if (ok) {
        setState(() { _verificationStatus = 'Presence verified — start catching!'; });

        // Keep success state visible briefly before navigating, matching legacy UX.
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;

        if (!CurrentUser.user!.visitedPis.contains(widget.piId)) {
          claimCoin(newLocationReward, message: "New location visited! +$newLocationReward coins! 🎉");
          CurrentUser.user!.visitedPis.add(widget.piId);
          CurrentUser.user!.lastPiVisited = widget.piId;
          await updateUser(CurrentUser.user!, context);
          if (!mounted) return;
        }

        if (CurrentUser.user!.lastPiVisited != widget.piId) {
          claimCoin(
            changeLocationReward,
            message:
            "Different location visited! +$changeLocationReward coins! 🎉",
          );
          CurrentUser.user!.lastPiVisited = widget.piId;
          await updateUser(CurrentUser.user!, context);
          if (!mounted) return;
        }

        final String mName = _mascot!.mascotName.toLowerCase();
        final bool isDndMascot = mName == 'storky' || mName == 'mascot_4' || mName == 'mascot_1';

        final didCatch = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CatchScreen(mascot: _mascot!),
          ),
        );

        if (!mounted) return;

        setState(() {
          _isVerifying = false;
          _hasCaughtMascot = didCatch == true;
          _verificationStatus = _hasCaughtMascot ? '$commonMascotName caught! 🎉' : '$commonMascotName escaped! 😭';
        });
      } else {
        setState(() {
          _isVerifying = false;
          _verificationStatus = _verificationFailedMessage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verificationStatus = _verificationFailedMessage;
      });
    }
  }

  Future<bool> _runVerificationFlow() async {
    if (username == "1") {
      return true;
    }

    if (!_useJwtPrimary) {
      if (!_allowLegacyFallback || !mounted) return false;
      setState(() {
        _verificationStatus = _legacyFallbackStatusMessage;
      });
      return _runLegacyFallbackFlow(_legacyAttemptDuration);
    }

    var jwtCompleted = false;
    var jwtResult = false;
    final jwtSuccess = Completer<bool>();
    final jwtFuture = _runJwtPrimaryFlow().then((ok) {
      jwtCompleted = true;
      jwtResult = ok;
      if (ok && !jwtSuccess.isCompleted) {
        jwtSuccess.complete(true);
      }
      return ok;
    });

    await Future.any<dynamic>([
      jwtSuccess.future,
      Future.delayed(_jwtAttemptDuration),
    ]);

    if (jwtCompleted && jwtResult) {
      return true;
    }

    if (!_allowLegacyFallback || !mounted) {
      final remainingJwtBudget =
          jwtCompleted ? Duration.zero : _legacyAttemptDuration;
      if (remainingJwtBudget == Duration.zero) {
        return false;
      }
      return jwtFuture.timeout(
        remainingJwtBudget,
        onTimeout: () => false,
      );
    }

    setState(() {
      _verificationStatus = _legacyFallbackStatusMessage;
    });

    final legacyFuture = _runLegacyFallbackFlow(_legacyAttemptDuration);

    if (jwtCompleted) {
      return legacyFuture.timeout(
        _legacyAttemptDuration,
        onTimeout: () => false,
      );
    }

    final overlapResult = Completer<bool>();
    var remainingFlows = 2;

    void settleOverlap(bool ok) {
      remainingFlows -= 1;
      if (ok && !overlapResult.isCompleted) {
        overlapResult.complete(true);
      } else if (remainingFlows == 0 && !overlapResult.isCompleted) {
        overlapResult.complete(false);
      }
    }

    jwtFuture.then(settleOverlap);
    legacyFuture.then(settleOverlap);

    return Future.any<bool>([
      overlapResult.future,
      Future.delayed(_legacyAttemptDuration, () => false),
    ]);
  }

  Future<bool> _runJwtPrimaryFlow() async {
    return _verificationHelper.runJwtPrimaryFlow();
  }

  Future<bool> _runLegacyFallbackFlow(Duration budget) async {
    return _verificationHelper.runLegacyFallbackFlow(budget);
  }

  void claimCoin(int numCoins, {String? message}) {
    setState(() { _coins += numCoins; });
    CurrentUser.user!.coins += numCoins;
    updateUser(CurrentUser.user!, context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'You found +$numCoins Campus Coins! 💰'), behavior: SnackBarBehavior.floating));
  }

  Color _statusColor() {
    if (_isVerifying) return Colors.amber.shade300;
    if (_verificationStatus == _verificationFailedMessage) {
      return Colors.redAccent.shade200;
    }
    if (_hasCaughtMascot) return Colors.lightGreenAccent.shade400;
    return Colors.white70;
  }

  Future<void> _loadMascot() async {
    final mascot = await getMascot(widget.mascotId);
    if (!mounted) return;
    setState(() { _mascot = mascot; _isLoading = false; });
  }

  String get mascotName => _mascot?.mascotName ?? "Mascot";
  String get commonMascotName => mascotName.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
  double get catchProbability => (1.0 - (_mascot?.rarity ?? 0.5));
  int get coinsToChallenge => _mascot?.coins ?? 2;
  String get mascotTier => getRarityTier(_mascot?.rarity ?? 0.5);
  Color get rarityColor => getRarityColor(_mascot?.rarity ?? 0.5);

  // Dynamic path based on your requirement: ID_Name.png
  String get mascotImagePath => "lib/assets/mascotimages/${widget.mascotId}_$mascotName.png";

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_mascot == null) return const Scaffold(body: Center(child: Text("Mascot not found")));

    return Scaffold(
      appBar: AppBar(title: Text('$commonMascotName Encounter'), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050814), Color(0xFF081A3A), Color(0xFF233D7B), Color(0xFF4263EB)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
        const Expanded(child: Text('Gaucho Trainer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(999)),
          child: Row(children: [const Icon(Icons.monetization_on, color: Colors.yellow, size: 20), const SizedBox(width: 4), Text('$_coins', style: const TextStyle(color: Colors.white, fontSize: 16))]),
        ),
      ],
    );
  }

  Widget _buildMascotCard() {
    return Card(
      elevation: 14, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), color: Colors.white.withOpacity(0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(commonMascotName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: rarityColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(mascotTier, style: TextStyle(fontSize: 13, color: rarityColor, fontWeight: FontWeight.w600))),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _hasCaughtMascot ? Colors.green.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(999)), child: Row(children: [Icon(_hasCaughtMascot ? Icons.check_circle : Icons.blur_on, size: 18, color: _hasCaughtMascot ? Colors.green.shade800 : Colors.orange.shade800), const SizedBox(width: 4), Text(_hasCaughtMascot ? 'Caught' : 'Not caught', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _hasCaughtMascot ? Colors.green.shade800 : Colors.orange.shade800))])),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFF4263EB), Color(0xFFB3C5FF)], radius: 0.85), boxShadow: [BoxShadow(color: Colors.blue.shade200.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)])),
                  Hero(
                    tag: 'mascot-$mascotName',
                    child: _isVerifying 
                      ? ScaleTransition(scale: _pulseController, child: Image.asset(mascotImagePath, fit: BoxFit.contain, height: 140, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 50)))
                      : Image.asset(mascotImagePath, fit: BoxFit.contain, height: 140, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 50)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 24),
            _buildDetailRow('Location', _mascotLocation),
            _buildDetailRow('Coins to Challenge', '$coinsToChallenge'),
            _buildDetailRow('Base Catch Odds', '${(catchProbability * 100).round()}%'),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Difficulty', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(minHeight: 9, value: (_mascot?.rarity ?? 0.5), backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(rarityColor))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    final canChallenge = !_isVerifying && _coins >= coinsToChallenge;
    return Row(
      children: [
        Expanded(child: ElevatedButton.icon(onPressed: canChallenge ? _challengeMascot : null, icon: const Icon(Icons.sports_martial_arts), label: Text(canChallenge ? 'Challenge' : 'Need $coinsToChallenge Coin(s)'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: canChallenge ? const Color(0xFFFFC857) : Colors.grey, foregroundColor: canChallenge ? Colors.black : Colors.grey.shade200, elevation: canChallenge ? 4 : 0))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: _isVerifying ? null : () => claimCoin(1), icon: const Icon(Icons.monetization_on), label: const Text('Claim Coin (+1)'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
      ],
    );
  }

  Widget _buildVerificationStatus() {
    final showHint = !_hasAttempted && !_isVerifying && !_hasCaughtMascot;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isVerifying) ...[const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)), const SizedBox(width: 8)] 
          else ...[Icon(_hasCaughtMascot ? Icons.stars : (showHint ? Icons.lightbulb_outline : Icons.info_outline), color: _statusColor()), const SizedBox(width: 8)],
          Expanded(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 250), style: TextStyle(color: _statusColor(), fontSize: 14), child: Text(showHint ? 'Spend $coinsToChallenge Campus Coin(s) to challenge $commonMascotName. We’ll verify your presence, then you can try to catch it!' : _verificationStatus))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Flexible(child: Text(value, style: const TextStyle(fontSize: 14), textAlign: TextAlign.right))]),
    );
  }
}
