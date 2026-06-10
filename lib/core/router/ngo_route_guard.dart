import '../../models/app_user.dart';
import '../../models/ngo_model.dart';
import 'route_paths.dart';

/// Resolves NGO onboarding / verification redirects.
String? resolveNgoRoute({
  required AppUser profile,
  required NgoModel? ngo,
  required bool ngoLoading,
  required String currentPath,
}) {
  if (profile.role != AppUserRole.ngo) return null;

  final isNgoFlowRoute = currentPath == RoutePaths.ngoProfileSetup ||
      currentPath == RoutePaths.ngoVerificationPending ||
      currentPath == RoutePaths.ngoVerificationRejected;

  if (ngoLoading) {
    if (currentPath == RoutePaths.home) {
      return RoutePaths.ngoVerificationPending;
    }
    return null;
  }

  if (ngo == null) {
    if (currentPath != RoutePaths.ngoProfileSetup) {
      return RoutePaths.ngoProfileSetup;
    }
    return null;
  }

  switch (ngo.verificationStatus) {
    case NgoVerificationStatus.approved:
      if (currentPath == RoutePaths.ngoVerificationPending ||
          currentPath == RoutePaths.ngoVerificationRejected) {
        return RoutePaths.home;
      }
      return null;

    case NgoVerificationStatus.pending:
      if (currentPath == RoutePaths.home) {
        return RoutePaths.ngoVerificationPending;
      }
      if (currentPath != RoutePaths.ngoProfileSetup &&
          currentPath != RoutePaths.ngoVerificationPending) {
        return RoutePaths.ngoVerificationPending;
      }
      return null;

    case NgoVerificationStatus.rejected:
      if (currentPath == RoutePaths.home) {
        return RoutePaths.ngoVerificationRejected;
      }
      if (currentPath != RoutePaths.ngoProfileSetup &&
          currentPath != RoutePaths.ngoVerificationRejected) {
        return RoutePaths.ngoVerificationRejected;
      }
      return null;
  }
}
