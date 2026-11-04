import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._db);

  final DatabaseService _db;

  @override
  Stream<List<LocationModel>> watchLocations(String companyId) =>
      _db.watchLocations(companyId);

  @override
  Future<List<LocationModel>> getLocations(String companyId) =>
      _guard(() => _db.getLocationsOnce(companyId));

  @override
  Future<String> saveLocation(
    String companyId,
    LocationModel location, {
    List<LocationModel> sites = const [],
  }) => _guard(() => _db.saveLocation(companyId, location, sites: sites));

  @override
  Future<void> deleteLocation(String companyId, String locationId) =>
      _guard(() => _db.deleteLocation(companyId, locationId));

  @override
  Future<void> assignLocations(
    String companyId,
    String employeeId, {
    required List<String> locationIds,
    LocationModel? primary,
  }) => _guard(
    () => _db.assignLocations(
      companyId,
      employeeId,
      locationIds: locationIds,
      primary: primary,
    ),
  );

  @override
  Future<int> migrateLegacyLocations(String companyId) =>
      _guard(() => _db.migrateLegacyLocations(companyId));

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
