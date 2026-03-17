enum UpdateResult {
  none,
  optional,
  force;

  String get value => name;

  static UpdateResult from(String? raw) {
    switch (raw) {
      case 'force':
        return UpdateResult.force;
      case 'optional':
        return UpdateResult.optional;
      default:
        return UpdateResult.none;
    }
  }
}
