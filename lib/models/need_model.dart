import 'package:cloud_firestore/cloud_firestore.dart';

class NeedModel {
  const NeedModel({
    required this.id,
    required this.title,
    required this.category,
    this.subcategory,
    required this.urgency,
    required this.description,
    required this.location,
    required this.locationMode,
    required this.reportedBy,
    required this.peopleAffected,
    required this.status,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String category;
  final String? subcategory;
  final String urgency;
  final String description;
  final String location;
  final String locationMode;
  final String reportedBy;
  final int peopleAffected;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? contactName;
  final String? contactPhone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NeedModel.fromMap(String id, Map<String, dynamic> map) {
    return NeedModel(
      id: id,
      title: (map['title'] as String?) ?? 'Untitled need',
      category: (map['category'] as String?) ?? 'general',
      subcategory: (map['subcategory'] as String?)?.trim(),
      urgency: (map['urgency'] as String?) ?? 'normal',
      description: (map['description'] as String?) ?? '',
      location: (map['location'] as String?) ?? 'Unknown',
      locationMode: (map['locationMode'] as String?) ?? 'manual',
      reportedBy: (map['reportedBy'] as String?) ?? '',
      peopleAffected: _toInt(map['peopleAffected']),
      status: (map['status'] as String?) ?? 'open',
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      contactName: (map['contactName'] as String?)?.trim(),
      contactPhone: (map['contactPhone'] as String?)?.trim(),
      createdAt: _asDateTime(map['createdAt']),
      updatedAt: _asDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      if (subcategory != null && subcategory!.trim().isNotEmpty) 'subcategory': subcategory,
      'urgency': urgency,
      'description': description,
      'location': location,
      'locationMode': locationMode,
      'reportedBy': reportedBy,
      'peopleAffected': peopleAffected,
      'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (contactName != null && contactName!.trim().isNotEmpty) 'contactName': contactName,
      if (contactPhone != null && contactPhone!.trim().isNotEmpty) 'contactPhone': contactPhone,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static double? _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
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
