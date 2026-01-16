//display caught mascots

import 'package:app/apis/user_api.dart';
import 'package:app/models/mascot.dart';
import 'package:flutter/material.dart';
import 'package:app/apis/mascot_api.dart';

class CaughtMascotsScreen extends StatefulWidget {
  const CaughtMascotsScreen({super.key});

  @override
  State<CaughtMascotsScreen> createState() => _CaughtMascotsScreenState();
}

class _CaughtMascotsScreenState extends State<CaughtMascotsScreen> {
  List<Mascot> caughtMascots = [];

  //get the list of caught mascots
  //TODO: where do we get the user data from? - from the login
  void loadCaughtMascots() async {
    var user = await fetchUserByUsername('testuser'); //TODO: replace with actual username
    List<int> mascotIds = user!.caughtMascots;
    List<Mascot> mascots = [];
    for (var id in mascotIds) {
      var mascot = await getMascot(id);
      if (mascot != null) {
        mascots.add(mascot);
      }
    }
    setState(() {
      caughtMascots = mascots;
    });
  }

  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }

  
  

}
