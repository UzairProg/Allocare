import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    this.cardMaxWidth = 460,
    this.cardPadding = const EdgeInsets.all(32),
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;
  final double cardMaxWidth;
  final EdgeInsets cardPadding;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.1,
            child: _GlowCircle(
              color: const Color(0xFF4285F4).withOpacity(0.08),
              size: size.width * 0.7,
            ),
          ),
          Positioned(
            bottom: -size.height * 0.15,
            left: -size.width * 0.15,
            child: _GlowCircle(
              color: const Color(0xFF34A853).withOpacity(0.06),
              size: size.width * 0.8,
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/allocare_icon.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Allocare',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'An intelligence that really cares',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 40),

                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      padding: cardPadding,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF64748B).withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          form,
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }
}
