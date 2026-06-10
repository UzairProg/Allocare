import '../../models/app_user.dart';
import '../../models/volunteer_model.dart';
import 'route_paths.dart';

/// Resolves Volunteer onboarding / verification redirects.
String? resolveVolunteerRoute({
  required AppUser profile,
  required VolunteerModel? volunteer,
  required bool volunteerLoading,
  required String currentPath,
}) {
  if (profile.role != AppUserRole.volunteer) return null;

  final isVolunteerFlowRoute = currentPath == RoutePaths.volunteerProfileSetup ||
      currentPath == RoutePaths.volunteerVerificationPending ||
      currentPath == RoutePaths.volunteerVerificationRejected;

  if (volunteerLoading) {
    if (currentPath == RoutePaths.volunteerHome) {
      return RoutePaths.volunteerVerificationPending;
    }
    return null;
  }

  if (volunteer == null || !volunteer.profileCompleted) {
    if (currentPath != RoutePaths.volunteerProfileSetup) {
      return RoutePaths.volunteerProfileSetup;
    }
    return null;
  }

  switch (volunteer.verificationStatus) {
    case VolunteerVerificationStatus.approved:
      if (isVolunteerFlowRoute) {
        return RoutePaths.volunteerHome;
      }
      return null;

    case VolunteerVerificationStatus.pending:
      if (currentPath == RoutePaths.volunteerHome) {
        return RoutePaths.volunteerVerificationPending;
      }
      if (currentPath != RoutePaths.volunteerProfileSetup &&
          currentPath != RoutePaths.volunteerVerificationPending) {
        return RoutePaths.volunteerVerificationPending;
      }
      return null;

    case VolunteerVerificationStatus.rejected:
      if (currentPath == RoutePaths.volunteerHome) {
        return RoutePaths.volunteerVerificationRejected;
      }
      if (currentPath != RoutePaths.volunteerProfileSetup &&
          currentPath != RoutePaths.volunteerVerificationRejected) {
        return RoutePaths.volunteerVerificationRejected;
      }
      return null;
  }
}
