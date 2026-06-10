import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final ngoStorageServiceProvider = Provider<NgoStorageService>((ref) {
  return NgoStorageService(ref.watch(firebaseStorageProvider));
});

class NgoStorageService {
  NgoStorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadNgoLogo({
    required String ngoId,
    required File imageFile,
  }) async {
    final ref = _storage.ref().child('ngos/$ngoId/logo.jpg');
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }
}
