// User Model
class User {
  String username;
  String password; //TODO: Hash password before storing
  List<int> caughtMascots; //list of mascotIds as references
  List<int> uncaughtMascots; //list of mascotIds as references
  List<int> visitedPis; //list of piIds
  int coins; //in-game currency
  int lastPiVisited;
  DateTime lastCheckInDate; //to track daily check-ins

  User(
    this.username,
    this.password,
    this.caughtMascots, //mascots caught by the user
    this.uncaughtMascots, //mascots that have been challenged but not yet caught
    this.visitedPis, //pis that the user has physically visited
    this.coins, //in-game currency
    this.lastPiVisited, //the last pi the user visited, used for check-in rewards
    this.lastCheckInDate, //the last date the user checked in, used for daily rewards
  );

  static toMap(User user) {
    return {
      'username': user.username,
      'password': user.password,
      'caughtMascots': user.caughtMascots,
      'uncaughtMascots': user.uncaughtMascots,
      'visitedPis': user.visitedPis,
      'coins': user.coins,
      'lastPiVisited': user.lastPiVisited,
      'lastCheckInDate': user.lastCheckInDate.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      map['username'] ?? '',
      map['password'] ?? '',
      List<int>.from((map['caughtMascots'] ?? []).map((e) => e as int)),
      List<int>.from((map['uncaughtMascots'] ?? []).map((e) => e as int)),
      List<int>.from(map['visitedPis'] ?? []),
      map['coins'] ?? 0,
      map['lastPiVisited'] ?? 0,
      DateTime.parse(map['lastCheckInDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}
