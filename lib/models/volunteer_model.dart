import 'package:cloud_firestore/cloud_firestore.dart';

enum VolunteerVerificationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VolunteerVerificationStatus(this.value);

  final String value;

  static VolunteerVerificationStatus fromString(String? raw) {
    return VolunteerVerificationStatus.values.firstWhere(
      (status) => status.value == raw,
      orElse: () => VolunteerVerificationStatus.pending,
    );
  }

  bool get isApproved => this == VolunteerVerificationStatus.approved;
  bool get isPending => this == VolunteerVerificationStatus.pending;
  bool get isRejected => this == VolunteerVerificationStatus.rejected;
}

class VolunteerModel {
  const VolunteerModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.phoneNumber,
    required this.city,
    required this.state,
    required this.country,
    this.latitude,
    this.longitude,
    required this.skills,
    required this.specializations,
    required this.ngoId,
    required this.verificationStatus,
    this.verifiedAt,
    required this.profileCompleted,
    required this.isActiveOnField,
    required this.status,
    this.currentMissionId,
    required this.missionsCompleted,
    required this.reportsSubmitted,
    required this.reportsVerified,
    required this.livesImpacted,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.emergencyContactRelation,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String phoneNumber;

  final String city;
  final String state;
  final String country;

  final double? latitude;
  final double? longitude;

  final List<String> skills;
  final List<String> specializations;

  final String ngoId;

  final VolunteerVerificationStatus verificationStatus;
  final DateTime? verifiedAt;

  final bool profileCompleted;
  final bool isActiveOnField;
  final String status;

  final String? currentMissionId;
  final int missionsCompleted;
  final int reportsSubmitted;
  final int reportsVerified;
  final int livesImpacted;

  final String emergencyContactName;
  final String emergencyContactPhone;
  final String emergencyContactRelation;

  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get formattedSpecializations {
    return specializations.map((s) {
      switch (s) {
        case 'medical': return 'Medical';
        case 'food_nutrition': return 'Food & Nutrition';
        case 'shelter_essentials': return 'Shelter & Essentials';
        case 'disaster_emergency': return 'Disaster & Emergency';
        case 'mental_wellbeing': return 'Mental Health & Wellbeing';
        case 'education_child_support': return 'Education & Child Support';
        case 'elderly_special_care': return 'Elderly & Special Care';
        case 'livelihood_financial_support': return 'Livelihood & Financial Support';
        case 'women_safety': return 'Women & Safety';
        case 'others': return 'General Support';
        default: return s;
      }
    }).toList();
  }

  VolunteerModel copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    List<String>? skills,
    List<String>? specializations,
    String? ngoId,
    VolunteerVerificationStatus? verificationStatus,
    DateTime? verifiedAt,
    bool? profileCompleted,
    bool? isActiveOnField,
    String? status,
    String? currentMissionId,
    int? missionsCompleted,
    int? reportsSubmitted,
    int? reportsVerified,
    int? livesImpacted,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    DateTime? updatedAt,
  }) {
    return VolunteerModel(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      skills: skills ?? this.skills,
      specializations: specializations ?? this.specializations,
      ngoId: ngoId ?? this.ngoId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isActiveOnField: isActiveOnField ?? this.isActiveOnField,
      status: status ?? this.status,
      currentMissionId: currentMissionId ?? this.currentMissionId,
      missionsCompleted: missionsCompleted ?? this.missionsCompleted,
      reportsSubmitted: reportsSubmitted ?? this.reportsSubmitted,
      reportsVerified: reportsVerified ?? this.reportsVerified,
      livesImpacted: livesImpacted ?? this.livesImpacted,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory VolunteerModel.fromMap(String id, Map<String, dynamic> map) {
    final active = map['isActiveOnField'] as bool? ?? false;
    List<String> specs = _readStringList(map['specializations']);
    if (specs.isEmpty) {
      final oldSpec = map['specialization'] as String?;
      if (oldSpec != null && oldSpec.trim().isNotEmpty) {
        final mapped = mapOldSpecialization(oldSpec);
        if (mapped != null) {
          specs = [mapped];
        }
      }
    }

    return VolunteerModel(
      uid: id,
      email: (map['email'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      photoUrl: map['photoUrl'] as String?,
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      state: (map['state'] as String?) ?? '',
      country: (map['country'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      skills: _readStringList(map['skills']),
      specializations: specs,
      ngoId: (map['ngoId'] as String?) ?? '',
      verificationStatus: VolunteerVerificationStatus.fromString(
        map['verificationStatus'] as String?,
      ),
      verifiedAt: _asDateTime(map['verifiedAt']),
      profileCompleted: map['profileCompleted'] as bool? ?? false,
      isActiveOnField: active,
      status: map['status'] as String? ?? (active ? 'available' : 'offline'),
      currentMissionId: map['currentMissionId'] as String?,
      missionsCompleted: (map['missionsCompleted'] as num? ?? map['totalCompletedMissions'] as num?)?.toInt() ?? 0,
      reportsSubmitted: (map['reportsSubmitted'] as num?)?.toInt() ?? 0,
      reportsVerified: (map['reportsVerified'] as num?)?.toInt() ?? 0,
      livesImpacted: (map['livesImpacted'] as num?)?.toInt() ?? 0,
      emergencyContactName: (map['emergencyContactName'] as String?) ?? '',
      emergencyContactPhone: (map['emergencyContactPhone'] as String?) ?? '',
      emergencyContactRelation: (map['emergencyContactRelation'] as String?) ?? '',
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static String? mapOldSpecialization(String oldSpec) {
    switch (oldSpec.trim()) {
      case 'Certified Medic':
        return 'medical';
      case 'Food Relief Coordinator':
        return 'food_nutrition';
      case 'Shelter Coordinator':
        return 'shelter_essentials';
      case 'Emergency Response Lead':
        return 'disaster_emergency';
      case 'Logistics Specialist':
        return 'others';
      default:
        return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'city': city,
      'state': state,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'skills': skills,
      'specializations': specializations,
      'ngoId': ngoId,
      'verificationStatus': verificationStatus.value,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'profileCompleted': profileCompleted,
      'isActiveOnField': isActiveOnField,
      'status': status,
      'currentMissionId': currentMissionId,
      'missionsCompleted': missionsCompleted,
      'totalCompletedMissions': missionsCompleted,
      'reportsSubmitted': reportsSubmitted,
      'reportsVerified': reportsVerified,
      'livesImpacted': livesImpacted,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
