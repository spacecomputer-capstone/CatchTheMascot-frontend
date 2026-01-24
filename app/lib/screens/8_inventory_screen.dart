//display caught mascots and number of coins

// import 'dart:ffi';

import 'package:app/apis/user_api.dart';
import 'package:app/models/mascot.dart';
import 'package:flutter/material.dart';
import 'package:app/apis/mascot_api.dart';
import 'package:app/state/current_user.dart';
import 'package:app/models/user.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<Mascot> mascots = [];
  String username = CurrentUser.user?.username ?? 'Guest';
  // final int coins = 0;

  @override
  void initState() {
    super.initState();

    if (CurrentUser.isLoggedIn) {
      _loadUserMascots();
      _loadUserCoins();
    }
  }

  Future<void> _loadUserMascots() async {
    try {
      mascots.clear();

      final List<int> userMascotIds = await getCaughtMascotsOfUser(
        CurrentUser.user!.username,
      );

      for (final id in userMascotIds) {
        final Mascot? mascot = await getMascot(id);
        if (mascot != null) {
          mascots.add(mascot);
        }
      }

      setState(() {}); // rebuild UI
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load inventory: $e')));
    }
  }

  Future<void> _loadUserCoins() async {
    CurrentUser.user!.coins = 0;

    try {
      if (username != "Guest") {
        final User? user = await fetchUserByUsername(username);
        if (CurrentUser.user != null) {
          CurrentUser.user!.coins = user!.coins;
        }
      }

      setState(() {}); // rebuild UI
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user\'s coins: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$username\'s Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch Mascots',
            onPressed: () {
              setState(() {
                // Replace the selection with:
                // fetch the user's mascots from Firestore

                // Future<List<int>> mascots = getCaughtMascotsOfUser(
                //   CurrentUser.user!.username
                // )
                _loadUserMascots()
                    .then((_) {
                      setState(() {}); // rebuild after fetch
                      if (!CurrentUser.isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please log in to fetch mascots from your inventory',
                            ),
                          ),
                        );
                        return;
                      }
                      if (mascots.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No mascots found')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fetched ${mascots.length} mascots'),
                          ),
                        );
                      }
                    })
                    .catchError((e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to fetch mascots: $e')),
                      );
                    });
              });

              // print('Mascots list updated. Total mascots: ${mascots.length}');
            },
          ),
        ],
      ),

      body:
          CurrentUser.isLoggedIn == false
              ? const Center(
                child: Text('Please log in to view your inventory.'),
              )
              :
              //shows a list of added mascots in this session
              mascots.isEmpty
              ? const Center(child: Text('No mascots available.'))
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coins display
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Coins: ${CurrentUser.user!.coins}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),

                  // Mascot list
                  Expanded(
                    child: ListView.builder(
                      itemCount: mascots.length,
                      itemBuilder: (context, index) {
                        final mascot = mascots[index];
                        print('Displaying mascot: ${mascot.mascotName}');
                        print(
                          'Details: ID=${mascot.mascotId}, PI=${mascot.piId}, Rarity=${mascot.rarity}, Respawn=${mascot.respawnTime}, Coins=${mascot.coins}',
                        );
                        //get mascot image path
                        // String mascotImagePath = await getMascotPath(mascot.mascotId);
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              //TODO: fix the image paths
                              "/lib/assets/mascotimages/1_raccoon.png",
                              width: 45,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.image_not_supported,
                                  size: 56,
                                );
                              },
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          title: Text('Name: ${mascot.mascotName}'),
                          subtitle: Text(
                            'ID: ${mascot.mascotId}\n'
                            'Location: ${mascot.piId}\n'
                            'Rarity: ${mascot.rarity}',
                          ),
                          trailing: Text(
                            'Respawn: ${mascot.respawnTime} min\n'
                            'Coins: ${mascot.coins}',
                            textAlign: TextAlign.right,
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
