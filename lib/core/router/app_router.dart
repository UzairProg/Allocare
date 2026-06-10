import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/main_navigation_screen.dart';
import '../../features/ngo/presentation/screens/ngo_profile_setup_screen.dart';
import '../../features/ngo/presentation/screens/ngo_verification_pending_screen.dart';
import '../../features/ngo/presentation/screens/ngo_verification_rejected_screen.dart';
import '../../features/volunteer/presentation/screens/volunteer_main_shell.dart';
import '../../features/volunteer/presentation/screens/volunteer_profile_setup_screen.dart';
import '../../features/volunteer/presentation/screens/volunteer_verification_pending_screen.dart';
import '../../features/volunteer/presentation/screens/volunteer_verification_rejected_screen.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/ngo_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/volunteer_service.dart';
import 'ngo_route_guard.dart';
import 'volunteer_route_guard.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(currentUserProfileProvider);
  final ngoState = ref.watch(currentNgoProvider);
  final volunteerState = ref.watch(currentVolunteerProvider);

  return GoRouter(
    initialLocation: RoutePaths.login,
    routes: [
      GoRoute(
        path: RoutePaths.auth,
        redirect: (context, state) => RoutePaths.login,
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: RoutePaths.volunteerHome,
        builder: (context, state) => const VolunteerMainShell(),
      ),
      GoRoute(
        path: RoutePaths.ngoProfileSetup,
        builder: (context, state) => const NgoProfileSetupScreen(),
      ),
      GoRoute(
        path: RoutePaths.ngoVerificationPending,
        builder: (context, state) => const NgoVerificationPendingScreen(),
      ),
      GoRoute(
        path: RoutePaths.ngoVerificationRejected,
        builder: (context, state) => const NgoVerificationRejectedScreen(),
      ),
      GoRoute(
        path: RoutePaths.volunteerProfileSetup,
        builder: (context, state) => const VolunteerProfileSetupScreen(),
      ),
      GoRoute(
        path: RoutePaths.volunteerVerificationPending,
        builder: (context, state) => const VolunteerVerificationPendingScreen(),
      ),
      GoRoute(
        path: RoutePaths.volunteerVerificationRejected,
        builder: (context, state) => const VolunteerVerificationRejectedScreen(),
      ),
    ],
    redirect: (context, state) {
      if (authState.isLoading || profileState.isLoading) {
        return null;
      }

      final user = authState.asData?.value;
      final profile = profileState.asData?.value;
      final ngo = ngoState.asData?.value;
      final volunteer = volunteerState.asData?.value;

      print('--- ROUTER REDIRECT ---');
      print('Path: ${state.uri.path}');
      print('User authenticated: ${user != null} (uid: ${user?.uid})');
      print('Profile role: ${profile?.role} (exists: ${profile != null})');
      print('Volunteer profile exists: ${volunteer != null}');
      print('Volunteer loading: ${volunteerState.isLoading}');
      print('-----------------------');

      final ngoLoading = user != null &&
          profile?.role == AppUserRole.ngo &&
          ngoState.isLoading;

      final volunteerLoading = user != null &&
          profile?.role == AppUserRole.volunteer &&
          volunteerState.isLoading;

      if (ngoLoading || volunteerLoading) {
        return null;
      }

      final isOnAuth =
          state.uri.path == RoutePaths.auth ||
          state.uri.path == RoutePaths.login ||
          state.uri.path == RoutePaths.forgotPassword;

      final isOnSignup = state.uri.path == RoutePaths.signup;
      final isAuthenticated = user != null;
      final hasProfile = profile != null;

      if (!isAuthenticated && !isOnAuth && !isOnSignup) {
        return RoutePaths.login;
      }

      if (isAuthenticated) {
        if (!hasProfile && !isOnSignup) {
          return RoutePaths.signup;
        }

        if (hasProfile) {
          final isVolunteer = profile.role == AppUserRole.volunteer;
          final isNgo = profile.role == AppUserRole.ngo;

          if (isOnAuth || isOnSignup) {
            if (isVolunteer) {
              final volunteerRedirect = resolveVolunteerRoute(
                profile: profile,
                volunteer: volunteer,
                volunteerLoading: volunteerLoading,
                currentPath: state.uri.path,
              );
              return volunteerRedirect ?? RoutePaths.volunteerHome;
            }
            if (isNgo) {
              final ngoRedirect = resolveNgoRoute(
                profile: profile,
                ngo: ngo,
                ngoLoading: ngoLoading,
                currentPath: state.uri.path,
              );
              return ngoRedirect ?? RoutePaths.home;
            }
            return RoutePaths.home;
          }

          if (isVolunteer) {
            final volunteerRedirect = resolveVolunteerRoute(
              profile: profile,
              volunteer: volunteer,
              volunteerLoading: volunteerLoading,
              currentPath: state.uri.path,
            );
            if (volunteerRedirect != null) return volunteerRedirect;

            if (state.uri.path == RoutePaths.home) {
              return RoutePaths.volunteerHome;
            }
            if (state.uri.path == RoutePaths.volunteerHome) {
              return null;
            }
          }

          if (isNgo) {
            final ngoRedirect = resolveNgoRoute(
              profile: profile,
              ngo: ngo,
              ngoLoading: ngoLoading,
              currentPath: state.uri.path,
            );
            if (ngoRedirect != null) return ngoRedirect;

            if (!isVolunteer && state.uri.path == RoutePaths.volunteerHome) {
              return RoutePaths.home;
            }
          } else {
            if (state.uri.path == RoutePaths.volunteerHome && !isVolunteer) {
              return RoutePaths.home;
            }
            if (state.uri.path.startsWith('/ngo/')) {
              return RoutePaths.home;
            }
            // Block volunteer workflows for non-volunteers
            if (state.uri.path.startsWith('/volunteer/') && !isVolunteer) {
              return RoutePaths.home;
            }
          }
        }
      }

      return null;
    },
  );
});
