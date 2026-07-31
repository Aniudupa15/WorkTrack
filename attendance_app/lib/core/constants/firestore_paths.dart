/// Single source of truth for every Firestore collection and document path.
///
/// Keeping these here (instead of inline strings scattered across the data
/// layer) means the schema in `firestore.rules` and the client agree on
/// exactly one set of names, and a schema change is a one-line edit.
class FirestorePaths {
  const FirestorePaths._();

  static const String companies = 'companies';
  static const String users = 'users';
  static const String notifications = 'notifications';

  static const String employees = 'employees';
  static const String attendance = 'attendance';
  static const String leaves = 'leaves';
}
