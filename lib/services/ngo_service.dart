import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firestore/firestore_paths.dart';
import '../models/app_user.dart';
import '../models/ngo_model.dart';
import 'auth_service.dart';
import 'user_profile_service.dart';
import 'volunteer_service.dart';

final ngosCollectionProvider = Provider<CollectionReference<NgoModel>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.ngos)
      .withConverter<NgoModel>(
        fromFirestore: (snapshot, _) =>
            NgoModel.fromMap(snapshot.id, snapshot.data() ?? {}),
        toFirestore: (ngo, _) => ngo.toMap(),
      );
});

final ngoServiceProvider = Provider<NgoService>((ref) {
  return NgoService(
    ref.watch(ngosCollectionProvider),
    ref.watch(userProfilesCollectionProvider),
  );
});

/// Live NGO profile for the authenticated user.
final currentNgoProvider = StreamProvider<NgoModel?>((ref) {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) {
    return Stream.value(null);
  }
  return ref.watch(ngoServiceProvider).watchByUserId(authUser.uid);
});

/// NGO document id for inventory / volunteer linkage.
/// Falls back to auth uid for legacy records created before NGO entity existed.
final effectiveNgoIdProvider = Provider<String?>((ref) {
  final ngo = ref.watch(currentNgoProvider).asData?.value;
  if (ngo != null) return ngo.ngoId;
  
  final volunteer = ref.watch(currentVolunteerProvider).asData?.value;
  if (volunteer != null && volunteer.ngoId.isNotEmpty) return volunteer.ngoId;

  final authUser = ref.watch(authStateProvider).asData?.value;
  return authUser?.uid;
});

class NgoService {
  NgoService(this._ngos, this._users);

  final CollectionReference<NgoModel> _ngos;
  final CollectionReference<AppUser> _users;

  Stream<NgoModel?> watchByUserId(String userId) {
    return _ngos.where('userId', isEqualTo: userId).limit(1).snapshots().map((
      snapshot,
    ) {
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    });
  }

  Stream<NgoModel?> watchById(String ngoId) {
    return _ngos.doc(ngoId).snapshots().map((snapshot) => snapshot.data());
  }

  Future<NgoModel?> getByUserId(String userId) async {
    final snapshot = await _ngos
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  Future<NgoModel> createProfile({
    required String userId,
    required String email,
    required String ngoName,
    required String description,
    required String phoneNumber,
    required String country,
    required String state,
    required String city,
    required String address,
    String logoUrl = '',
    List<String> supportedCategories = const [],
  }) async {
    final existing = await getByUserId(userId);
    if (existing != null) {
      throw StateError('NGO profile already exists for this user.');
    }

    final now = DateTime.now();
    // Use auth uid as ngoId for stable linkage with legacy inventory records.
    final docRef = _ngos.doc(userId);
    final ngo = NgoModel(
      ngoId: userId,
      userId: userId,
      ngoName: ngoName.trim(),
      description: description.trim(),
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      city: city.trim(),
      state: state.trim(),
      country: country.trim(),
      address: address.trim(),
      logoUrl: logoUrl,
      verificationStatus: NgoVerificationStatus.pending,
      verifiedAt: null,
      isActive: false,
      supportedCategories: supportedCategories,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(ngo);
    await _linkNgoToUser(userId, ngo.ngoId);
    return ngo;
  }

  Future<NgoModel> updateProfile({
    required String ngoId,
    required String ngoName,
    required String description,
    required String phoneNumber,
    required String country,
    required String state,
    required String city,
    required String address,
    String? logoUrl,
    List<String>? supportedCategories,
    bool resetToPendingOnEdit = false,
  }) async {
    final snapshot = await _ngos.doc(ngoId).get();
    final existing = snapshot.data();
    if (existing == null) {
      throw StateError('NGO profile not found.');
    }

    final updated = existing.copyWith(
      ngoName: ngoName.trim(),
      description: description.trim(),
      phoneNumber: phoneNumber.trim(),
      country: country.trim(),
      state: state.trim(),
      city: city.trim(),
      address: address.trim(),
      logoUrl: logoUrl ?? existing.logoUrl,
      supportedCategories: supportedCategories ?? existing.supportedCategories,
      verificationStatus:
          resetToPendingOnEdit && existing.verificationStatus.isRejected
          ? NgoVerificationStatus.pending
          : existing.verificationStatus,
      updatedAt: DateTime.now(),
    );

    await _ngos.doc(ngoId).set(updated, SetOptions(merge: true));
    return updated;
  }

  Future<void> _linkNgoToUser(String userId, String ngoId) async {
    final userSnapshot = await _users.doc(userId).get();
    final user = userSnapshot.data();
    if (user == null) return;

    await _users
        .doc(userId)
        .set(
          user.copyWith(ngoId: ngoId, updatedAt: DateTime.now()),
          SetOptions(merge: true),
        );
  }
}
