## Documentation for user API

#### Code for user API is located in:
- API functions: \CatchTheMascot-frontend\app\lib\apis\user_api.dart
- user class definition: CatchTheMascot-frontend\app\lib\models\user.dart
- testing: CatchTheMascot-frontend\app\lib\screens\99_user_api_test_screen.dart
    - to test, set debug bool to true in CatchTheMascot-frontend\app\lib\screens\1_home_screen.dart

#### User Info
- user has fields:
  String username;
  String password; //TODO: Hash password before storing
  List<String> caughtMascots; //list of mascotIds as references
  List<String> uncaughtMascots; //list of mascotIds as references
  List<int> visitedPis; //list of piIds
  int coins; //number of coins (in-game currency) a user has

#### API Quickstart
1. import API code
    `import 'package:app/apis/user_api.dart';`
    `import 'package:app/models/user.dart';`

*the following are in no particular order*
2. to add a user to the database: 
    1. create a user: `User newUser = User(String username, String password, List<String> caughtMascots, List<String> uncaughtMascots, List<int> visitedPis, int coins, );`
    2. add user: `await addUser(newUser, context);`
3. login (check that username and password match):
    `Future<bool> loginUser(String username, String password, BuildContext context,)`
    - returns true if login is successful (username and password match)
    - returns false if username and password do not match
4. get user data from username:
    `Future<User?> fetchUserByUsername(String username)`
5. add or remove a caught mascot:
    `Future<void> updateCaughtMascot({ required String username, required int mascotId, bool addOrRemove = true, })`
    - addOrRemove: true = add, false = remove
6. add or remove a uncaught mascot:
    `Future<void> updateUncaughtMascot({ required String username, required int mascotId, bool addOrRemove = true, })`
    - addOrRemove: true = add, false = remove
7. add or remove a visited pi:
    `Future<void> updateVisitedPi({ required String username, required int piId, bool addOrRemove = true, })`
    - addOrRemove: true = add, false = remove
8. update the number of coins a user has:
    `Future<void> updateUserCoins({ required String username, required int coinsToAdd,})`
    - coinsToAdd can be negative to subtract coins
    - total resulting coins cannot go below 0 -> will return an exception 'Insufficient coins...'
