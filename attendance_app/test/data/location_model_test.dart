import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/data/models/location_model.dart';
import 'package:attendance_app/data/models/user_model.dart';

void main() {
  test('fromMap reads a site document', () {
    final s = LocationModel.fromMap({
      'name': 'Head office',
      'address': 'MG Road',
      'latitude': 12.97,
      'longitude': 77.59,
      'radius': 150,
      'isMain': true,
    }, 'hq');
    expect(s.id, 'hq');
    expect(s.radius, 150.0);
    expect(s.isMain, isTrue);
    expect(s.isLegacy, isFalse);
  });

  test('legacy zone becomes an id-less site named by its address', () {
    final s = LocationModel.legacy({
      'latitude': 1,
      'longitude': 2,
      'radius': 80,
      'address': 'Old office',
    });
    expect(s.isLegacy, isTrue);
    expect(s.name, 'Old office');
    expect(
      LocationModel.legacy({'latitude': 1, 'longitude': 2}).name,
      'Work location',
    );
  });

  test('toZone mirrors the legacy workLocation shape', () {
    const s = LocationModel(
      id: 'wh',
      name: 'Warehouse',
      latitude: 1,
      longitude: 2,
      radius: 200,
    );
    expect(s.toZone(), {
      'latitude': 1.0,
      'longitude': 2.0,
      'radius': 200.0,
      'address': 'Warehouse',
    });
  });

  test('employees without sites read as an empty assignment', () {
    final u = UserModel.fromMap({'name': 'A'}, 'u1');
    expect(u.locationIds, isEmpty);
    expect(u.primaryLocationId, isNull);
    final v = UserModel.fromMap({
      'name': 'B',
      'locationIds': ['a', 'b'],
      'primaryLocationId': 'b',
    }, 'u2');
    expect(v.locationIds, ['a', 'b']);
    expect(v.primaryLocationId, 'b');
  });
}
