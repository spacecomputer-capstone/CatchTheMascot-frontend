// a file with helper functions for mascot details
// import with the command import 'package:app/screens/helpers.dart';

import 'package:flutter/material.dart';

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
