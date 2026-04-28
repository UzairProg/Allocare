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
      await ref.read(authServiceProvider).signInWithEmail(
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
      final credential = await ref.read(authServiceProvider).signUpWithEmail(
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

      await ref.read(userProfileServiceProvider).provisionFromAuthUser(
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
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
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
      await ref.read(authServiceProvider).sendPasswordResetEmail(email: email);
    });
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    state = const AsyncLoading();
    await ref.read(authServiceProvider).verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (credential) {
            state = const AsyncData(null);
            onVerificationCompleted(credential);
          },
          verificationFailed: (e) {
            state = AsyncError(e, StackTrace.current);
            onVerificationFailed(e);
          },
          codeSent: (verificationId, resendToken) {
            state = const AsyncData(null);
            onCodeSent(verificationId, resendToken);
          },
          codeAutoRetrievalTimeout: (verificationId) {
            state = const AsyncData(null);
          },
        );
  }

  Future<void> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).signInWithPhoneNumber(
            verificationId: verificationId,
            smsCode: smsCode,
          );
    });
  }

  Future<void> completeProfile({
    required String displayName,
    required AppUserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-missing',
          message: 'No authenticated user found.',
        );
      }

      await ref.read(userProfileServiceProvider).provisionFromAuthUser(
            user,
            requestedRole: role,
            fallbackDisplayName: displayName,
          );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authServiceProvider).signOut();
    });
  }
}
