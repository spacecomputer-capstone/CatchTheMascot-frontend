// User Model
class User {
  String username;
  String password; //TODO: Hash password before storing
  List<String> caughtMascots; //list of mascotIds as references
  List<String> uncaughtMascots; //list of mascotIds as references
  List<int> visitedPis; //list of piIds
  int coins;

  User(
    this.username,
    this.password,
    this.caughtMascots,
    this.uncaughtMascots,
    this.visitedPis,
    this.coins,
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
      List<String>.from(map['caughtMascots']),
      List<String>.from(map['uncaughtMascots']),
      List<int>.from(map['visitedPis']),
      map['coins'],
    );
  }
}
