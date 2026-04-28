import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/router/route_paths.dart';
import '../../../models/app_user.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_page_shell.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_role_selector.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  AppUserRole _selectedRole = AppUserRole.volunteer;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    });

    return AuthPageShell(
      title: 'Join Allocare',
      subtitle: 'Create your account to start making an impact',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Role Selection
          Text(
            'I am a',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          AuthRoleSelector(
            value: _selectedRole,
            enabled: !isBusy,
            onChanged: (role) => setState(() => _selectedRole = role),
          ),
          const SizedBox(height: 32),

          // Google Signup
          OutlinedButton.icon(
            onPressed: isBusy ? null : () => ref.read(authControllerProvider.notifier).signInWithGoogle(role: _selectedRole),
            icon: SvgPicture.asset('lib/assets/icons/google_logo.svg', width: 20, height: 20),
            label: Text(
              'Sign up with Google',
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR REGISTER MANUALLY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),
          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _fullNameController,
                  enabled: !isBusy,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15),
                  decoration: _inputDecoration('Full Name', Icons.person_outline),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: !isBusy,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15),
                  decoration: _inputDecoration('Email Address', Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !isBusy,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15),
                  decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Password must be at least 6 chars',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AuthPrimaryButton(
            label: 'Create Account',
            isLoading: isBusy,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                ref.read(authControllerProvider.notifier).signUpWithEmail(
                  email: _emailController.text,
                  password: _passwordController.text,
                  displayName: _fullNameController.text,
                  phoneNumber: '', // Will be updated later or handled via PNV if needed
                  role: _selectedRole,
                );
              }
            },
          ),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Already have an account? ",
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
          TextButton(
            onPressed: isBusy ? null : () => context.go(RoutePaths.login),
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(
                color: const Color(0xFF4285F4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
      ),
    );
  }
}
