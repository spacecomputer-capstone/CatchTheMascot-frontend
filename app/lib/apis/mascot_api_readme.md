## Documentation for mascot API

#### Code for mascot API is located in:
- API functions: \CatchTheMascot-frontend\app\lib\apis\mascot_api.dart
    - more functions (unused): CatchTheMascot-frontend\app\lib\apis\unused_api.dart
- Mascot class and persistent local storage definition: CatchTheMascot-frontend\app\lib\models\mascot.dart
- testing: CatchTheMascot-frontend\app\lib\screens\99_api_test_screen.dart

#### Mascot Info
- mascot has fields:
  String mascotName; //common name of the mascot
  int mascotId; //unique identifier - each mascot has a unique mascotId, but other attributes can be the same
  double rarity; //0.0 to 1.0, the lower the rarer
  int piId; //the pi that this mascot belongs to
  int respawnTime; //in minutes
  int coins; //coins to challenge

#### API Quickstart
1. import API code
    `import 'package:app/apis/mascot_api.dart';`
    `import 'package:app/models/mascot.dart';`
2. before using the mascot API, load the mascots once - this can be done in main.dart, before running the app (this saves the highest mascotId locally)
    `List<Mascot> mascots = [];`
    `await getMascots(mascots);`

*the following are in no particular order*
3. to add a mascot to the database:
    1. create a mascot: `createMascot(String mascotName, double rarity, int piId, int respawnTime, int coins,)`
    2. add mascot: `addMascot(Mascot mascot, BuildContext context, List<Mascot>? mascots)`
        - list of mascots is optional to locally store all added mascots
4. to get a list of all mascots:
    `Future<void> getMascots(List<Mascot> mascots)`
5. to get a mascot object by mascotId (context is optional for pop up messages, pass in null if not using):
    `getmascot(int mascotId, [BuildContext? context])`
6. to set mascot fields (by mascotId, all fields all optional except mascotId)
    `setMascot(int mascotId, String? newName, double? newRarity, int newPiId, int? newRespawnTime, int? newCoins, [BuildContext? context,])`
7. to delete a mascot (by mascotId)
    `deleteMascot(int mascotId, List<Mascot>? mascots, [BuildContext? context,])`
*example code can be found in CatchTheMascot-frontend\app\lib\screens\99_api_test_screen.dart*