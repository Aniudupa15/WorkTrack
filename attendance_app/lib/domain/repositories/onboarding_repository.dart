/// Self-serve company signup, joining a team, and inviting people.
abstract interface class OnboardingRepository {
  /// Makes the signed-in (email) user the admin of a new company on a trial.
  /// Returns the new company's id.
  Future<String> registerCompany({
    required String companyName,
    required String adminName,
    required List<Map<String, dynamic>> locations,
    required String shiftStart,
    required String shiftEnd,
    String? teamSize,
    String? industry,
    String? gstin,
    List<int> workingDays,
    int lateAfterMinutes,
    bool checkoutInZone,
    bool shiftReminders,
    bool selfieRequired,
  });

  /// Joins the signed-in user to a company by a phone invite (no [code]) or by
  /// the company's join [code]. Returns the company and the new employee status: `active`, or
  /// `pending` when the company approves joiners.
  Future<({String companyId, String status})> claimJoin({
    String? code,
    String? name,
    String? email,
    String? employeeNumber,
  });

  /// Invites people by phone. Each row: name, phone, and optionally
  /// department, position, location (site names joined by `;`), shiftStart,
  /// shiftEnd.
  Future<ImportResult> importEmployees(
    String companyId,
    List<Map<String, dynamic>> rows,
  );

  /// Replaces the company's join code; returns the new one.
  Future<String> resetJoinCode(String companyId);

  /// Deletes the signed-in employee's profile, membership and login.
  Future<void> deleteMyAccount();
}

class ImportResult {
  const ImportResult({
    required this.created,
    required this.updated,
    required this.errors,
  });

  final int created;
  final int updated;

  /// Row index (into the submitted rows) → why it was skipped.
  final Map<int, String> errors;
}
