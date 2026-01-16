import 'package:flutter/material.dart';
import 'small_icon_button.dart';

class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // only as big as children
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SmallIconButton(icon: Icons.add, onTap: onZoomIn),
            const SizedBox(height: 8),
            SmallIconButton(icon: Icons.remove, onTap: onZoomOut),
          ],
        ),
      ),
    );
  }
}
