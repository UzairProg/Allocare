import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../services/ngo_service.dart';
import '../../../auth/presentation/widgets/auth_page_shell.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';

class NgoVerificationRejectedScreen extends ConsumerWidget {
  const NgoVerificationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ngo = ref.watch(currentNgoProvider).asData?.value;

    return AuthPageShell(
      title: 'Verification Rejected',
      subtitle: 'Please contact the AlloCare team for assistance.',
      cardMaxWidth: 480,
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verification Status',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rejected',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
                if (ngo != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    ngo.ngoName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'You may update your profile and resubmit for review. Our team will re-evaluate your application after changes are saved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Edit Profile',
            onPressed: () => context.go(RoutePaths.ngoProfileSetup),
            color: const Color(0xFFDC2626),
          ),
        ],
      ),
      footer: const SizedBox.shrink(),
    );
  }
}
