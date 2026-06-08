import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../models/volunteer_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/volunteer_service.dart';
import 'volunteer_verification_pending_screen.dart';

class VolunteerVerificationRejectedScreen extends ConsumerStatefulWidget {
  const VolunteerVerificationRejectedScreen({super.key});

  @override
  ConsumerState<VolunteerVerificationRejectedScreen> createState() =>
      _VolunteerVerificationRejectedScreenState();
}

class _VolunteerVerificationRejectedScreenState
    extends ConsumerState<VolunteerVerificationRejectedScreen> {
  bool _isResubmitting = false;

  Future<void> _resubmit(VolunteerModel volunteer) async {
    setState(() => _isResubmitting = true);
    try {
      await ref.read(volunteerServiceProvider).updateProfile(
            uid: volunteer.uid,
            displayName: volunteer.displayName,
            phoneNumber: volunteer.phoneNumber,
            country: volunteer.country,
            state: volunteer.state,
            city: volunteer.city,
            skills: volunteer.skills,
            specializations: volunteer.specializations,
            ngoId: volunteer.ngoId,
            emergencyContactName: volunteer.emergencyContactName,
            emergencyContactPhone: volunteer.emergencyContactPhone,
            emergencyContactRelation: volunteer.emergencyContactRelation,
            resubmit: true,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application resubmitted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resubmission failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final volunteer = ref.watch(currentVolunteerProvider).asData?.value;
    final ngoStream = ref.watch(selectedNgoProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Warning / Rejected Icon Shield
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.gpp_bad_rounded,
                    color: Color(0xFFEF4444),
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Title
              Text(
                'Application Rejected',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF991B1B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Description Message
              Text(
                'Please contact your selected NGO for further details regarding your registration request.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // NGO Info Details
              if (volunteer != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected NGO',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      ngoStream.when(
                        data: (ngo) => Text(
                          ngo?.ngoName ?? 'Unknown NGO',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        error: (_, __) => Text(
                          'Unknown NGO',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),

              // Action Buttons
              if (volunteer != null) ...[
                ElevatedButton.icon(
                  onPressed: _isResubmitting ? null : () => _resubmit(volunteer),
                  icon: _isResubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('RESUBMIT APPLICATION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFFCA5A5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  context.push(RoutePaths.volunteerProfileSetup);
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('EDIT PROFILE DETAILS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                },
                icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
                label: Text(
                  'LOGOUT FROM ACCOUNT',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
