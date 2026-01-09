//screen to test apis

import 'package:app/models/mascot.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import '../utils/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:app/apis/mascot_api.dart';

class ApiTestScreen extends StatefulWidget {
  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  //   ApiTestScreen({super.key});

  var nameController = TextEditingController();
  var mascIDController = TextEditingController();
  var rarityController = TextEditingController();
  var piIDController = TextEditingController();
  var respawnTimeController = TextEditingController();
  var coinsController = TextEditingController();

  final List<Mascot> mascots = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch Mascots',
            onPressed: () {
              setState(() {
                // Replace the selection with:
                getMascots(mascots)
                    .then((_) {
                      setState(() {}); // rebuild after fetch
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
          //shows a list of added mascots in this session
          mascots.isEmpty
              ? const Center(child: Text('No mascots available.'))
              : ListView.builder(
                itemCount: mascots.length,
                itemBuilder: (context, index) {
                  final mascot = mascots[index];
                  return ListTile(
                    title: Text(
                      'Name: ${mascot.mascotName}, ID: ${mascot.mascotId.toString()}',
                    ),
                    subtitle: Text(
                      'Location: ${mascot.piId}, Rarity: ${mascot.rarity}',
                    ),
                    trailing: Text(
                      'Respawn: ${mascot.respawnTime} min\nCoins: ${mascot.coins}',
                    ),
                  );
                },
              ),

      //button to add a mascot
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Add Mascot'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,

                    //input text fields for mascot details
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Mascot Name',
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: mascIDController,
                        decoration: const InputDecoration(
                          hintText: 'Mascot ID',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: rarityController,
                        decoration: const InputDecoration(hintText: 'Rarity'),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: piIDController,
                        decoration: const InputDecoration(hintText: 'PI ID'),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: respawnTimeController,
                        decoration: const InputDecoration(
                          hintText: 'Respawn Time (min)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: coinsController,
                        decoration: const InputDecoration(
                          hintText: 'Coins to Challenge',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      //display the highest mascotId
                      SizedBox(height: 10),
                      FutureBuilder<int>(
                        future: MascotStorageService().getHighestMascotId(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            );
                          } else {
                            final highestId = snapshot.data ?? 0;
                            return Text(
                              'Next Mascot ID: ${highestId + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  //buttons to cancel or add mascot
                  actions: [
                    //cancel button
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("Cancel"),
                    ),

                    //add button
                    ElevatedButton(
                      onPressed: () async {
                        //validate inputs
                        if (nameController.text.isEmpty ||
                            mascIDController.text.isEmpty ||
                            rarityController.text.isEmpty ||
                            piIDController.text.isEmpty ||
                            respawnTimeController.text.isEmpty ||
                            coinsController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields'),
                            ),
                          );
                          return;
                        }

                        String name = nameController.text.trim();
                        int mascID = int.parse(mascIDController.text.trim());
                        double rarity = double.parse(
                          rarityController.text.trim(),
                        );
                        int piID = int.parse(piIDController.text.trim());
                        int respawnTime = int.parse(
                          respawnTimeController.text.trim(),
                        );
                        int coins = int.parse(coinsController.text.trim());
                        // print("trying to add mascot: $name, $mascID, $rarity, $piID, $respawnTime");

                        //validate rarity
                        if (rarity < 0.0 || rarity > 1.0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Rarity must be between 0.0 and 1.0',
                              ),
                            ),
                          );
                          return;
                        }

                        Mascot newMascot = Mascot(
                          name,
                          mascID,
                          rarity,
                          piID,
                          respawnTime,
                          coins,
                        );

                        //add mascot to firestore
                        await addMascot(newMascot, context, mascots);
                        // print("after mascot added to firestore");

                        //when a property of a stateless widget changes, we need to call
                        //setState to rebuild the widget with the new data
                        setState(() {});

                        //clear text fields
                        // nameController.clear();
                        // mascIDController.clear();
                        // rarityController.clear();
                        // piIDController.clear();
                        // respawnTimeController.clear();

                        Navigator.pop(context);
                      },
                      child: const Text('Add'),
                    ),

                    //add with auto ID button
                    ElevatedButton(
                      onPressed: () async {
                        //validate inputs
                        if (nameController.text.isEmpty ||
                            rarityController.text.isEmpty ||
                            piIDController.text.isEmpty ||
                            respawnTimeController.text.isEmpty ||
                            coinsController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in missing fields'),
                            ),
                          );
                          return;
                        }

                        String name = nameController.text.trim();
                        // int mascID = int.parse(mascIDController.text.trim());
                        double rarity = double.parse(
                          rarityController.text.trim(),
                        );
                        int piID = int.parse(piIDController.text.trim());
                        int respawnTime = int.parse(
                          respawnTimeController.text.trim(),
                        );
                        int coins = int.parse(coinsController.text.trim());
                        // print("trying to add mascot: $name, $mascID, $rarity, $piID, $respawnTime");

                        // Mascot newMascot = Mascot(
                        //   name,
                        //   mascID,
                        //   rarity,
                        //   piID,
                        //   respawnTime,
                        //   coins,
                        // );

                        //validate rarity
                        if (rarity < 0.0 || rarity > 1.0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Rarity must be between 0.0 and 1.0',
                              ),
                            ),
                          );
                          return;
                        }

                        Mascot newMascot = await createMascot(
                          name,
                          rarity,
                          piID,
                          respawnTime,
                          coins,
                        );

                        //add mascot to firestore
                        await addMascot(newMascot, context, mascots);
                        // print("after mascot added to firestore");

                        //when a property of a stateless widget changes, we need to call
                        //setState to rebuild the widget with the new data
                        setState(() {});

                        //clear text fields
                        // nameController.clear();
                        // mascIDController.clear();
                        // rarityController.clear();
                        // piIDController.clear();
                        // respawnTimeController.clear();

                        Navigator.pop(context);
                      },
                      child: const Text('Add with Auto ID'),
                    ),

                    //change values button (set values from text fields to mascot with given ID)
                    // ElevatedButton(
                    //   onPressed: () async {
                    //     //validate inputs
                    //     if (mascIDController.text.isEmpty) {
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         const SnackBar(
                    //           content: Text('Please enter Mascot ID'),
                    //         ),
                    //       );
                    //       return;
                    //     }

                    //     int mascId = int.parse(mascIDController.text.trim());

                    //     String? name =
                    //         nameController.text.isEmpty
                    //             ? null
                    //             : nameController.text.trim();
                    //     // double? rarity =
                    //     //     rarityController.text.isEmpty
                    //     //         ? null
                    //     //         : double.parse(rarityController.text.trim());
                    //     // int? piID =
                    //     //     piIDController.text.isEmpty
                    //     //         ? null
                    //     //         : int.parse(piIDController.text.trim());
                    //     // int? respawnTime =
                    //     //     respawnTimeController.text.isEmpty
                    //     //         ? null
                    //     //         : int.parse(respawnTimeController.text.trim());
                    //     // int? coins =
                    //     //     coinsController.text.isEmpty
                    //     //         ? null
                    //     //         : int.parse(coinsController.text.trim());

                    //     //   await setMascotValues(
                    //     //     mascID,
                    //     //     name,
                    //     //     rarity,
                    //     //     piID,
                    //     //     respawnTime,
                    //     //     coins,
                    //     //     context,
                    //     //   );

                    //     if (name != null) {
                    //       await setMascotName(mascId, name, context);
                    //     }

                    //     setState(() {});

                    //     Navigator.pop(context);
                    //   },
                    //   child: const Text('Set mascot values'),
                    // ),
                  ],
                ),
          );
        },
        child: const Icon(Icons.add),
      ),

      //another button to test mascot getter by id
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Get Mascot by ID'),
                    content: TextField(
                      controller: mascIDController,
                      decoration: const InputDecoration(hintText: 'Mascot ID'),
                      keyboardType: TextInputType.number,
                    ),
                    actions: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          int mascID = int.parse(mascIDController.text.trim());
                          Mascot? fetchedMascot = await getMascot(
                            mascID,
                            context,
                          );
                          if (fetchedMascot != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Fetched Mascot: ${fetchedMascot.mascotName}, ID: ${fetchedMascot.mascotId}, Rarity: ${fetchedMascot.rarity}, PI ID: ${fetchedMascot.piId}, Respawn: ${fetchedMascot.respawnTime}, Coins: ${fetchedMascot.coins}',
                                ),
                              ),
                            );
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('Fetch'),
                      ),
                    ],
                  ),
            );
          },
          child: const Text('Fetch Mascot by ID'),
        ),
      ),
    );
  }
}
