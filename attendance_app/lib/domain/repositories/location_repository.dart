import 'package:attendance_app/data/models/location_model.dart';

/// Company work sites and which employees may punch at them.
abstract interface class LocationRepository {
  Stream<List<LocationModel>> watchLocations(String companyId);

  Future<List<LocationModel>> getLocations(String companyId);

  /// Creates (empty id) or updates a site; returns its id. [sites] is the
  /// company's current list, used to move the main-site flag.
  Future<String> saveLocation(
    String companyId,
    LocationModel location, {
    List<LocationModel> sites,
  });

  Future<void> deleteLocation(String companyId, String locationId);

  Future<void> assignLocations(
    String companyId,
    String employeeId, {
    required List<String> locationIds,
    LocationModel? primary,
  });

  /// Turns legacy per-employee work locations into company sites, once.
  Future<int> migrateLegacyLocations(String companyId);
}
