import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/volunteer_model.dart';

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

  bool _specialityMatches(String category, String speciality) {
    final c = category.trim().toLowerCase();
    final s = speciality.trim().toLowerCase();

    // 1. Exact contains or equal
    if (c == s || c.contains(s) || s.contains(c)) {
      return true;
    }

    // 2. Medical Group
    final isMedicalCat =
        c.contains('medical') || c.contains('health') || c.contains('medicine');
    final isMedicalSpec =
        s.contains('medical') || s.contains('health') || s.contains('medicine');
    if (isMedicalCat && isMedicalSpec) return true;

    // 3. Food Group
    final isFoodCat =
        c.contains('food') || c.contains('nutrition') || c.contains('meal');
    final isFoodSpec =
        s.contains('food') || s.contains('nutrition') || s.contains('meal');
    if (isFoodCat && isFoodSpec) return true;

    // 4. Water Group
    final isWaterCat =
        c.contains('water') ||
        c.contains('sanitation') ||
        c.contains('waterborne');
    final isWaterSpec =
        s.contains('water') ||
        s.contains('sanitation') ||
        s.contains('waterborne');
    if (isWaterCat && isWaterSpec) return true;

    // 5. Logistics/Shelter/Infrastructure Group
    final isLogisticsCat =
        c.contains('logistics') ||
        c.contains('shelter') ||
        c.contains('infrastructure') ||
        c.contains('supply');
    final isLogisticsSpec =
        s.contains('logistics') ||
        s.contains('shelter') ||
        s.contains('infrastructure') ||
        s.contains('supply');
    if (isLogisticsCat && isLogisticsSpec) return true;

    // 6. Rescue/Fire/Disaster/Police Group
    final isRescueCat =
        c.contains('fire') ||
        c.contains('accident') ||
        c.contains('natural') ||
        c.contains('disaster') ||
        c.contains('police') ||
        c.contains('rescue');
    final isRescueSpec =
        s.contains('fire') ||
        s.contains('accident') ||
        s.contains('natural') ||
        s.contains('disaster') ||
        s.contains('police') ||
        s.contains('rescue');
    if (isRescueCat && isRescueSpec) return true;

    // Fallback: Logistics specialist can assist in Rescue/Disaster scenarios
    if (isRescueCat && isLogisticsSpec) {
      return true;
    }

    return false;
  }

  Future<AllocationResult> dispatchVolunteer(
    String reportId,
    String category, {
    List<String>? excludeVolunteers,
  }) async {
    try {
      final normalizedCategory = category.trim();

      // Fetch the need to get its ngoId if it exists
      final needDoc = await _firestore.collection('needs').doc(reportId).get();
      String? needNgoId;
      if (needDoc.exists) {
        final data = needDoc.data();
        if (data != null) {
          needNgoId = data['ngoId'] as String? ?? data['ngo_id'] as String?;
        }
      }

      // 1. Selection Logic: pull volunteers and filter in memory to match specializations
      final volunteersSnapshot = await _firestore
          .collection('volunteers')
          .get();

      final docs = volunteersSnapshot.docs.map((doc) {
        return VolunteerModel.fromMap(doc.id, doc.data());
      }).toList();

      final matchedVolunteers = docs.where((v) {
        if (excludeVolunteers != null && excludeVolunteers.contains(v.uid)) {
          return false;
        }

        // Filter by NGO if need has ngoId
        if (needNgoId != null && needNgoId.isNotEmpty && v.ngoId != needNgoId) {
          return false;
        }

        // 1. Approved Volunteers
        if (v.verificationStatus != VolunteerVerificationStatus.approved) {
          return false;
        }

        // 2. Active On Field
        if (!v.isActiveOnField) {
          return false;
        }

        // 3. Not Currently Assigned (currentMissionId is null/empty or status is not 'assigned')
        final isNotAssigned =
            (v.currentMissionId == null ||
            v.currentMissionId!.isEmpty ||
            v.status != 'assigned');
        if (!isNotAssigned) {
          return false;
        }

        // 4. Category Match
        final normCategory = normalizedCategory.trim().toLowerCase();
        final targetCategory = (normCategory == 'natural_disaster' || normCategory == 'natural disaster') ? 'medical' : normCategory;
        final matchesCategory = v.specializations.contains(targetCategory) || v.specializations.contains(normCategory);
        if (!matchesCategory) {
          return false;
        }

        return true;
      }).toList();

      // Sort in-memory by missionsCompleted (Highest Reliability) descending
      matchedVolunteers.sort(
        (a, b) => b.missionsCompleted.compareTo(a.missionsCompleted),
      );

      if (matchedVolunteers.isEmpty) {
        // No matching volunteer available.
        final reportUpdate = <String, dynamic>{
          'status': 'open',
          'assignmentStatus': 'open',
        };
        await _firestore
            .collection('reports')
            .doc(reportId)
            .set(reportUpdate, SetOptions(merge: true));
        await _firestore
            .collection('needs')
            .doc(reportId)
            .set(reportUpdate, SetOptions(merge: true));

        print('Volunteer selected: None');
        return AllocationResult(
          success: false,
          message:
              'No available volunteers found for category: $normalizedCategory',
        );
      }

      final selectedVolunteer = matchedVolunteers.first;
      final volunteerId = selectedVolunteer.uid;
      final volunteerName = selectedVolunteer.displayName;

      // 2. Atomic Update (The Handshake)
      await _firestore.runTransaction((transaction) async {
        final reportRef = _firestore.collection('reports').doc(reportId);
        final needRef = _firestore.collection('needs').doc(reportId);
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
        final liveVolunteer = VolunteerModel.fromMap(
          volunteerId,
          liveVolunteerData,
        );

        final isStillAvailable =
            liveVolunteer.verificationStatus ==
                VolunteerVerificationStatus.approved &&
            liveVolunteer.isActiveOnField &&
            (liveVolunteer.currentMissionId == null ||
                liveVolunteer.currentMissionId!.isEmpty ||
                liveVolunteer.status != 'assigned') &&
            (liveVolunteer.specializations.contains(
                  normalizedCategory.trim().toLowerCase(),
                ) ||
                ((normalizedCategory.trim().toLowerCase() == 'natural_disaster' ||
                        normalizedCategory.trim().toLowerCase() == 'natural disaster') &&
                    liveVolunteer.specializations.contains('medical')));

        if (!isStillAvailable) {
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
          'status': 'pending_response',
          'currentMissionId': reportId,
          'current_report_id': reportId,
        });

        final reportUpdate = <String, dynamic>{
          'matchedVolunteerId': volunteerId,
          'matchedVolunteerName': volunteerName,
          'matched_volunteer_id': volunteerId,
          'matched_volunteer_name': volunteerName,
          'assignmentStatus': 'pending',
          'status': 'pending_acceptance',
          'assignmentRequestedAt': FieldValue.serverTimestamp(),
          'missionHistory': [
            {
              'status': 'assigned',
              'timestamp': DateTime.now().toIso8601String(),
            },
          ],
        };

        if (newUrgency != null) {
          reportUpdate['urgency_score'] = newUrgency;
        }

        transaction.update(reportRef, reportUpdate);
        transaction.update(needRef, reportUpdate);

        final missionRef = _firestore.collection('missions').doc(reportId);
        final fullMissionData = Map<String, dynamic>.from(reportData);
        fullMissionData.addAll(reportUpdate);
        transaction.set(missionRef, fullMissionData, SetOptions(merge: true));

        print('Volunteer selected');
        print('Need matched');
        print('--- DISPATCH TRANSITION ---');
        print(
          'Volunteer ($volunteerId) Status Before: ${liveVolunteer.status}',
        );
        print('Volunteer ($volunteerId) Status After: pending_response');
        print('Need ($reportId) Status Before: ${reportData['status']}');
        print('Need ($reportId) Status After: pending_acceptance');
        print(
          'Need ($reportId) AssignmentStatus Before: ${reportData['assignmentStatus']}',
        );
        print('Need ($reportId) AssignmentStatus After: pending');
      });

      // 3. Log event
      await _logMissionUpdate(
        missionId: reportId,
        ngoId: needNgoId,
        volunteerId: volunteerId,
        eventType: 'mission_assigned',
        message: 'Mission assigned to volunteer: $volunteerName.',
      );

      // 4. UI Feedback
      return AllocationResult(
        success: true,
        volunteerName: volunteerName,
        message:
            'Successfully matched $volunteerName. Pending volunteer confirmation.',
      );
    } catch (e) {
      return AllocationResult(
        success: false,
        message: 'Error during allocation: $e',
      );
    }
  }

  Future<void> _logMissionUpdate({
    required String missionId,
    required String? ngoId,
    required String volunteerId,
    required String eventType,
    required String message,
  }) async {
    try {
      final now = FieldValue.serverTimestamp();
      final data = {
        'id':
            missionId, // Use missionId as document identifier or generate one? Let's generate a unique doc ID for the update!
        'missionId': missionId,
        'ngoId': ngoId ?? '',
        'volunteerId': volunteerId,
        'eventType': eventType,
        'message': message,
        'createdAt': now,
      };

      // Generate a unique update ID
      final updateNeedRef = _firestore
          .collection('needs')
          .doc(missionId)
          .collection('updates')
          .doc();
      data['id'] = updateNeedRef.id;

      await updateNeedRef.set(data);

      await _firestore
          .collection('reports')
          .doc(missionId)
          .collection('updates')
          .doc(updateNeedRef.id)
          .set(data);
    } catch (e) {
      print('Error logging mission update: $e');
    }
  }

  Future<void> startNavigationEvent({
    required String needId,
    required String volunteerId,
  }) async {
    try {
      final needDoc = await _firestore.collection('needs').doc(needId).get();
      final needData = needDoc.data() ?? {};
      final ngoId = needData['ngoId'] ?? needData['ngo_id'] ?? '';

      final currentStatus = needData['status'] ?? '';
      print('[MISSION] startNavigationEvent: before=$currentStatus, writing en_route');

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      final updateData = {
        'status': 'en_route',
        'assignmentStatus': 'accepted',
        'acceptedAt': now,
        'accepted_at': now,
        'enRouteAt': now,
        'en_route_at': now,
        'navigationStartedAt': now,
        'navigation_started_at': now,
        'updatedAt': now,
        'missionHistory': FieldValue.arrayUnion([
          {'status': 'en_route', 'timestamp': DateTime.now().toIso8601String()},
        ]),
      };

      batch.set(
        _firestore.collection('needs').doc(needId),
        updateData,
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('reports').doc(needId),
        updateData,
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('missions').doc(needId),
        updateData,
        SetOptions(merge: true),
      );
      // Update volunteer status to on_mission
      batch.update(_firestore.collection('volunteers').doc(volunteerId), {
        'status': 'on_mission',
        'currentMissionId': needId,
      });
      await batch.commit();
      print('[MISSION] startNavigationEvent: committed. status=en_route');

      await _logMissionUpdate(
        missionId: needId,
        ngoId: ngoId,
        volunteerId: volunteerId,
        eventType: 'navigation_started',
        message: 'Volunteer started turn-by-turn navigation to site.',
      );
    } catch (e) {
      print('Error starting navigation event: $e');
    }
  }

  Future<bool> acceptMission({
    required String needId,
    required String volunteerId,
    required String volunteerName,
  }) async {
    try {
      final needSnapshot = await _firestore
          .collection('needs')
          .doc(needId)
          .get();
      final needData = needSnapshot.data() ?? {};
      final volunteerSnapshot = await _firestore
          .collection('volunteers')
          .doc(volunteerId)
          .get();
      final volunteerData = volunteerSnapshot.data() ?? {};

      final batch = _firestore.batch();

      final needRef = _firestore.collection('needs').doc(needId);
      final reportRef = _firestore.collection('reports').doc(needId);
      final missionRef = _firestore.collection('missions').doc(needId);
      final volunteerRef = _firestore.collection('volunteers').doc(volunteerId);

      final now = FieldValue.serverTimestamp();

      final needUpdate = {
        'status': 'accepted',
        'assignmentStatus': 'accepted',
        'assignedVolunteerId': volunteerId,
        'assignedVolunteerName': volunteerName,
        'assigned_volunteer_id': volunteerId,
        'assigned_volunteer_name': volunteerName,
        'assignedAt': now,
        'assigned_at': now,
        'acceptedAt': now,
        'accepted_at': now,
        'updatedAt': now,
        'missionHistory': FieldValue.arrayUnion([
          {'status': 'accepted', 'timestamp': DateTime.now().toIso8601String()},
        ]),
      };

      batch.set(needRef, needUpdate, SetOptions(merge: true));
      batch.set(reportRef, needUpdate, SetOptions(merge: true));
      batch.set(missionRef, needUpdate, SetOptions(merge: true));

      batch.update(volunteerRef, {
        'status': 'on_mission',
        'currentMissionId': needId,
        'current_report_id': needId,
      });

      await batch.commit();

      print('Need accepted');
      print('--- ACCEPT TRANSITION ---');
      print(
        'Volunteer ($volunteerId) Status Before: ${volunteerData['status']}',
      );
      print('Volunteer ($volunteerId) Status After: on_mission');
      print('Need ($needId) Status Before: ${needData['status']}');
      print('Need ($needId) Status After: accepted');
      print(
        'Need ($needId) AssignmentStatus Before: ${needData['assignmentStatus']}',
      );
      print('Need ($needId) AssignmentStatus After: accepted');

      // Log event
      final ngoId = needData['ngoId'] ?? needData['ngo_id'] ?? '';
      await _logMissionUpdate(
        missionId: needId,
        ngoId: ngoId,
        volunteerId: volunteerId,
        eventType: 'mission_accepted',
        message: 'Volunteer accepted the mission and is en route.',
      );

      return true;
    } catch (e) {
      print('Error accepting mission: $e');
      return false;
    }
  }

  Future<bool> markArrivedOnSite({
    required String needId,
    required String volunteerId,
  }) async {
    try {
      final needDoc = await _firestore.collection('needs').doc(needId).get();
      final needData = needDoc.data() ?? {};
      final ngoId = needData['ngoId'] ?? needData['ngo_id'] ?? '';
      final currentStatus = needData['status'] ?? '';
      print('[MISSION] markArrivedOnSite: before=$currentStatus, writing on_site');

      final batch = _firestore.batch();
      final needRef = _firestore.collection('needs').doc(needId);
      final reportRef = _firestore.collection('reports').doc(needId);
      final missionRef = _firestore.collection('missions').doc(needId);

      final now = FieldValue.serverTimestamp();
      final updateData = {
        'status': 'on_site',
        'arrivedAt': now,
        'arrived_at': now,
        'updatedAt': now,
        'missionHistory': FieldValue.arrayUnion([
          {'status': 'arrived', 'timestamp': DateTime.now().toIso8601String()},
        ]),
      };

      batch.set(needRef, updateData, SetOptions(merge: true));
      batch.set(reportRef, updateData, SetOptions(merge: true));
      batch.set(missionRef, updateData, SetOptions(merge: true));

      await batch.commit();
      print('[MISSION] markArrivedOnSite: committed. status=on_site');

      // Log event
      await _logMissionUpdate(
        missionId: needId,
        ngoId: ngoId,
        volunteerId: volunteerId,
        eventType: 'arrived_on_site',
        message: 'Volunteer arrived on site.',
      );

      return true;
    } catch (e) {
      print('Error setting on_site status: $e');
      return false;
    }
  }

  Future<bool> beginFieldOperations({
    required String needId,
    required String volunteerId,
  }) async {
    try {
      final needDoc = await _firestore.collection('needs').doc(needId).get();
      final needData = needDoc.data() ?? {};
      final ngoId = needData['ngoId'] ?? needData['ngo_id'] ?? '';

      final batch = _firestore.batch();
      final needRef = _firestore.collection('needs').doc(needId);
      final reportRef = _firestore.collection('reports').doc(needId);

      final now = FieldValue.serverTimestamp();
      final updateData = {
        'status': 'field_active',
        'fieldOpsStartedAt': now,
        'field_ops_started_at': now,
        'operationsStartedAt': now,
        'operations_started_at': now,
      };

      batch.update(needRef, updateData);
      batch.update(reportRef, updateData);

      await batch.commit();
      print('Need status set to field_active');

      // Log event
      await _logMissionUpdate(
        missionId: needId,
        ngoId: ngoId,
        volunteerId: volunteerId,
        eventType: 'field_operations_started',
        message: 'Field operations are now active.',
      );

      return true;
    } catch (e) {
      print('Error setting field_active status: $e');
      return false;
    }
  }

  Future<bool> declineMission({
    required String needId,
    required String volunteerId,
  }) async {
    try {
      // 1. Fetch need to get category and existing declined volunteers
      final needSnapshot = await _firestore
          .collection('needs')
          .doc(needId)
          .get();
      if (!needSnapshot.exists) {
        throw Exception('Need not found');
      }
      final data = needSnapshot.data() ?? {};
      final category =
          data['category'] as String? ?? data['crisis_type'] as String? ?? '';

      final volunteerSnapshot = await _firestore
          .collection('volunteers')
          .doc(volunteerId)
          .get();
      final volunteerData = volunteerSnapshot.data() ?? {};

      final declinedVolunteers = List<String>.from(
        data['declinedVolunteers'] ?? [],
      );
      if (!declinedVolunteers.contains(volunteerId)) {
        declinedVolunteers.add(volunteerId);
      }

      // 2. Database update
      final batch = _firestore.batch();
      final needRef = _firestore.collection('needs').doc(needId);
      final reportRef = _firestore.collection('reports').doc(needId);
      final missionRef = _firestore.collection('missions').doc(needId);
      final volunteerRef = _firestore.collection('volunteers').doc(volunteerId);

      final now = FieldValue.serverTimestamp();
      final needUpdate = {
        'status': 'open',
        'assignmentStatus': 'declined',
        'matchedVolunteerId': FieldValue.delete(),
        'matchedVolunteerName': FieldValue.delete(),
        'matched_volunteer_id': FieldValue.delete(),
        'matched_volunteer_name': FieldValue.delete(),
        'declinedVolunteers': declinedVolunteers,
        'updatedAt': now,
        'missionHistory': FieldValue.arrayUnion([
          {'status': 'declined', 'timestamp': DateTime.now().toIso8601String()},
        ]),
      };

      batch.set(needRef, needUpdate, SetOptions(merge: true));
      batch.set(reportRef, needUpdate, SetOptions(merge: true));
      batch.set(missionRef, needUpdate, SetOptions(merge: true));

      batch.update(volunteerRef, {
        'status': 'available',
        'currentMissionId': FieldValue.delete(),
        'current_report_id': FieldValue.delete(),
      });

      await batch.commit();

      print('Need declined');
      print('--- DECLINE TRANSITION ---');
      print(
        'Volunteer ($volunteerId) Status Before: ${volunteerData['status']}',
      );
      print('Volunteer ($volunteerId) Status After: available');
      print('Need ($needId) Status Before: ${data['status']}');
      print('Need ($needId) Status After: open');
      print(
        'Need ($needId) AssignmentStatus Before: ${data['assignmentStatus']}',
      );
      print('Need ($needId) AssignmentStatus After: declined');

      // Log event
      final ngoId = data['ngoId'] ?? data['ngo_id'] ?? '';
      await _logMissionUpdate(
        missionId: needId,
        ngoId: ngoId,
        volunteerId: volunteerId,
        eventType: 'mission_declined',
        message: 'Volunteer declined the mission match.',
      );

      // 3. Rerun matching automatically (next-best match)
      if (category.isNotEmpty) {
        await dispatchVolunteer(
          needId,
          category,
          excludeVolunteers: declinedVolunteers,
        );
      }

      return true;
    } catch (e) {
      print('Error declining mission: $e');
      return false;
    }
  }

  Future<bool> completeMission({
    required String needId,
    required String volunteerId,
  }) async {
    try {
      final needSnapshot = await _firestore
          .collection('needs')
          .doc(needId)
          .get();
      final needData = needSnapshot.data() ?? {};
      final volunteerSnapshot = await _firestore
          .collection('volunteers')
          .doc(volunteerId)
          .get();
      final volunteerData = volunteerSnapshot.data() ?? {};

      final batch = _firestore.batch();

      final needRef = _firestore.collection('needs').doc(needId);
      final reportRef = _firestore.collection('reports').doc(needId);
      final missionRef = _firestore.collection('missions').doc(needId);
      final volunteerRef = _firestore.collection('volunteers').doc(volunteerId);

      final now = FieldValue.serverTimestamp();

      final needUpdate = {
        'status': 'completed',
        'completedAt': now,
        'completed_at': now,
        'resolvedAt': now,
        'resolved_at': now,
        'updatedAt': now,
        'missionHistory': FieldValue.arrayUnion([
          {'status': 'resolved', 'timestamp': DateTime.now().toIso8601String()},
        ]),
      };

      batch.set(needRef, needUpdate, SetOptions(merge: true));
      batch.set(reportRef, needUpdate, SetOptions(merge: true));
      batch.set(missionRef, needUpdate, SetOptions(merge: true));

      batch.update(volunteerRef, {
        'status': 'available',
        'currentMissionId': null,
        'current_report_id': null,
        'isActiveOnField': false, // Turn active duty status off when completed
        'missionsCompleted': FieldValue.increment(1),
        'totalCompletedMissions': FieldValue.increment(1),
      });

      await batch.commit();

      print('Mission completed');
      print('--- COMPLETE TRANSITION ---');
      print(
        'Volunteer ($volunteerId) Status Before: ${volunteerData['status']}',
      );
      print('Volunteer ($volunteerId) Status After: available');
      print('Need ($needId) Status Before: ${needData['status']}');
      print('Need ($needId) Status After: completed');

      // Log event
      final ngoId = needData['ngoId'] ?? needData['ngo_id'] ?? '';
      await _logMissionUpdate(
        missionId: needId,
        ngoId: ngoId,
        volunteerId: volunteerId,
        eventType: 'mission_completed',
        message: 'Mission completed successfully.',
      );

      return true;
    } catch (e) {
      print('Error completing mission: $e');
      return false;
    }
  }
}

final smartAllocationServiceProvider = Provider<SmartAllocationService>((ref) {
  return SmartAllocationService();
});
