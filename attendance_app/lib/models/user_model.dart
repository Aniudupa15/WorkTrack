class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final Map<String, double>? assignedLocation; // {lat, lng}
  final double? radius;
  final String? companyId;
  final String? shiftStart;
  final String? shiftEnd;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.assignedLocation,
    this.radius,
    this.companyId,
    this.shiftStart,
    this.shiftEnd,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'employee',
      assignedLocation: map['assignedLocation'] != null
          ? Map<String, double>.from(map['assignedLocation'])
          : null,
      radius: (map['radius'] as num?)?.toDouble(),
      companyId: map['companyId'],
      shiftStart: map['shiftStart'],
      shiftEnd: map['shiftEnd'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'assignedLocation': assignedLocation,
      'radius': radius,
      'companyId': companyId,
      'shiftStart': shiftStart,
      'shiftEnd': shiftEnd,
    };
  }
}
