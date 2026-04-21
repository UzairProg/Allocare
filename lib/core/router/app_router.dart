import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/home_shell_page.dart';
import '../../services/auth_service.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

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
        builder: (context, state) => const HomeShellPage(),
      ),
    ],
    redirect: (context, state) {
      final user = authState.asData?.value;
      final isOnAuth =
          state.uri.path == RoutePaths.auth ||
          state.uri.path == RoutePaths.login ||
          state.uri.path == RoutePaths.signup ||
          state.uri.path == RoutePaths.forgotPassword;
      final isAuthenticated = user != null;

      if (!isAuthenticated && !isOnAuth) {
        return RoutePaths.auth;
      }

      if (isAuthenticated && isOnAuth) {
        return RoutePaths.home;
      }

      return null;
    },
  );
});
