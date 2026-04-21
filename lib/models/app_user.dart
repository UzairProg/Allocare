import 'package:cloud_firestore/cloud_firestore.dart';

enum AppUserRole { admin, volunteer, ngo }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String phoneNumber;
  final AppUserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: (map['email'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      role: _roleFromString((map['role'] as String?) ?? 'volunteer'),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static AppUserRole _roleFromString(String raw) {
    if (raw == 'coordinator') {
      return AppUserRole.ngo;
    }

    return AppUserRole.values.firstWhere(
      (role) => role.name == raw,
      orElse: () => AppUserRole.volunteer,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
