import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AllocationResult {
  final bool success;
  final String? volunteerName;
  final String message;

  AllocationResult({
    required this.success,
    this.volunteerName,
    required this.message,
  });
}

class SmartAllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _canonicalKey(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'medical':
      case 'health':
      case 'medicine':
        return 'medical';
      case 'food':
      case 'food_nutrition':
      case 'nutrition':
        return 'food';
      case 'logistics':
      case 'shelter_essentials':
      case 'shelter':
      case 'infrastructure':
        return 'logistics';
      case 'airborne':
        return 'airborne';
      case 'waterborne':
        return 'waterborne';
      case 'natural_disaster':
      case 'natural':
      case 'accident':
      case 'fire':
      case 'police':
        return value;
      default:
        return value;
    }
  }

  bool _specialityMatches(String category, String speciality) {
    final c = _canonicalKey(category);
    final s = _canonicalKey(speciality);
    if (c == s) {
      return true;
    }

    // Allow broader resource fallback for certain categories.
    if ((c == 'fire' || c == 'accident' || c == 'natural_disaster') &&
        s == 'logistics') {
      return true;
    }

    return false;
  }

  Future<AllocationResult> dispatchVolunteer(
    String reportId,
    String category,
  ) async {
    try {
      final normalizedCategory = category.trim();

      // 1. Selection Logic: pull available volunteers and match speciality locally.
      // This avoids index requirements and supports canonical category matching.
      final volunteersSnapshot = await _firestore
          .collection('volunteers')
          .where('status', isEqualTo: 'available')
          .limit(100)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? volunteerDoc;
      for (final doc in volunteersSnapshot.docs) {
        final data = doc.data();
        final speciality = (data['speciality'] as String? ?? '').trim();
        if (_specialityMatches(normalizedCategory, speciality)) {
          volunteerDoc = doc;
          break;
        }
      }

      if (volunteerDoc == null) {
        // 4. Edge Case: No matching volunteer available.
        // Keep urgency untouched and mark report as Pending.
        await _firestore.collection('reports').doc(reportId).set({
          'status': 'Pending',
        }, SetOptions(merge: true));

        return AllocationResult(
          success: false,
          message:
              'No available volunteers found for category: $normalizedCategory',
        );
      }

      final volunteerId = volunteerDoc.id;
      final volunteerData = volunteerDoc.data();
      final volunteerName =
          volunteerData['name'] as String? ?? 'Unknown Volunteer';
      final volunteerContact =
          (volunteerData['contact'] as String?) ??
          (volunteerData['phone'] as String?) ??
          (volunteerData['mobile'] as String?) ??
          '';

      // 2. Atomic Update (The Handshake)
      await _firestore.runTransaction((transaction) async {
        final reportRef = _firestore.collection('reports').doc(reportId);
        final volunteerRef = _firestore
            .collection('volunteers')
            .doc(volunteerId);

        // Read report first (Transaction requirement: all reads before writes)
        final reportSnapshot = await transaction.get(reportRef);
        if (!reportSnapshot.exists) {
          throw Exception('Report not found');
        }

        final volunteerSnapshot = await transaction.get(volunteerRef);
        if (!volunteerSnapshot.exists) {
          throw Exception('Volunteer not found');
        }

        final liveVolunteerData = volunteerSnapshot.data() ?? {};
        final liveStatus = (liveVolunteerData['status'] as String? ?? '')
            .trim()
            .toLowerCase();
        final liveSpeciality =
            (liveVolunteerData['speciality'] as String? ?? '').trim();

        if (liveStatus != 'available' ||
            !_specialityMatches(normalizedCategory, liveSpeciality)) {
          throw Exception(
            'Volunteer is no longer available for this category. Try dispatch again.',
          );
        }

        final reportData = reportSnapshot.data() ?? {};

        // Calculate new urgency score (reduce by 20%)
        double? currentUrgency;
        if (reportData.containsKey('urgency_score')) {
          final val = reportData['urgency_score'];
          if (val is num) {
            currentUrgency = val.toDouble();
          } else if (val is String) {
            currentUrgency = double.tryParse(val);
          }
        }

        if (currentUrgency == null && reportData.containsKey('urgency')) {
          final urgencyStr = reportData['urgency'].toString().toLowerCase();
          switch (urgencyStr.trim()) {
            case 'critical':
              currentUrgency = 10.0;
              break;
            case 'high':
              currentUrgency = 8.5;
              break;
            case 'medium':
            case 'normal':
              currentUrgency = 5.0;
              break;
            case 'low':
              currentUrgency = 2.5;
              break;
          }
        }

        final newUrgency = currentUrgency == null ? null : currentUrgency * 0.8;

        // Write updates
        transaction.update(volunteerRef, {
          'status': 'on_mission',
          'current_report_id': reportId,
        });

        final reportUpdate = <String, dynamic>{
          'assigned_volunteer_id': volunteerId,
          'assigned_volunteer_name': volunteerName,
          'assigned_volunteer_contact': volunteerContact,
          'assigned_volunteer_speciality': normalizedCategory,
          'assigned_at': FieldValue.serverTimestamp(),
          'status': 'assigned',
        };

        if (newUrgency != null) {
          reportUpdate['urgency_score'] = newUrgency;
        }

        transaction.update(reportRef, reportUpdate);
      });

      // 3. UI Feedback
      return AllocationResult(
        success: true,
        volunteerName: volunteerName,
        message: 'Successfully dispatched $volunteerName',
      );
    } catch (e) {
      return AllocationResult(
        success: false,
        message: 'Error during allocation: $e',
      );
    }
  }
}

final smartAllocationServiceProvider = Provider<SmartAllocationService>((ref) {
  return SmartAllocationService();
});
