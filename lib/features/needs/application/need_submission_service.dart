import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../../models/need_model.dart';
import '../../../services/user_profile_service.dart';

final needSubmissionServiceProvider = Provider<NeedSubmissionService>((ref) {
  return NeedSubmissionService(
    firestore: ref.watch(firestoreProvider),
  );
});

class NeedSubmissionService {
  NeedSubmissionService({required this.firestore});

  final FirebaseFirestore firestore;

  Future<String> submitNeed(NeedModel need) async {
    final doc = firestore.collection(FirestorePaths.needs).doc();
    await doc.set(need.copyWith(id: doc.id).toMap());
    return doc.id;
  }
}

extension on NeedModel {
  NeedModel copyWith({
    String? id,
    String? title,
    String? category,
    String? urgency,
    String? description,
    String? location,
    String? locationMode,
    String? reportedBy,
    int? peopleAffected,
    String? status,
    double? latitude,
    double? longitude,
    String? contactName,
    String? contactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NeedModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      description: description ?? this.description,
      location: location ?? this.location,
      locationMode: locationMode ?? this.locationMode,
      reportedBy: reportedBy ?? this.reportedBy,
      peopleAffected: peopleAffected ?? this.peopleAffected,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
