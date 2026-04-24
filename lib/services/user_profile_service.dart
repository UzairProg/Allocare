import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firestore/firestore_paths.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final userProfilesCollectionProvider = Provider<CollectionReference<AppUser>>((ref) {
  return ref.watch(firestoreProvider).collection(FirestorePaths.users).withConverter<AppUser>(
        fromFirestore: (snapshot, _) => AppUser.fromMap(snapshot.id, snapshot.data() ?? {}),
        toFirestore: (appUser, _) => appUser.toMap(),
      );
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref.watch(userProfilesCollectionProvider));
});

final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) {
    return Stream.value(null);
  }

  return ref.watch(userProfileServiceProvider).watchById(authUser.uid);
});

class UserProfileService {
  UserProfileService(this._users);

  final CollectionReference<AppUser> _users;

  Stream<AppUser?> watchById(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) => snapshot.data());
  }

  Future<AppUser?> getById(String userId) async {
    final snapshot = await _users.doc(userId).get();
    return snapshot.data();
  }

  Future<void> upsert(AppUser user) {
    return _users.doc(user.id).set(user, SetOptions(merge: true));
  }

  Future<void> provisionFromAuthUser(
    User user, {
    required AppUserRole requestedRole,
    String? fallbackDisplayName,
    String? fallbackPhoneNumber,
  }) async {
    final now = DateTime.now();
    final existing = await getById(user.uid);

    final profile = AppUser(
      id: user.uid,
      email: user.email ?? existing?.email ?? '',
      displayName: (user.displayName ?? fallbackDisplayName ?? existing?.displayName ?? '').trim(),
      phoneNumber: (existing?.phoneNumber ?? fallbackPhoneNumber ?? '').trim(),
      role: existing?.role ?? requestedRole,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      inventoryItems: existing?.inventoryItems ?? const [],
    );

    await upsert(profile);
  }
}
