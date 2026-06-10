import 'package:cloud_firestore/cloud_firestore.dart';

/// Verification lifecycle for NGO onboarding.
enum NgoVerificationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const NgoVerificationStatus(this.value);

  final String value;

  static NgoVerificationStatus fromString(String? raw) {
    return NgoVerificationStatus.values.firstWhere(
      (status) => status.value == raw,
      orElse: () => NgoVerificationStatus.pending,
    );
  }

  bool get isApproved => this == NgoVerificationStatus.approved;
  bool get isPending => this == NgoVerificationStatus.pending;
  bool get isRejected => this == NgoVerificationStatus.rejected;
}

/// First-class NGO entity stored in `ngos/{ngoId}`.
class NgoModel {
  const NgoModel({
    required this.ngoId,
    required this.userId,
    required this.ngoName,
    required this.description,
    required this.email,
    required this.phoneNumber,
    required this.city,
    required this.state,
    required this.country,
    required this.address,
    required this.logoUrl,
    required this.verificationStatus,
    this.verifiedAt,
    required this.isActive,
    this.activeVolunteerCount = 0,
    this.pendingVolunteerCount = 0,
    this.activeMissionCount = 0,
    this.completedMissionCount = 0,
    this.reportsReceived = 0,
    this.supportedCategories = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String ngoId;
  final String userId;

  final String ngoName;
  final String description;

  final String email;
  final String phoneNumber;

  final String city;
  final String state;
  final String country;
  final String address;

  final String logoUrl;

  final NgoVerificationStatus verificationStatus;
  final DateTime? verifiedAt;

  final bool isActive;

  final int activeVolunteerCount;
  final int pendingVolunteerCount;
  final int activeMissionCount;
  final int completedMissionCount;
  final int reportsReceived;
  final List<String> supportedCategories;

  final DateTime createdAt;
  final DateTime updatedAt;

  @Deprecated('Use activeVolunteerCount')
  int get activeVolunteers => activeVolunteerCount;

  @Deprecated('Use activeMissionCount')
  int get activeMissions => activeMissionCount;

  @Deprecated('Use completedMissionCount')
  int get completedMissions => completedMissionCount;

  bool get isVerified => verificationStatus.isApproved;
  bool get canAccessDashboard => verificationStatus.isApproved;

  NgoModel copyWith({
    String? ngoName,
    String? description,
    String? email,
    String? phoneNumber,
    String? city,
    String? state,
    String? country,
    String? address,
    String? logoUrl,
    NgoVerificationStatus? verificationStatus,
    DateTime? verifiedAt,
    bool? isActive,
    int? activeVolunteerCount,
    int? pendingVolunteerCount,
    int? activeMissionCount,
    int? completedMissionCount,
    int? reportsReceived,
    List<String>? supportedCategories,
    DateTime? updatedAt,
  }) {
    return NgoModel(
      ngoId: ngoId,
      userId: userId,
      ngoName: ngoName ?? this.ngoName,
      description: description ?? this.description,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      isActive: isActive ?? this.isActive,
      activeVolunteerCount: activeVolunteerCount ?? this.activeVolunteerCount,
      pendingVolunteerCount:
          pendingVolunteerCount ?? this.pendingVolunteerCount,
      activeMissionCount: activeMissionCount ?? this.activeMissionCount,
      completedMissionCount:
          completedMissionCount ?? this.completedMissionCount,
      reportsReceived: reportsReceived ?? this.reportsReceived,
      supportedCategories: supportedCategories ?? this.supportedCategories,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NgoModel.fromMap(String id, Map<String, dynamic> map) {
    return NgoModel(
      ngoId: id,
      userId: (map['userId'] as String?) ?? '',
      ngoName: (map['ngoName'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      state: (map['state'] as String?) ?? '',
      country: (map['country'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      logoUrl: (map['logoUrl'] as String?) ?? '',
      verificationStatus: NgoVerificationStatus.fromString(
        map['verificationStatus'] as String?,
      ),
      verifiedAt: _asDateTime(map['verifiedAt']),
      isActive: map['isActive'] as bool? ?? false,
      activeVolunteerCount: _readInt(
        map,
        'activeVolunteerCount',
        fallbackKey: 'activeVolunteers',
      ),
      pendingVolunteerCount: _readInt(map, 'pendingVolunteerCount'),
      activeMissionCount: _readInt(
        map,
        'activeMissionCount',
        fallbackKey: 'activeMissions',
      ),
      completedMissionCount: _readInt(
        map,
        'completedMissionCount',
        fallbackKey: 'completedMissions',
      ),
      reportsReceived: _readInt(map, 'reportsReceived'),
      supportedCategories: _readStringList(map['supportedCategories']),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ngoName': ngoName,
      'description': description,
      'email': email,
      'phoneNumber': phoneNumber,
      'city': city,
      'state': state,
      'country': country,
      'address': address,
      'logoUrl': logoUrl,
      'verificationStatus': verificationStatus.value,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'isActive': isActive,
      'activeVolunteerCount': activeVolunteerCount,
      'pendingVolunteerCount': pendingVolunteerCount,
      'activeMissionCount': activeMissionCount,
      'completedMissionCount': completedMissionCount,
      'reportsReceived': reportsReceived,
      'supportedCategories': supportedCategories,
      'activeVolunteers': activeVolunteerCount,
      'activeMissions': activeMissionCount,
      'completedMissions': completedMissionCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static int _readInt(
    Map<String, dynamic> map,
    String key, {
    String? fallbackKey,
  }) {
    final primary = (map[key] as num?)?.toInt();
    if (primary != null) return primary;
    return (map[fallbackKey] as num?)?.toInt() ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
