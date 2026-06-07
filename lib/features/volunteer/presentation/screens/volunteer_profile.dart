import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/auth_service.dart';
import '../../../../services/user_profile_service.dart';

class VolunteerProfileScreen extends ConsumerWidget {
  const VolunteerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final authUser = ref.watch(authStateProvider).asData?.value;

    final userName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : (authUser?.displayName?.trim() ?? 'Active Volunteer');

    final userEmail = profile?.email.trim().isNotEmpty == true
        ? profile!.email
        : (authUser?.email?.trim() ?? 'volunteer@allocare.org');

    final userPhone = profile?.phoneNumber.trim().isNotEmpty == true
        ? profile!.phoneNumber
        : 'Not Verified';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Card Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        color: theme.colorScheme.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            userEmail,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'On-Ground Responder',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tactical Stats
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStatCard(
                      label: 'Missions Done',
                      value: '14',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniStatCard(
                      label: 'Hours Active',
                      value: '38.5h',
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Contact Info / Identity Section
              Text(
                'Identity & Verification',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Phone Number',
                      value: userPhone,
                      trailing: userPhone != 'Not Verified'
                          ? const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18)
                          : const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Account Role',
                      value: 'Volunteer Responder',
                      trailing: const Icon(Icons.shield_outlined, color: Color(0xFF5B888F), size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Certified Skills Section
              Text(
                'Skill Certifications',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSkillChip('First Aid & CPR'),
                  _buildSkillChip('Disaster Response'),
                  _buildSkillChip('Logistics Management'),
                  _buildSkillChip('Search & Rescue'),
                  _buildSkillChip('Communications'),
                ],
              ),
              const SizedBox(height: 32),

              // Sign Out Button (Footer)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('SIGN OUT FROM SESSION'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: const BorderSide(color: Color(0xFFFEE2E2)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
