import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/app_user.dart';
import '../../../models/ngo_model.dart';
import '../../../models/volunteer_model.dart';
import '../../../models/insight_model.dart';
import '../../../services/ngo_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';
import 'manage_volunteer_page.dart';
import 'volunteer_registry_page.dart';
import '../../insights/presentation/sentinel_strategic_hub_page.dart';
import '../../insights/presentation/smart_allocation_center_page.dart';
import '../../reports/presentation/reports_center_page.dart';
import '../../reports/presentation/ngo_reports_center_page.dart';
import '../../../core/router/route_paths.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const MethodChannel _pnvChannel = MethodChannel(
    'com.example.allocare_app/pnv',
  );

  bool _isVerifyingPhone = false;
  String? _verifiedPhone;

  void _showVerificationSuccessToast(String phone) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F7A47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Identity confirmed via OTP-less Firebase PNV. $phone is now verified.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistVerifiedPhone(String verifiedPhone) async {
    final profileService = ref.read(userProfileServiceProvider);
    final authUser = ref.read(authStateProvider).asData?.value;

    if (authUser == null) return;

    final existing = await profileService.getById(authUser.uid);
    final now = DateTime.now();

    final updated = AppUser(
      id: authUser.uid,
      email: authUser.email ?? existing?.email ?? '',
      displayName: (authUser.displayName ?? existing?.displayName ?? '').trim(),
      phoneNumber: verifiedPhone,
      role: existing?.role ?? AppUserRole.ngo,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      inventoryItems: existing?.inventoryItems ?? const [],
    );

    await profileService.upsert(updated);
  }

  Future<void> _verifyPhone() async {
    setState(() => _isVerifyingPhone = true);

    try {
      final response = await _pnvChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getVerifiedPhone',
      );
      final phone = (response?['phoneNumber'] as String?)?.trim();

      if (phone != null && phone.isNotEmpty) {
        await _persistVerifiedPhone(phone);
      }

      if (!mounted) return;
      setState(() {
        _verifiedPhone = phone;
      });

      if (phone != null && phone.isNotEmpty) {
        _showVerificationSuccessToast(phone);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Phone number verified.')));
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Platform verification failed: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone verification failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingPhone = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).asData?.value;
    final ngo = ref.watch(currentNgoProvider).asData?.value;
    final ngoId = ref.watch(effectiveNgoIdProvider) ?? '';
    final authService = ref.watch(authServiceProvider);

    if (ngoId.isEmpty || ngo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('volunteers')
            .where('ngoId', isEqualTo: ngoId)
            .snapshots(),
        builder: (context, volunteerSnapshot) {
          final docs = volunteerSnapshot.data?.docs ?? [];
          final volunteers = docs
              .map(
                (doc) => VolunteerModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>? ?? {},
                ),
              )
              .toList();

          final activeVolunteers = volunteers
              .where(
                (v) =>
                    v.verificationStatus ==
                    VolunteerVerificationStatus.approved,
              )
              .length;

          final pendingVolunteers = volunteers
              .where(
                (v) =>
                    v.verificationStatus == VolunteerVerificationStatus.pending,
              )
              .length;

          final pendingVolunteersList = volunteers
              .where(
                (v) =>
                    v.verificationStatus == VolunteerVerificationStatus.pending,
              )
              .toList();

          final activeOnField = volunteers
              .where(
                (v) =>
                    v.verificationStatus ==
                        VolunteerVerificationStatus.approved &&
                    v.isActiveOnField,
              )
              .length;

          // Find Top Volunteer by missionsCompleted
          VolunteerModel? topVolunteer;
          final approvedVolunteers = volunteers
              .where(
                (v) =>
                    v.verificationStatus ==
                    VolunteerVerificationStatus.approved,
              )
              .toList();
          if (approvedVolunteers.isNotEmpty) {
            approvedVolunteers.sort(
              (a, b) => b.missionsCompleted.compareTo(a.missionsCompleted),
            );
            topVolunteer = approvedVolunteers.first;
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SECTION 1: NGO Header
                _buildNgoHeader(ngo, activeOnField),
                const SizedBox(height: 24),

                // SECTION 2: Workforce Command Center
                _buildWorkforceCommandCenter(
                  context,
                  activeVolunteers,
                  pendingVolunteers,
                  topVolunteer,
                  pendingVolunteersList,
                ),
                const SizedBox(height: 24),

                // SECTION 3: Gemini Intelligence Brief
                _buildGeminiBrief(ngoId),
                const SizedBox(height: 24),

                // SECTION 4: Impact Force Leaderboard
                _buildLeaderboard(context, approvedVolunteers),
                const SizedBox(height: 24),

                // SECTION 5: Firebase PNV Verification
                _buildPnvVerificationCard(),
                const SizedBox(height: 24),

                // SECTION 6: Logout
                ElevatedButton.icon(
                  onPressed: () => authService.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('LOGOUT FROM COMMAND CENTER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNgoHeader(NgoModel ngo, int activeOnField) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFF0FDF4),
                backgroundImage: ngo.logoUrl.isNotEmpty
                    ? NetworkImage(ngo.logoUrl)
                    : null,
                child: ngo.logoUrl.isEmpty
                    ? Text(
                        ngo.ngoName.isNotEmpty
                            ? ngo.ngoName[0].toUpperCase()
                            : 'N',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF15803D),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ngo.ngoName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ngo.isVerified
                          ? 'Verified Relief Partner'
                          : 'Relief Partner',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0284C7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${ngo.city}, ${ngo.state}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Right Column for Verified badge and Edit Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (ngo.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF0284C7),
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'VERIFIED',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0369A1),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: Color(0xFF475569),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            context.push(RoutePaths.ngoProfileSetup),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Column(
            children: [
              // Row 1 (Compact): Operations layer (Half Width)
              Row(
                children: [
                  Expanded(
                    child: _ClickableStatCard(
                      label: 'Active On Field',
                      value: '$activeOnField',
                      icon: Icons.people_outline_rounded,
                      color: const Color(0xFF10B981),
                      subtitle: 'Volunteers currently deployed',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ManageVolunteerPage(
                              filterActiveOnField: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ClickableStatCard(
                      label: 'Active Missions',
                      value: '${ngo.activeMissionCount}',
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFFDC2626),
                      subtitle: 'Ongoing relief operations',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SmartAllocationCenterPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2 (Priority): Intelligence layer (Full Width)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ngo_reports')
                    .where(
                      'ngoId',
                      isEqualTo: ref.watch(effectiveNgoIdProvider) ?? '',
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return _buildPriorityStatCard(
                    label: 'Reports Uploaded',
                    value: '$count Report${count == 1 ? "" : "s"}',
                    subtitle: 'Upload field intelligence for Gemini analysis',
                    icon: Icons.upload_file_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NgoReportsCenterPage(),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              // Row 3 (Priority): Crisis layer (Full Width)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('needs')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return _buildPriorityStatCard(
                    label: 'All Needs',
                    value: '$count Active Incident${count == 1 ? "" : "s"}',
                    subtitle: 'Platform-wide actionable incidents',
                    icon: Icons.analytics_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsCenterPage(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityStatCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Thin colored accent strip on the left
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(color: color),
                ),
                // Content Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Subtly tinted icon container (no border)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: color,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkforceCommandCenter(
    BuildContext context,
    int activeVolunteers,
    int pendingRequests,
    VolunteerModel? topVolunteer,
    List<VolunteerModel> pendingVolunteersList,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ManageVolunteerPage(initialTabIndex: 0),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WORKFORCE COMMAND CENTER',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MetricBadge(
                    label: 'Total Volunteers',
                    value: '$activeVolunteers',
                    color: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const VolunteerRegistryPage(initialTabIndex: 0),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _MetricBadge(
                    label: 'Pending Requests',
                    value: '$pendingRequests',
                    color: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const ManageVolunteerPage(initialTabIndex: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (pendingRequests > 0 && pendingVolunteersList.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED), // Warm light orange
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFEDD5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFEA580C),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pendingRequests Volunteer${pendingRequests > 1 ? "s" : ""} Awaiting Approval',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFFE5D9),
                            backgroundImage:
                                pendingVolunteersList.first.photoUrl != null &&
                                    pendingVolunteersList
                                        .first
                                        .photoUrl!
                                        .isNotEmpty
                                ? NetworkImage(
                                    pendingVolunteersList.first.photoUrl!,
                                  )
                                : null,
                            child:
                                pendingVolunteersList.first.photoUrl == null ||
                                    pendingVolunteersList
                                        .first
                                        .photoUrl!
                                        .isEmpty
                                ? Text(
                                    pendingVolunteersList
                                            .first
                                            .displayName
                                            .isNotEmpty
                                        ? pendingVolunteersList
                                              .first
                                              .displayName[0]
                                              .toUpperCase()
                                        : 'V',
                                    style: const TextStyle(
                                      color: Color(0xFFEA580C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pendingVolunteersList.first.displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7C2D12),
                                  ),
                                ),
                                Text(
                                  pendingVolunteersList
                                          .first
                                          .formattedSpecializations
                                          .isNotEmpty
                                      ? pendingVolunteersList
                                            .first
                                            .formattedSpecializations
                                            .join(', ')
                                      : 'General Specialist',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF9A3412),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ManageVolunteerPage(
                                  initialTabIndex: 1,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.rate_review_rounded, size: 16),
                          label: const Text('Review Application'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'TOP PERFORMER',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (topVolunteer != null)
                _TopVolunteerCard(volunteer: topVolunteer)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'No active volunteers. Approve pending requests to deploy responders.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeminiBrief(String ngoId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ngo_reports')
          .where('ngoId', isEqualTo: ngoId)
          .snapshots(),
      builder: (context, reportsSnapshot) {
        final reportsCount = reportsSnapshot.data?.docs.length ?? 0;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('insights')
              .where('ngoId', isEqualTo: ngoId)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _GeminiBriefCard(
                insight: null,
                reportsCount: reportsCount,
                updatedAt: null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SentinelStrategicHubPage(),
                    ),
                  );
                },
              );
            }

            final doc = docs.first;
            final insight = InsightModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>? ?? {},
            );
            final rawData = doc.data() as Map<String, dynamic>?;
            final updatedAt = rawData?['updatedAt'] as Timestamp?;

            return _GeminiBriefCard(
              insight: insight,
              reportsCount: reportsCount,
              updatedAt: updatedAt,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SentinelStrategicHubPage(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboard(
    BuildContext context,
    List<VolunteerModel> approvedVolunteers,
  ) {
    // Sort in memory by missionsCompleted to make sure it represents top performers correctly
    final sortedVolunteers = List<VolunteerModel>.from(approvedVolunteers);
    sortedVolunteers.sort(
      (a, b) => b.missionsCompleted.compareTo(a.missionsCompleted),
    );
    final top3 = sortedVolunteers.take(3).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VolunteerRegistryPage(initialTabIndex: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'IMPACT FORCE LEADERBOARD',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (top3.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'No active volunteers found on the leaderboard.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: top3.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _LeaderboardItem(
                      rank: index + 1,
                      volunteer: top3[index],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Full Leaderboard',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF2563EB),
                      size: 14,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPnvVerificationCard() {
    final hasVerifiedPhone =
        _verifiedPhone != null && _verifiedPhone!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasVerifiedPhone
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasVerifiedPhone
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasVerifiedPhone
                    ? Icons.verified_user_rounded
                    : Icons.shield_rounded,
                color: hasVerifiedPhone
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF475569),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Firebase PNV Verification',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (hasVerifiedPhone)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VERIFIED',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Secure, OTP-less SIM-backed identity verification powered by Firebase Phone Number Verification.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          if (hasVerifiedPhone) ...[
            const SizedBox(height: 10),
            Text(
              'Verified phone: $_verifiedPhone',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isVerifyingPhone ? null : _verifyPhone,
                icon: _isVerifyingPhone
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.vpn_key_rounded, size: 14),
                label: Text(
                  _isVerifyingPhone ? 'Verifying...' : 'Verify Phone Identity',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF475569),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopVolunteerCard extends StatelessWidget {
  final VolunteerModel volunteer;

  const _TopVolunteerCard({required this.volunteer});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VolunteerRegistryPage(initialTabIndex: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF0FDF4),
                backgroundImage:
                    volunteer.photoUrl != null && volunteer.photoUrl!.isNotEmpty
                    ? NetworkImage(volunteer.photoUrl!)
                    : null,
                child: volunteer.photoUrl == null || volunteer.photoUrl!.isEmpty
                    ? Text(
                        volunteer.displayName.isNotEmpty
                            ? volunteer.displayName[0].toUpperCase()
                            : 'V',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            volunteer.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '🏆 Top Performer',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      volunteer.formattedSpecializations.isNotEmpty
                          ? volunteer.formattedSpecializations.join(', ')
                          : 'General Specialist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${volunteer.missionsCompleted}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  Text(
                    'Missions',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeminiBriefCard extends StatelessWidget {
  final InsightModel? insight;
  final int reportsCount;
  final Timestamp? updatedAt;
  final VoidCallback onTap;

  const _GeminiBriefCard({
    this.insight,
    required this.reportsCount,
    this.updatedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = updatedAt != null
        ? _timeAgo(updatedAt!.toDate())
        : 'Recently';

    return Material(
      color: const Color.fromARGB(255, 28, 41, 71),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF38BDF8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Gemini Intelligence Brief',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C4A6E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AI',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          insight != null
                              ? 'Last analyzed $timeStr'
                              : 'Active Analysis Engine',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (insight != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C4A6E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.psychology_alt_rounded,
                            color: Color(0xFF38BDF8),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(insight!.score * 100).toStringAsFixed(0)}% Conf.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (insight != null) ...[
                Text(
                  insight!.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight!.recommendation,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFCBD5E1),
                    height: 1.4,
                  ),
                ),
              ] else ...[
                Text(
                  'Gemini has not generated an intelligence brief yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload reports or create incidents to trigger AI analysis.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFCBD5E1),
                    height: 1.4,
                  ),
                ),
              ],
              const Divider(height: 24, color: Color(0xFF334155)),
              Row(
                children: [
                  Text(
                    'Reports Synthesized: $reportsCount',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View AI Insights',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF38BDF8),
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ClickableStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String subtitle;

  const _ClickableStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label == 'Active On Field'
        ? 'Active On\nField'
        : (label == 'Active Missions' ? 'Active\nMissions' : label);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: color, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                displayLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final VolunteerModel volunteer;

  const _LeaderboardItem({required this.rank, required this.volunteer});

  @override
  Widget build(BuildContext context) {
    final Color rankColor;
    final String rankSuffix;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFF59E0B);
        rankSuffix = '1st';
        break;
      case 2:
        rankColor = const Color(0xFF94A3B8);
        rankSuffix = '2nd';
        break;
      default:
        rankColor = const Color(0xFFB45309);
        rankSuffix = '3rd';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              rankSuffix,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundImage:
                volunteer.photoUrl != null && volunteer.photoUrl!.isNotEmpty
                ? NetworkImage(volunteer.photoUrl!)
                : null,
            child: volunteer.photoUrl == null || volunteer.photoUrl!.isEmpty
                ? Text(
                    volunteer.displayName.isNotEmpty
                        ? volunteer.displayName[0].toUpperCase()
                        : 'V',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  volunteer.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  volunteer.formattedSpecializations.isNotEmpty
                      ? volunteer.formattedSpecializations.first
                      : 'General Specialist',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${volunteer.missionsCompleted} Missions',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
