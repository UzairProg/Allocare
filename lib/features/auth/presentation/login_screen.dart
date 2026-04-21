import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../models/app_user.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_page_shell.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_role_selector.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/brand_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AppUserRole _selectedRole = AppUserRole.volunteer;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (!next.hasError) {
        return;
      }

      final message = _friendlyError(next.error);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return AuthPageShell(
      title: 'Welcome back',
      subtitle: 'Connect with real needs and make meaningful impact',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthRoleSelector(
              value: _selectedRole,
              enabled: !isBusy,
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: isBusy
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).signInWithGoogle(role: _selectedRole);
                    },
              icon: const GoogleBrandIcon(size: 18),
              label: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              enabled: !isBusy,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              suffixIcon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onSuffixPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              validator: (value) {
                final password = value ?? '';
                if (password.length < 6) {
                  return 'Password should be at least 6 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isBusy ? null : () => context.go(RoutePaths.forgotPassword),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: 'Continue',
              isLoading: isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: isBusy ? null : () => context.go(RoutePaths.signup),
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  String _friendlyError(Object? error) {
    if (error is! Exception) {
      return 'Something went wrong. Please try again.';
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }

    if (raw.contains('invalid-credential') || raw.contains('wrong-password') || raw.contains('user-not-found')) {
      return 'Invalid email or password.';
    }

    if (raw.contains('network-request-failed')) {
      return 'Network error. Check your connection and try again.';
    }

    return 'Authentication failed. Please try again.';
  }
}
