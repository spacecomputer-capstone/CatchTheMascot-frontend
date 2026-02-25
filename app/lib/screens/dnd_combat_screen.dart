import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app/models/mascot.dart';
import 'package:app/state/current_user.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'mascot-database',
);

enum EntityType { player, bull, cow, horse, enemy }

class CombatEntity {
  final String name;
  final EntityType type;
  int hp;
  final int maxHp;

  bool isLethargic = false;
  int lethargicTurnsLeft = 0;

  bool isHasted = false;
  int hastedTurnsLeft = 0;
  int hasteDuration = 0; // to track when to become lethargic

  bool isFrightened = false;
  bool isPoisoned = false;

  CombatEntity({
    required this.name,
    required this.type,
    required this.hp,
    required this.maxHp,
  });
}

class DndCombatScreen extends StatefulWidget {
  final Mascot mascot;

  const DndCombatScreen({Key? key, required this.mascot}) : super(key: key);

  @override
  State<DndCombatScreen> createState() => _DndCombatScreenState();
}

class _DndCombatScreenState extends State<DndCombatScreen> {
  late CombatEntity player;
  CombatEntity? activeAlly;
  late CombatEntity enemy;

  List<String> combatLog = [];
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  bool isPlayerTurn = true;
  bool isGameOver = false;

  int playerActionsLeft = 1;

  int enemyMasks = 0; // For Raccoon's obfuscation

  @override
  void initState() {
    super.initState();
    player = CombatEntity(
      name: 'Gaucho',
      type: EntityType.player,
      hp: 100,
      maxHp: 100,
    );

    String mName = widget.mascot.mascotName.toLowerCase();
    if (mName == 'storky') {
      enemy = CombatEntity(
        name: 'Storkey',
        type: EntityType.enemy,
        hp: 250,
        maxHp: 250,
      );
    } else if (mName == 'mascot_4') {
      enemy = CombatEntity(
        name: 'Oil Rig',
        type: EntityType.enemy,
        hp: 200,
        maxHp: 200,
      );
    } else if (mName == 'mascot_1') {
      enemy = CombatEntity(
        name: 'Raccoon',
        type: EntityType.enemy,
        hp: 150,
        maxHp: 150,
      );
    } else {
      enemy = CombatEntity(
        name: widget.mascot.mascotName,
        type: EntityType.enemy,
        hp: 100,
        maxHp: 100,
      );
    }

    _log('Encountered ${enemy.name}! Combat initiated.');
    _startTurn();
  }

  void _log(String message) {
    setState(() {
      combatLog.add(message);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int _rollDice(int sides) {
    return _random.nextInt(sides) + 1;
  }

  void _startTurn() {
    if (isGameOver) return;

    if (isPlayerTurn) {
      // Handle Player/Ally turn status effects
      _applyStatusEffects(player);
      if (activeAlly != null) _applyStatusEffects(activeAlly!);

      playerActionsLeft = player.isHasted ? 2 : 1;
      
      if (player.isLethargic) {
        _log('${player.name} is lethargic and must skip a turn!');
        playerActionsLeft = 0;
      } else if (player.isFrightened) {
        _log('${player.name} is frightened and has disadvantage!');
      }

      if (player.hp <= 0) {
        _endCombat(false);
        return;
      }

      if (playerActionsLeft <= 0) {
        _endPlayerTurn();
      }
    } else {
      // Enemy turn
      _applyStatusEffects(enemy);
      if (enemy.hp <= 0) {
        _endCombat(true);
        return;
      }
      _enemyTurnAction();
    }
  }

  void _applyStatusEffects(CombatEntity entity) {
    if (entity.isPoisoned) {
      int poisonDmg = _rollDice(4);
      entity.hp -= poisonDmg;
      _log('${entity.name} takes $poisonDmg poison damage.');
    }

    if (entity.isHasted) {
      entity.hastedTurnsLeft--;
      entity.hasteDuration++;
      if (entity.hasteDuration >= 10) {
        entity.isHasted = false;
        entity.isLethargic = true;
        entity.lethargicTurnsLeft = 1; // Lethargic for 1 turn as an example
        _log('${entity.name} haste wore off and became lethargic!');
      }
    }

    if (entity.isLethargic && entity.lethargicTurnsLeft > 0) {
      entity.lethargicTurnsLeft--;
      if (entity.lethargicTurnsLeft <= 0) {
        entity.isLethargic = false;
        _log('${entity.name} is no longer lethargic.');
      }
    }

    if (entity.isFrightened) {
      // Frightened usually lasts 1 turn, clearing it after their turn begins
      entity.isFrightened = false;
    }
  }

  void _playerActionLasso() {
    if (!isPlayerTurn || isGameOver || playerActionsLeft <= 0) return;

    if (enemyMasks > 0) {
      // Raccoon mask mechanic
      if (_random.nextDouble() < 0.33 * enemyMasks) {
        _log('${player.name} tried to lasso, but hit an obfuscation mask!');
        enemyMasks--;
        _useAction();
        return;
      }
    }

    int roll1 = _rollDice(10);
    int roll2 = _rollDice(10);
    int totalDmg = roll1 + roll2;

    if (enemy.name.toLowerCase() == 'storkey' || enemy.name.toLowerCase() == 'storky') {
      int advRoll1_1 = _rollDice(10);
      int advRoll1_2 = _rollDice(10);
      roll1 = max(advRoll1_1, advRoll1_2);

      int advRoll2_1 = _rollDice(10);
      int advRoll2_2 = _rollDice(10);
      roll2 = max(advRoll2_1, advRoll2_2);
      
      totalDmg = roll1 + roll2;
      _log('${player.name} uses Lasso with advantage: rolled $roll1 and $roll2!');
    } else if (player.isFrightened) {
      int disRoll1_1 = _rollDice(10);
      int disRoll1_2 = _rollDice(10);
      roll1 = min(disRoll1_1, disRoll1_2);

      int disRoll2_1 = _rollDice(10);
      int disRoll2_2 = _rollDice(10);
      roll2 = min(disRoll2_1, disRoll2_2);

      totalDmg = roll1 + roll2;
      _log('${player.name} uses Lasso with disadvantage: rolled $roll1 and $roll2.');
    } else {
      _log('${player.name} uses Lasso: rolled $roll1 and $roll2.');
    }

    _dealDamage(enemy, totalDmg);
    _useAction();
  }

  void _summonAlly(String allyName) {
    if (!isPlayerTurn || isGameOver || playerActionsLeft <= 0) return;

    if (allyName == 'Bull') {
      activeAlly = CombatEntity(name: 'Bull', type: EntityType.bull, hp: 130, maxHp: 130);
    } else if (allyName == 'Cow') {
      activeAlly = CombatEntity(name: 'Cow', type: EntityType.cow, hp: 130, maxHp: 130);
    } else if (allyName == 'Horse') {
      activeAlly = CombatEntity(name: 'Horse', type: EntityType.horse, hp: 130, maxHp: 130);
    }

    _log('${player.name} summoned $allyName!');
    _useAction();
  }

  void _allyAction() {
    if (!isPlayerTurn || isGameOver || activeAlly == null || playerActionsLeft <= 0) return;

    if (activeAlly!.type == EntityType.bull) {
      int dmg = _rollDice(10);
      _log('${activeAlly!.name} Charges! Dealing $dmg damage.');
      _dealDamage(enemy, dmg);
    } else if (activeAlly!.type == EntityType.cow) {
      int heal = _rollDice(15);
      player.hp = min(player.maxHp, player.hp + heal);
      _log('${activeAlly!.name} gives pail of milk! Heals ${player.name} for $heal HP.');
    } else if (activeAlly!.type == EntityType.horse) {
      if (!player.isHasted) {
        player.isHasted = true;
        player.hastedTurnsLeft = 10;
        player.hasteDuration = 0;
        _log('${activeAlly!.name} casts Haste on ${player.name}!');
      } else {
         _log('${activeAlly!.name} tries to cast Haste, but ${player.name} is already Hasted.');
      }
    }

    _useAction();
  }

  void _useAction() {
    setState(() {
      playerActionsLeft--;
    });

    if (enemy.hp <= 0) {
      _endCombat(true);
      return;
    }

    if (playerActionsLeft <= 0) {
      _endPlayerTurn();
    }
  }

  void _endPlayerTurn() {
    if (isGameOver) return;
    setState(() {
      isPlayerTurn = false;
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _startTurn();
    });
  }

  void _enemyTurnAction() {
    if (isGameOver) return;

    String mName = widget.mascot.mascotName.toLowerCase();
    
    // Choose target (player or active ally)
    CombatEntity target = player;
    if (activeAlly != null && _random.nextBool()) {
      target = activeAlly!;
    }
    
    if (mName == 'storky' || mName == 'storkey') {
      if (_random.nextDouble() < 0.30) {
        // Bells of doom
        _log('${enemy.name} uses Bells of Doom!');
        player.isFrightened = true;
        if (activeAlly != null) activeAlly!.isFrightened = true;
        _log('All enemies are now frightened!');
      } else {
        // Tower smash
        int dmg = _rollDice(20);
        _log('${enemy.name} uses Tower Smash on ${target.name} for $dmg damage!');
        _dealDamage(target, dmg);
      }
    } else if (mName == 'mascot_4') {
      // Oil Rig
       if (_random.nextDouble() < 0.50) {
         _log('${enemy.name} uses Global Warming!');
         target.isPoisoned = true;
         _log('${target.name} is now poisoned!');
       } else {
         int dmg = _rollDice(6);
         _log('${enemy.name} uses Gas Flame! Deals $dmg damage to all.');
         _dealDamage(player, dmg);
         if (activeAlly != null) _dealDamage(activeAlly!, dmg);
       }
    } else if (mName == 'mascot_1') {
      // Raccoon
      if (_random.nextDouble() < 0.40) {
        enemyMasks = 3;
        _log('${enemy.name} uses Obfuscation! Created 3 floating masks.');
      } else {
        int dmg = _rollDice(8) + 2; // base damage
        _log('${enemy.name} throws garbage at ${target.name} for $dmg damage!');
         _dealDamage(target, dmg);
      }
    } else {
       // Generic attack
       int dmg = _rollDice(8);
       _log('${enemy.name} attacks ${target.name} for $dmg damage!');
       _dealDamage(target, dmg);
    }

    if (player.hp <= 0) {
      _endCombat(false);
      return;
    }

    setState(() {
      isPlayerTurn = true;
    });
    // Add small delay for player turn
    Future.delayed(const Duration(milliseconds: 500), () {
      _startTurn();
    });
  }

  void _dealDamage(CombatEntity target, int amount) {
    if (amount <= 0) return;
    target.hp -= amount;
    if (target.hp < 0) target.hp = 0;

    if (target.hp <= 0 && target != player && target != enemy) {
      _log('${target.name} was defeated!');
      if (target == activeAlly) activeAlly = null;
    }
  }

  void _endCombat(bool win) {
    if (isGameOver) return;
    setState(() {
      isGameOver = true;
    });

    if (win) {
      _log('Combat Over! You defeated ${enemy.name} and caught it!');
      _saveCatchToBackend();
    } else {
      _log('Combat Over! You were defeated by ${enemy.name}. It escaped!');
    }

    Future.delayed(const Duration(seconds: 2), () {
      _showResultDialog(win);
    });
  }

  Future<void> _saveCatchToBackend() async {
    final u = CurrentUser.user;
    if (u == null) return;

    await _firestore.collection('users').doc(u.username).update({
      'caughtMascots': FieldValue.arrayUnion([widget.mascot.mascotId]),
    });
  }

  void _showResultDialog(bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.close_rounded,
                  size: 64,
                  color: success ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  success
                      ? 'You caught ${enemy.name}!'
                      : '${enemy.name} escaped!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    Navigator.of(context).pop(success);
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combat Encounter'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.black87,
        child: Column(
          children: [
            // Enemy Status
            _buildEntityPlate(enemy),
            const Divider(color: Colors.white54),

            // Ally Status (if active)
            if (activeAlly != null) ...[
               _buildEntityPlate(activeAlly!),
               const Divider(color: Colors.white54),
            ],

            // Player Status
            _buildEntityPlate(player),

            // Combat Log
            Expanded(
               child: Container(
                 margin: const EdgeInsets.all(8),
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Colors.black54,
                   border: Border.all(color: Colors.white30),
                   borderRadius: BorderRadius.circular(8)
                 ),
                 child: ListView.builder(
                   controller: _scrollController,
                   itemCount: combatLog.length,
                   itemBuilder: (context, index) {
                     return Padding(
                       padding: const EdgeInsets.symmetric(vertical: 2.0),
                       child: Text(
                         combatLog[index],
                         style: const TextStyle(color: Colors.white70, fontSize: 14),
                       ),
                     );
                   }
                 )
               )
            ),

            // Action Panel
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.indigo.shade900,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isGameOver ? 'Combat Ended' : (isPlayerTurn ? 'Your Turn (Actions: $playerActionsLeft)' : 'Enemy Turn...'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.line_style),
                        label: const Text('Lasso'),
                        onPressed: isPlayerTurn && !isGameOver && playerActionsLeft > 0 ? _playerActionLasso : null,
                      ),
                      if (activeAlly != null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.pets),
                          label: Text('${activeAlly!.name} Action'),
                           onPressed: isPlayerTurn && !isGameOver && playerActionsLeft > 0 ? _allyAction : null,
                        ),
                      if (activeAlly == null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Summon Bull'),
                          onPressed: isPlayerTurn && !isGameOver && playerActionsLeft > 0 ? () => _summonAlly('Bull') : null,
                        ),
                      if (activeAlly == null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Summon Cow'),
                          onPressed: isPlayerTurn && !isGameOver && playerActionsLeft > 0 ? () => _summonAlly('Cow') : null,
                        ),
                      if (activeAlly == null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Summon Horse'),
                           onPressed: isPlayerTurn && !isGameOver && playerActionsLeft > 0 ? () => _summonAlly('Horse') : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityPlate(CombatEntity ent) {
    double hpPct = ent.hp / ent.maxHp;
    Color healthColor = hpPct > 0.5 ? Colors.green : (hpPct > 0.2 ? Colors.orange : Colors.red);

    List<String> statuses = [];
    if (ent.isPoisoned) statuses.add('Poisoned');
    if (ent.isFrightened) statuses.add('Frightened');
    if (ent.isHasted) statuses.add('Hasted (${ent.hastedTurnsLeft})');
    if (ent.isLethargic) statuses.add('Lethargic');
    if (ent.name == 'Raccoon' && enemyMasks > 0) statuses.add('Masks: $enemyMasks');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   ent.name,
                   style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                 ),
                 if (statuses.isNotEmpty)
                    Text(
                      statuses.join(' | '),
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                    ),
                 const SizedBox(height: 8),
                 LinearProgressIndicator(
                   value: hpPct.clamp(0.0, 1.0),
                   backgroundColor: Colors.white24,
                   valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                   minHeight: 12,
                   borderRadius: BorderRadius.circular(6),
                 ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${ent.hp} / ${ent.maxHp}',
             style: const TextStyle(color: Colors.white, fontSize: 16),
          )
        ],
      ),
    );
  }
}
