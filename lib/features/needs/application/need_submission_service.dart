import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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

  Future<String> uploadToCloudinary(File image) {
    return uploadImageToCloudinary(image);
  }

  Future<String> uploadImageToCloudinary(File image) async {
    if (!await image.exists()) {
      throw Exception('Selected image file does not exist.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/dsuwvrile/image/upload'),
    )
      ..fields['upload_preset'] = 'allocare_preset'
      ..fields['folder'] = 'reports'
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = (body['secure_url'] as String?)?.trim();
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return a secure_url.');
    }

    return secureUrl;
  }

  Future<String> submitReport(
    NeedModel need, {
    File? imageFile,
  }) async {
    String imageUrl = '';
    if (imageFile != null) {
      imageUrl = await uploadToCloudinary(imageFile);
    }
    if (imageUrl.isEmpty) {
      return '';
    }

    final normalizedImageUrl = _requirePublicCloudinaryUrl(imageUrl);

    print('Final URL being saved to Firestore: $normalizedImageUrl');

    final reportData = need.toMap()
      ..['image_url'] = normalizedImageUrl
      ..['crisis_type'] = _resolveCrisisType(need)
      ..['urgency_score'] = _urgencyToScore(need.urgency);

    final reportDoc = await firestore.collection(FirestorePaths.reports).add(reportData);

    final savedReport = await reportDoc.get();
    final savedImageUrl = (savedReport.data()?['image_url'] as String?) ?? '';
    print('Verified image_url in reports/${reportDoc.id}: $savedImageUrl');

    // Keep the existing needs collection in sync for current dashboards.
    final syncedNeedData = need.copyWith(id: reportDoc.id).toMap()
      ..['image_url'] = normalizedImageUrl
      ..['crisis_type'] = reportData['crisis_type']
      ..['urgency_score'] = reportData['urgency_score'];
    await firestore.collection(FirestorePaths.needs).doc(reportDoc.id).set(syncedNeedData);
    return reportDoc.id;
  }

  String _requirePublicCloudinaryUrl(String url) {
    final trimmed = url.trim();
    final parsed = Uri.tryParse(trimmed);
    final valid = parsed != null &&
        parsed.hasScheme &&
        parsed.scheme == 'https' &&
        parsed.host.contains('res.cloudinary.com');
    if (!valid) {
      throw Exception('Invalid Cloudinary secure URL: $trimmed');
    }
    return trimmed;
  }

  Future<String> submitNeed(NeedModel need) async {
    final doc = firestore.collection(FirestorePaths.needs).doc();
    await doc.set(need.copyWith(id: doc.id).toMap());
    return doc.id;
  }

  String _resolveCrisisType(NeedModel need) {
    final subcategory = need.subcategory?.trim();
    if (subcategory != null && subcategory.isNotEmpty) {
      return subcategory;
    }
    return need.title;
  }

  double _urgencyToScore(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case 'critical':
        return 5.0;
      case 'high':
        return 4.0;
      case 'medium':
      case 'normal':
        return 3.0;
      case 'low':
        return 2.0;
      default:
        return 1.0;
    }
  }
}

extension on NeedModel {
  NeedModel copyWith({
    String? id,
    String? title,
    String? category,
    String? subcategory,
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
    List<Map<String, dynamic>>? supportingDocsMetadata,
  }) {
    return NeedModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
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
      supportingDocsMetadata: supportingDocsMetadata ?? this.supportingDocsMetadata,
    );
  }
}
