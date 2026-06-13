import 'package:cloud_firestore/cloud_firestore.dart';

import 'ngo_inventory_item.dart';

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
    this.ngoId,
    this.inventoryItems = const [],
    this.savedInsights = const [],
  });

  final String id;
  final String email;
  final String displayName;
  final String phoneNumber;
  final AppUserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Reference to `ngos/{ngoId}` — not embedded NGO data.
  final String? ngoId;

  final List<NgoInventoryItem> inventoryItems;
  final List<String> savedInsights;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final source = (map['ngoProfile'] as Map?)?.cast<String, dynamic>() ?? map;

    return AppUser(
      id: id,
      email: (source['email'] as String?) ?? '',
      displayName: (source['displayName'] as String?) ?? '',
      phoneNumber: (source['phoneNumber'] as String?) ?? '',
      role: _roleFromString((source['role'] as String?) ?? 'volunteer'),
      createdAt: _asDateTime(source['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(source['updatedAt']) ?? DateTime.now(),
      ngoId: (map['ngoId'] as String?)?.trim().isNotEmpty == true
          ? (map['ngoId'] as String).trim()
          : null,
      inventoryItems: (source['inventoryItems'] as List<dynamic>?)
              ?.map((entry) {
                final entryMap = (entry as Map).cast<String, dynamic>();
                return NgoInventoryItem.fromMap(
                  (entryMap['id'] as String?)?.trim().isNotEmpty ?? false
                      ? (entryMap['id'] as String).trim()
                      : DateTime.now().microsecondsSinceEpoch.toString(),
                  entryMap,
                );
              })
              .toList() ??
          const [],
      savedInsights: (source['savedInsights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  AppUser copyWith({
    String? email,
    String? displayName,
    String? phoneNumber,
    AppUserRole? role,
    DateTime? updatedAt,
    String? ngoId,
    List<NgoInventoryItem>? inventoryItems,
    List<String>? savedInsights,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ngoId: ngoId ?? this.ngoId,
      inventoryItems: inventoryItems ?? this.inventoryItems,
      savedInsights: savedInsights ?? this.savedInsights,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (ngoId != null) 'ngoId': ngoId,
      'ngoProfile': {
        'email': email,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'role': role.name,
        'inventoryItems': inventoryItems.map((item) => item.toMap()).toList(),
        'savedInsights': savedInsights,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
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
