import 'package:latlong2/latlong.dart';

class CompanyModel {
  final String id;
  final String name;
  final String adminId;
  final Map<String, double>? defaultLocation; // {lat, lng}
  final double defaultRadius;

  CompanyModel({
    required this.id,
    required this.name,
    required this.adminId,
    this.defaultLocation,
    this.defaultRadius = 100,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map, String id) {
    return CompanyModel(
      id: id,
      name: map['name'] ?? '',
      adminId: map['adminId'] ?? '',
      defaultLocation: map['defaultLocation'] != null
          ? Map<String, double>.from(map['defaultLocation'])
          : null,
      defaultRadius: (map['defaultRadius'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'adminId': adminId,
      'defaultLocation': defaultLocation,
      'defaultRadius': defaultRadius,
    };
  }
}
