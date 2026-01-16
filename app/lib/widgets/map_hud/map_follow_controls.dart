import 'package:flutter/material.dart';
import 'small_icon_button.dart';
import 'map_player_pill.dart';

class MapFollowControls extends StatelessWidget {
  const MapFollowControls({
    super.key,
    required this.isAutoFollow,
    required this.onRecenter,
    required this.onToggleFollow,
    this.playerName = "You",
    this.playerSubtitle = "Lv. 1 • 0.0 km walked",
    this.onPlayerPillTap,
  });

  final bool isAutoFollow;
  final VoidCallback onRecenter;
  final VoidCallback onToggleFollow;

  final String playerName;
  final String playerSubtitle;
  final VoidCallback? onPlayerPillTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SmallIconButton(
                    icon: Icons.my_location,
                    onTap: onRecenter,
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 0.5,
                    color: Colors.white24,
                  ),
                  SmallIconButton(
                    icon: isAutoFollow ? Icons.lock : Icons.open_with,
                    onTap: onToggleFollow,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MapPlayerPill(
              name: playerName,
              subtitle: playerSubtitle,
              onTap: onPlayerPillTap,
            ),
          ],
        ),
      ),
    );
  }
}
