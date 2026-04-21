class FirestorePaths {
  const FirestorePaths._();

  static const String users = 'users';
  static const String needs = 'needs';
  static const String resources = 'resources';
  static const String allocations = 'allocations';
  static const String insights = 'insights';

  static String user(String uid) => '$users/$uid';
  static String need(String needId) => '$needs/$needId';
  static String resource(String resourceId) => '$resources/$resourceId';
  static String allocation(String allocationId) => '$allocations/$allocationId';
}
