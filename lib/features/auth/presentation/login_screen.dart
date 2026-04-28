import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const MethodChannel _pnvChannel = MethodChannel('com.example.allocare_app/pnv');

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  AppUserRole _selectedRole = AppUserRole.volunteer;
  bool _obscurePassword = true;
  bool _isPnvLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePNV() async {
    setState(() => _isPnvLoading = true);
    try {
      final response = await _pnvChannel.invokeMethod<Map<dynamic, dynamic>>('getVerifiedPhone');
      final phone = response?['phoneNumber'] as String?;

      if (phone != null && phone.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SvgPicture.asset('lib/assets/icons/firebase_logo.svg', width: 20, height: 20),
                const SizedBox(width: 10),
                Text('Verified via Firebase PNV: $phone'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firebase PNV detection unavailable: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _isPnvLoading = false);
    }
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
      title: 'Sign In',
      subtitle: 'Unifying fragmented crisis data into priority-based smart intelligence.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Continue as',
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

          // Google Login
          OutlinedButton.icon(
            onPressed: isBusy ? null : () => ref.read(authControllerProvider.notifier).signInWithGoogle(role: _selectedRole),
            icon: SvgPicture.asset('lib/assets/icons/google_logo.svg', width: 20, height: 20),
            label: Text(
              'Continue with Google',
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
          const SizedBox(height: 16),

          // Firebase PNV Login
          AuthPrimaryButton(
            label: _isPnvLoading ? 'Detecting...' : 'Instant PNV Login',
            isLoading: _isPnvLoading,
            icon: SvgPicture.asset('lib/assets/icons/firebase_logo.svg', width: 22, height: 22),
            onPressed: isBusy ? null : _handlePNV,
            color: const Color(0xFF0F172A),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Verified via Firebase Phone Number Verification',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR MANUAL LOGIN',
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

          TextFormField(
            controller: _emailController,
            enabled: !isBusy,
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 15),
            decoration: _inputDecoration('Email Address', Icons.email_outlined),
            keyboardType: TextInputType.emailAddress,
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
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Sign In',
            isLoading: isBusy,
            onPressed: () {
              ref.read(authControllerProvider.notifier).signInWithEmail(
                email: _emailController.text,
                password: _passwordController.text,
              );
            },
            color: const Color(0xFF4285F4), // Simple Google Blue
          ),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "New to Allocare? ",
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
          TextButton(
            onPressed: isBusy ? null : () => context.go(RoutePaths.signup),
            child: Text(
              'Register Now',
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
