import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ngo_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/ngo_service.dart';
import '../../../services/ngo_storage_service.dart';

final ngoControllerProvider =
    AutoDisposeAsyncNotifierProvider<NgoController, void>(NgoController.new);

class NgoProfileFormData {
  const NgoProfileFormData({
    required this.ngoName,
    required this.description,
    required this.phoneNumber,
    required this.country,
    required this.state,
    required this.city,
    required this.address,
    required this.supportedCategories,
    this.logoFile,
  });

  final String ngoName;
  final String description;
  final String phoneNumber;
  final String country;
  final String state;
  final String city;
  final String address;
  final List<String> supportedCategories;
  final File? logoFile;
}

class NgoController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<NgoModel> submitProfile({
    required NgoProfileFormData form,
    NgoModel? existing,
  }) async {
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-missing',
          message: 'No authenticated user found.',
        );
      }

      final ngoService = ref.read(ngoServiceProvider);
      final NgoModel ngo;

      if (existing == null) {
        ngo = await ngoService.createProfile(
          userId: user.uid,
          email: user.email ?? '',
          ngoName: form.ngoName,
          description: form.description,
          phoneNumber: form.phoneNumber,
          country: form.country,
          state: form.state,
          city: form.city,
          address: form.address,
          supportedCategories: form.supportedCategories,
        );
      } else {
        ngo = await ngoService.updateProfile(
          ngoId: existing.ngoId,
          ngoName: form.ngoName,
          description: form.description,
          phoneNumber: form.phoneNumber,
          country: form.country,
          state: form.state,
          city: form.city,
          address: form.address,
          supportedCategories: form.supportedCategories,
          resetToPendingOnEdit: existing.verificationStatus.isRejected,
        );
      }

      if (form.logoFile != null) {
        final logoUrl = await ref
            .read(ngoStorageServiceProvider)
            .uploadNgoLogo(ngoId: ngo.ngoId, imageFile: form.logoFile!);
        return ngoService.updateProfile(
          ngoId: ngo.ngoId,
          ngoName: form.ngoName,
          description: form.description,
          phoneNumber: form.phoneNumber,
          country: form.country,
          state: form.state,
          city: form.city,
          address: form.address,
          supportedCategories: form.supportedCategories,
          logoUrl: logoUrl,
        );
      }

      return ngo;
    });

    state = result.when(
      data: (_) => const AsyncData(null),
      error: (error, stackTrace) => AsyncError(error, stackTrace),
      loading: () => const AsyncLoading(),
    );

    if (result.hasError) {
      throw result.error!;
    }

    return result.requireValue;
  }
}
