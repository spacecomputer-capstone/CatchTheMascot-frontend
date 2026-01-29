// //display caught mascots and number of coins

// // import 'dart:ffi';

// import 'package:app/apis/user_api.dart';
// import 'package:app/models/mascot.dart';
// import 'package:flutter/material.dart';
// import 'package:app/apis/mascot_api.dart';
// import 'package:app/state/current_user.dart';
// import 'package:app/models/user.dart';

// class InventoryScreen extends StatefulWidget {
//   const InventoryScreen({super.key});

//   @override
//   State<InventoryScreen> createState() => _InventoryScreenState();
// }

// class _InventoryScreenState extends State<InventoryScreen> {
//   final List<Mascot> mascots = [];
//   String username = CurrentUser.user?.username ?? 'Guest';
//   // final int coins = 0;

//   @override
//   void initState() {
//     super.initState();

//     if (CurrentUser.isLoggedIn) {
//       _loadUserMascots();
//       _loadUserCoins();
//     }
//   }

//   Future<void> _loadUserMascots() async {
//     try {
//       mascots.clear();

//       final List<int> userMascotIds = await getCaughtMascotsOfUser(
//         CurrentUser.user!.username,
//       );

//       for (final id in userMascotIds) {
//         final Mascot? mascot = await getMascot(id);
//         if (mascot != null) {
//           mascots.add(mascot);
//         }
//       }

//       setState(() {}); // rebuild UI
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to load inventory: $e')));
//     }
//   }

//   Future<void> _loadUserCoins() async {
//     CurrentUser.user!.coins = 0;

//     try {
//       if (username != "Guest") {
//         final User? user = await fetchUserByUsername(username);
//         if (CurrentUser.user != null) {
//           CurrentUser.user!.coins = user!.coins;
//         }
//       }

//       setState(() {}); // rebuild UI
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to load user\'s coins: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('$username\'s Inventory'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             tooltip: 'Fetch Mascots',
//             onPressed: () {
//               setState(() {
//                 // Replace the selection with:
//                 // fetch the user's mascots from Firestore

//                 // Future<List<int>> mascots = getCaughtMascotsOfUser(
//                 //   CurrentUser.user!.username
//                 // )
//                 _loadUserMascots()
//                     .then((_) {
//                       setState(() {}); // rebuild after fetch
//                       if (!CurrentUser.isLoggedIn) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text(
//                               'Please log in to fetch mascots from your inventory',
//                             ),
//                           ),
//                         );
//                         return;
//                       }
//                       if (mascots.isEmpty) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(content: Text('No mascots found')),
//                         );
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text('Fetched ${mascots.length} mascots'),
//                           ),
//                         );
//                       }
//                     })
//                     .catchError((e) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Failed to fetch mascots: $e')),
//                       );
//                     });
//               });

//               // print('Mascots list updated. Total mascots: ${mascots.length}');
//             },
//           ),
//         ],
//       ),

//       body:
//           CurrentUser.isLoggedIn == false
//               ? const Center(
//                 child: Text('Please log in to view your inventory.'),
//               )
//               :
//               //shows a list of added mascots in this session
//               mascots.isEmpty
//               ? const Center(child: Text('No mascots available.'))
//               : Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Coins display
//                   Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Text(
//                       'Coins: ${CurrentUser.user!.coins}',
//                       style: Theme.of(context).textTheme.titleLarge,
//                     ),
//                   ),

//                   // Mascot list
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: mascots.length,
//                       itemBuilder: (context, index) {
//                         final mascot = mascots[index];
//                         print('Displaying mascot: ${mascot.mascotName}');
//                         print(
//                           'Details: ID=${mascot.mascotId}, PI=${mascot.piId}, Rarity=${mascot.rarity}, Respawn=${mascot.respawnTime}, Coins=${mascot.coins}',
//                         );
//                         //get mascot image path
//                         // String mascotImagePath = await getMascotPath(mascot.mascotId);
//                         String mascotImagePath =
//                             'lib/assets/mascotimages/${mascot.mascotId}_${mascot.mascotName}.png';
//                         //get the image width and height
//                         double width = 56;
//                         double height = 56;
//                         return ListTile(
//                           leading: SizedBox(
//                             width: 56,
//                             height: 56,
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.asset(
//                                 mascotImagePath,
//                                 fit: BoxFit.cover, // crop nicely
//                                 errorBuilder: (context, error, stackTrace) {
//                                   return const Icon(
//                                     Icons.image_not_supported,
//                                     size: 40,
//                                   );
//                                 },
//                               ),
//                             ),
//                           ),

//                           title: Text('Name: ${mascot.mascotName}'),
//                           subtitle: Text(
//                             'ID: ${mascot.mascotId}\n'
//                             'Location: ${mascot.piId}\n'
//                             'Rarity: ${mascot.rarity}',
//                           ),
//                           trailing: Text(
//                             'Respawn: ${mascot.respawnTime} min\n'
//                             'Coins: ${mascot.coins}',
//                             textAlign: TextAlign.right,
//                           ),
//                           isThreeLine: true,
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//     );
//   }
// }

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

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load inventory: $e')));
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
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load coins: $e')));
    }
  }

  Color _rarityColor(double rarity) {
    if (rarity < 0.2) {
      return Colors.grey; // Common
    } else if (rarity < 0.4) {
      return Colors.green; // Uncommon
    } else if (rarity < 0.6) {
      return Colors.blue; // Rare
    } else if (rarity < 0.8) {
      return Colors.purple; // Epic
    } else {
      return Colors.orange; // Legendary
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${username[0].toUpperCase()}${username.substring(1)}'s Mascotarium"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserMascots,
          ),
        ],
      ),
      body:
          !CurrentUser.isLoggedIn
              ? const Center(
                child: Text('Please log in to view your inventory.'),
              )
              : mascots.isEmpty
              ? const Center(child: Text('No mascots caught yet!'))
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coins header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on),
                        const SizedBox(width: 8),
                        Text(
                          'Coins: ${CurrentUser.user!.coins}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),

                  // Pokédex grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: mascots.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                      itemBuilder: (context, index) {
                        final mascot = mascots[index];
                        final mascotImagePath =
                            'lib/assets/mascotimages/${mascot.mascotId}_${mascot.mascotName}.png';

                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                // Image
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      mascotImagePath,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Name
                                Text(
                                  mascot.mascotName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 4),

                                // Rarity badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _rarityColor(
                                      mascot.rarity,
                                    ).withOpacity(0.15),
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

                                // Stats
                                Text(
                                  '🪙 ${mascot.coins}   ⏱ ${mascot.respawnTime}m',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
