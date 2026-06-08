import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../services/ngo_service.dart';
import '../../../auth/presentation/widgets/auth_page_shell.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';

class NgoVerificationPendingScreen extends ConsumerWidget {
  const NgoVerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ngo = ref.watch(currentNgoProvider).asData?.value;

    return AuthPageShell(
      title: 'Application Submitted',
      subtitle:
          'Your NGO profile is awaiting approval from the AlloCare team.',
      cardMaxWidth: 480,
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 48,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verification Status',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
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
                      color: const Color(0xFF78350F),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Once approved in Firebase, you will gain access to the NGO Command Center — volunteer management, missions, inventory, and relief coordination.',
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
            color: const Color(0xFF1A5F7A),
          ),
        ],
      ),
      footer: const SizedBox.shrink(),
    );
  }
}
