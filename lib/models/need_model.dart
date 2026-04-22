import 'package:cloud_firestore/cloud_firestore.dart';

class NeedModel {
  const NeedModel({
    required this.id,
    required this.title,
    required this.category,
    required this.urgency,
    required this.location,
    required this.peopleAffected,
    required this.status,
  });

  final String id;
  final String title;
  final String category;
  final String urgency;
  final String location;
  final int peopleAffected;
  final String status;

  factory NeedModel.fromMap(String id, Map<String, dynamic> map) {
    return NeedModel(
      id: id,
      title: (map['title'] as String?) ?? 'Untitled need',
      category: (map['category'] as String?) ?? 'general',
      urgency: (map['urgency'] as String?) ?? 'normal',
      location: (map['location'] as String?) ?? 'Unknown',
      peopleAffected: _toInt(map['peopleAffected']),
      status: (map['status'] as String?) ?? 'open',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'urgency': urgency,
      'location': location,
      'peopleAffected': peopleAffected,
      'status': status,
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
}
