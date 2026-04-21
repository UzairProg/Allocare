import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_page_shell.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _linkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final message = _friendlyError(next.error);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      if (previous?.isLoading == true && !next.isLoading && mounted) {
        setState(() {
          _linkSent = true;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Reset link sent to ${_emailController.text.trim()}'),
            ),
          );
      }
    });

    return AuthPageShell(
      title: 'Forgot password?',
      subtitle: "Enter your email associated with your account and we'll send a link to reset your account.",
      cardMaxWidth: 500,
      cardPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      formTopSpacing: 24,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _linkSent ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _linkSent ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _linkSent ? Icons.mark_email_read_outlined : Icons.lock_reset,
                    color: _linkSent ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _linkSent
                          ? 'Check your inbox and spam folder for the reset email.'
                          : 'We will send a secure reset link to your inbox in a few moments.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _linkSent ? const Color(0xFF166534) : const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: 'Get Link',
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
            'Remembered your password? ',
            style: theme.textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: isBusy ? null : () => context.go(RoutePaths.login),
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(
          email: _emailController.text,
        );
  }

  String _friendlyError(Object? error) {
    if (error == null) {
      return 'Could not send reset link. Try again.';
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('user-not-found')) {
      return 'No account found for this email.';
    }

    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email.';
    }

    if (raw.contains('network-request-failed')) {
      return 'Network error. Check your connection and try again.';
    }

    return 'Could not send reset link. Please try again.';
  }
}
