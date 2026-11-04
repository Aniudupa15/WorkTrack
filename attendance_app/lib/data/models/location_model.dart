/// A work site — stored under companies/{cid}/locations/{id}. Employees are
/// assigned one or more sites and may punch inside any of them.
class LocationModel {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isMain;

  const LocationModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 100,
    this.isMain = false,
  });

  /// An employee's pre-v2 single `workLocation`, which has no document of its
  /// own. Punches against it carry no locationId.
  factory LocationModel.legacy(Map<String, dynamic> zone) => LocationModel(
    id: '',
    name: (zone['address'] as String?)?.isNotEmpty == true
        ? zone['address'] as String
        : 'Work location',
    address: zone['address'] as String?,
    latitude: (zone['latitude'] as num).toDouble(),
    longitude: (zone['longitude'] as num).toDouble(),
    radius: (zone['radius'] as num?)?.toDouble() ?? 100,
  );

  factory LocationModel.fromMap(Map<String, dynamic> map, String id) =>
      LocationModel(
        id: id,
        name: map['name'] ?? '',
        address: map['address'],
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radius: (map['radius'] as num?)?.toDouble() ?? 100,
        isMain: map['isMain'] == true,
      );

  bool get isLegacy => id.isEmpty;

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'isMain': isMain,
  };

  /// The legacy `workLocation` shape, mirrored onto employees so app versions
  /// before multi-site keep punching against their primary site.
  Map<String, dynamic> toZone() => {
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'address': address ?? name,
  };

  LocationModel copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isMain,
  }) => LocationModel(
    id: id,
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radius: radius ?? this.radius,
    isMain: isMain ?? this.isMain,
  );
}
