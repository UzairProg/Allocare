import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';

final authControllerProvider = AutoDisposeAsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.watch(authServiceProvider).signInWithEmail(
            email: email.trim(),
            password: password,
          );
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required AppUserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref.watch(authServiceProvider).signUpWithEmail(
            email: email.trim(),
            password: password,
            displayName: displayName,
          );

      final authUser = credential.user;
      if (authUser == null) {
        throw FirebaseAuthException(
          code: 'user-missing',
          message: 'User account was not created.',
        );
      }

      await ref.watch(userProfileServiceProvider).provisionFromAuthUser(
            authUser,
            requestedRole: role,
            fallbackDisplayName: displayName,
        fallbackPhoneNumber: phoneNumber,
          );
    });
  }

  Future<void> signInWithGoogle({
    required AppUserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref.watch(authServiceProvider).signInWithGoogle();
      final authUser = credential.user;
      if (authUser == null) {
        throw FirebaseAuthException(
          code: 'google-user-missing',
          message: 'Google sign-in did not return a valid user.',
        );
      }

      await ref.watch(userProfileServiceProvider).provisionFromAuthUser(
            authUser,
            requestedRole: role,
            fallbackDisplayName: authUser.displayName,
          );
    });
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.watch(authServiceProvider).sendPasswordResetEmail(email: email);
    });
  }
}
