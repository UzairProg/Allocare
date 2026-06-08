import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firestore/firestore_paths.dart';
import '../models/volunteer_model.dart';
import 'user_profile_service.dart';

final volunteersCollectionProvider = Provider<CollectionReference<VolunteerModel>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.volunteers)
      .withConverter<VolunteerModel>(
        fromFirestore: (snapshot, _) =>
            VolunteerModel.fromMap(snapshot.id, snapshot.data() ?? {}),
        toFirestore: (volunteer, _) => volunteer.toMap(),
      );
});

final volunteerServiceProvider = Provider<VolunteerService>((ref) {
  return VolunteerService(
    ref.watch(volunteersCollectionProvider),
    ref.watch(firestoreProvider),
  );
});

/// Stream of the volunteer profile for the currently logged in user.
final currentVolunteerProvider = StreamProvider<VolunteerModel?>((ref) {
  final authUser = ref.watch(currentUserProfileProvider).asData?.value;
  if (authUser == null) {
    return Stream.value(null);
  }
  return ref.watch(volunteerServiceProvider).watchById(authUser.id);
});

class VolunteerService {
  VolunteerService(this._volunteers, this._firestore);

  final CollectionReference<VolunteerModel> _volunteers;
  final FirebaseFirestore _firestore;

  Stream<VolunteerModel?> watchById(String uid) {
    return _volunteers.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<VolunteerModel?> getById(String uid) async {
    final snapshot = await _volunteers.doc(uid).get();
    return snapshot.data();
  }

  Stream<List<VolunteerModel>> watchPendingByNgoId(String ngoId) {
    return _volunteers
        .where('ngoId', isEqualTo: ngoId)
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Stream<List<VolunteerModel>> watchApprovedByNgoId(String ngoId) {
    return _volunteers
        .where('ngoId', isEqualTo: ngoId)
        .where('verificationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Create a new volunteer profile and increment the selected NGO's pending count.
  Future<VolunteerModel> createProfile({
    required String uid,
    required String email,
    required String displayName,
    String? photoUrl,
    required String phoneNumber,
    required String country,
    required String state,
    required String city,
    required List<String> skills,
    required List<String> specializations,
    required String ngoId,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String emergencyContactRelation,
  }) async {
    final now = DateTime.now();
    final volunteer = VolunteerModel(
      uid: uid,
      email: email.trim(),
      displayName: displayName.trim(),
      photoUrl: photoUrl,
      phoneNumber: phoneNumber.trim(),
      city: city.trim(),
      state: state.trim(),
      country: country.trim(),
      skills: skills,
      specializations: specializations,
      ngoId: ngoId,
      verificationStatus: VolunteerVerificationStatus.pending,
      verifiedAt: null,
      profileCompleted: true,
      isActiveOnField: false,
      status: 'offline',
      currentMissionId: null,
      missionsCompleted: 0,
      reportsSubmitted: 0,
      reportsVerified: 0,
      livesImpacted: 0,
      emergencyContactName: emergencyContactName.trim(),
      emergencyContactPhone: emergencyContactPhone.trim(),
      emergencyContactRelation: emergencyContactRelation.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      // Create volunteer document
      transaction.set(_volunteers.doc(uid), volunteer);

      // Increment pending count in NGO
      final ngoRef = _firestore.collection(FirestorePaths.ngos).doc(ngoId);
      transaction.update(ngoRef, {
        'pendingVolunteerCount': FieldValue.increment(1),
      });
    });

    return volunteer;
  }

  /// Update volunteer profile. Handles updating NGO pending/active counts if NGO or status changes.
  Future<VolunteerModel> updateProfile({
    required String uid,
    required String displayName,
    required String phoneNumber,
    required String country,
    required String state,
    required String city,
    required List<String> skills,
    required List<String> specializations,
    required String ngoId,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String emergencyContactRelation,
    bool resubmit = false,
  }) async {
    final docRef = _volunteers.doc(uid);
    final snapshot = await docRef.get();
    final existing = snapshot.data();

    if (existing == null) {
      throw StateError('Volunteer profile not found.');
    }

    final newStatus = resubmit ? VolunteerVerificationStatus.pending : existing.verificationStatus;
    final now = DateTime.now();

    final updated = existing.copyWith(
      displayName: displayName.trim(),
      phoneNumber: phoneNumber.trim(),
      country: country.trim(),
      state: state.trim(),
      city: city.trim(),
      skills: skills,
      specializations: specializations,
      ngoId: ngoId,
      verificationStatus: newStatus,
      emergencyContactName: emergencyContactName.trim(),
      emergencyContactPhone: emergencyContactPhone.trim(),
      emergencyContactRelation: emergencyContactRelation.trim(),
      updatedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(docRef, updated, SetOptions(merge: true));

      // Handle NGO stats updates if the NGO changed, or if resubmitting from rejected.
      final ngoChanged = existing.ngoId != ngoId;
      final statusChanged = existing.verificationStatus != newStatus;

      if (ngoChanged) {
        // Decrement old NGO
        final oldNgoRef = _firestore.collection(FirestorePaths.ngos).doc(existing.ngoId);
        if (existing.verificationStatus.isPending) {
          transaction.update(oldNgoRef, {
            'pendingVolunteerCount': FieldValue.increment(-1),
          });
        } else if (existing.verificationStatus.isApproved) {
          transaction.update(oldNgoRef, {
            'activeVolunteerCount': FieldValue.increment(-1),
          });
        }

        // Increment new NGO
        final newNgoRef = _firestore.collection(FirestorePaths.ngos).doc(ngoId);
        if (newStatus.isPending) {
          transaction.update(newNgoRef, {
            'pendingVolunteerCount': FieldValue.increment(1),
          });
        } else if (newStatus.isApproved) {
          transaction.update(newNgoRef, {
            'activeVolunteerCount': FieldValue.increment(1),
          });
        }
      } else if (statusChanged) {
        // NGO is the same, but status changed (e.g. resubmitting from rejected to pending)
        final ngoRef = _firestore.collection(FirestorePaths.ngos).doc(ngoId);
        if (existing.verificationStatus.isRejected && newStatus.isPending) {
          transaction.update(ngoRef, {
            'pendingVolunteerCount': FieldValue.increment(1),
          });
        }
      }
    });

    return updated;
  }

  /// Approve volunteer application and adjust NGO counts.
  Future<void> approveVolunteer(String uid) async {
    final docRef = _volunteers.doc(uid);
    final snapshot = await docRef.get();
    final volunteer = snapshot.data();

    if (volunteer == null) {
      throw StateError('Volunteer not found.');
    }

    if (volunteer.verificationStatus.isApproved) return;

    await _firestore.runTransaction((transaction) async {
      transaction.update(docRef, {
        'verificationStatus': VolunteerVerificationStatus.approved.value,
        'verifiedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final ngoRef = _firestore.collection(FirestorePaths.ngos).doc(volunteer.ngoId);
      // Decrement pending, increment active
      transaction.update(ngoRef, {
        'pendingVolunteerCount': FieldValue.increment(-1),
        'activeVolunteerCount': FieldValue.increment(1),
      });
    });
  }

  /// Reject volunteer application and adjust NGO counts.
  Future<void> rejectVolunteer(String uid) async {
    final docRef = _volunteers.doc(uid);
    final snapshot = await docRef.get();
    final volunteer = snapshot.data();

    if (volunteer == null) {
      throw StateError('Volunteer not found.');
    }

    if (volunteer.verificationStatus.isRejected) return;

    await _firestore.runTransaction((transaction) async {
      transaction.update(docRef, {
        'verificationStatus': VolunteerVerificationStatus.rejected.value,
        'updatedAt': Timestamp.now(),
      });

      final ngoRef = _firestore.collection(FirestorePaths.ngos).doc(volunteer.ngoId);
      // Decrement pending only (rejected doesn't go to active)
      if (volunteer.verificationStatus.isPending) {
        transaction.update(ngoRef, {
          'pendingVolunteerCount': FieldValue.increment(-1),
        });
      } else if (volunteer.verificationStatus.isApproved) {
        // If they were somehow approved and now rejected
        transaction.update(ngoRef, {
          'activeVolunteerCount': FieldValue.increment(-1),
        });
      }
    });
  }

  /// Toggle whether the volunteer is active on ground.
  Future<void> toggleActiveOnField(String uid, bool isActive) async {
    await _volunteers.doc(uid).update({
      'isActiveOnField': isActive,
      'status': isActive ? 'available' : 'offline',
      'updatedAt': Timestamp.now(),
    });
  }
}
