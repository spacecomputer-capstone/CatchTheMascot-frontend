import 'package:flutter/material.dart';

class MapEdgeGradientOverlay extends StatelessWidget {
  const MapEdgeGradientOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black26,
              Colors.transparent,
              Colors.transparent,
              Colors.black38,
            ],
            stops: [0.0, 0.25, 0.7, 1.0],
          ),
        ),
      ),
    );
  }
}
