import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firestore/firestore_paths.dart';
import '../../../../models/ground_report_model.dart';
import '../../../../services/user_profile_service.dart';

final groundReportRepositoryProvider = Provider<GroundReportRepository>((ref) {
  return GroundReportRepository(firestore: ref.watch(firestoreProvider));
});

class GroundReportRepository {
  final FirebaseFirestore firestore;

  GroundReportRepository({required this.firestore});

  Future<String> createReport(GroundReportModel report) async {
    final docRef = firestore.collection(FirestorePaths.groundReports).doc();
    final newReport = report.copyWith(reportId: docRef.id);
    await docRef.set(newReport.toMap());
    return docRef.id;
  }

  Future<void> updateReport(String reportId, Map<String, dynamic> data) async {
    await firestore.collection(FirestorePaths.groundReports).doc(reportId).update(data);
  }

  Future<GroundReportModel?> getReport(String reportId) async {
    final doc = await firestore.collection(FirestorePaths.groundReports).doc(reportId).get();
    if (doc.exists && doc.data() != null) {
      return GroundReportModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<List<GroundReportModel>> watchReportsForMission(String missionId) {
    return firestore
        .collection(FirestorePaths.groundReports)
        .where('missionId', isEqualTo: missionId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroundReportModel.fromMap(doc.data(), doc.id)).toList());
  }
}
