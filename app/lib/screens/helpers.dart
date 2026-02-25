// a file with helper functions for mascot details
// import with the command import 'package:app/screens/helpers.dart';

import 'package:flutter/material.dart';

//define the game constants here so they can be easily tweaked and accessed across the app
int getdailyReward() => 5; //number of coins awarded for daily check-in
int get startingCoins => 5; //number of coins new users start with
int get changeLocationReward =>
    2; //number of coins awarded for visiting a different location
int get newLocationReward =>
    6; //number of coins awarded for visiting a location for the first time

// int dailyReward = 5; //number of coins awarded for daily check-in
// int startingCoins = 5; //number of coins new users start with
// int changeLocationReward =
//     2; //number of coins awarded for visiting a different location
// int newLocationReward =
//     3; //number of coins awarded for visiting a location for the first time

//less rarity -> more common
Color getRarityColor(double rarity) {
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

String getRarityTier(double rarity) {
  if (rarity < 0.2) {
    return "Common";
  } else if (rarity < 0.4) {
    return "Uncommon";
  } else if (rarity < 0.6) {
    return "Rare";
  } else if (rarity < 0.8) {
    return "Epic";
  } else {
    return "Legendary";
  }
}
