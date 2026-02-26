import 'package:flutter/material.dart';
import 'package:app/apis/user_api.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:app/models/mascot.dart';
import 'package:app/models/user.dart';
import 'package:app/state/current_user.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<Mascot> mascots = [];
  String username = CurrentUser.user?.username ?? 'Guest';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    if (CurrentUser.isLoggedIn) {
      _initialize();
    } else {
      isLoading = false;
    }
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadUserMascots(),
      _loadUserCoins(),
    ]);

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadUserMascots() async {
    try {
      mascots.clear();

      final List<int> userMascotIds =
          await getCaughtMascotsOfUser(CurrentUser.user!.username);

      final List<Mascot> fetchedMascots =
          await getMascotsByIds(userMascotIds);

      mascots.addAll(fetchedMascots);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load inventory: $e')),
      );
    }
  }

  Future<void> _loadUserCoins() async {
    try {
      if (username != "Guest") {
        final User? user = await fetchUserByUsername(username);
        if (user != null) {
          CurrentUser.user!.coins = user.coins;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load coins: $e')),
      );
    }
  }

  Color _rarityColor(double rarity) {
    if (rarity < 0.2) return Colors.grey;
    if (rarity < 0.4) return Colors.green;
    if (rarity < 0.6) return Colors.blue;
    if (rarity < 0.8) return Colors.purple;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "${username[0].toUpperCase()}${username.substring(1)}'s Mascotarium",
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _initialize,
          ),
        ],
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
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!CurrentUser.isLoggedIn) {
      return const Center(
        child: Text(
          'Please log in to view your inventory.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (mascots.isEmpty) {
      return const Center(
        child: Text(
          'No mascots caught yet!',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coins Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.monetization_on,
                  color: Color(0xFFFFC857)),
              const SizedBox(width: 8),
              Text(
                'Coins: ${CurrentUser.user!.coins}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mascots.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              final mascot = mascots[index];
              final mascotImagePath =
                  'lib/assets/mascotimages/${mascot.mascotId}_${mascot.mascotName}.png';

              return _buildMascotCard(mascot, mascotImagePath);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMascotCard(Mascot mascot, String mascotImagePath) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                mascotImagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                    size: 48,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mascot.mascotName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _rarityColor(mascot.rarity)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              mascot.rarity.toString(),
              style: TextStyle(
                color: _rarityColor(mascot.rarity),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '🪙 ${mascot.coins}   ⏱ ${mascot.respawnTime}m',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}