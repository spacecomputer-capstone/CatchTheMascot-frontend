// User Model
class User {
  String username;
  String password; //TODO: Hash password before storing
  List<int> caughtMascots; //list of mascotIds as references
  List<int> uncaughtMascots; //list of mascotIds as references
  List<int> visitedPis; //list of piIds
  int coins; //in-game currency

  User(
    this.username,
    this.password,
    this.caughtMascots, //mascots caught by the user
    this.uncaughtMascots, //mascots that have been challenged but not yet caught
    this.visitedPis, //pis that the user has physically visited
    this.coins, //in-game currency
  );

  static toMap(User user) {
    return {
      'username': user.username,
      'password': user.password,
      'caughtMascots': user.caughtMascots,
      'uncaughtMascots': user.uncaughtMascots,
      'visitedPis': user.visitedPis,
      'coins': user.coins,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      map['username'],
      map['password'],
      List<int>.from(map['caughtMascots']),
      List<int>.from(map['uncaughtMascots']),
      List<int>.from(map['visitedPis']),
      map['coins'],
    );
  }
}
