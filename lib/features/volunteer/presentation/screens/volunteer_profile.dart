import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../services/auth_service.dart';
import '../../../../services/user_profile_service.dart';
import '../../../../services/volunteer_service.dart';
import '../controllers/volunteer_controller.dart';
import 'volunteer_profile_setup_screen.dart';
import '../../../profile/presentation/volunteer_registry_page.dart';
import 'volunteer_mission_history_page.dart';
import 'volunteer_ground_reports_history.dart';

final volunteerMissionsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final volunteerId = ref.watch(currentVolunteerProvider).asData?.value?.uid;
  if (volunteerId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('needs')
      .where('assignedVolunteerId', isEqualTo: volunteerId)
      .where('status', isEqualTo: 'completed')
      .snapshots();
});

final volunteerReportsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final volunteerId = ref.watch(currentVolunteerProvider).asData?.value?.uid;
  if (volunteerId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('ground_reports')
      .where('volunteerId', isEqualTo: volunteerId)
      .snapshots();
});

final volunteerRankProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final volunteer = ref.watch(currentVolunteerProvider).asData?.value;
  if (volunteer == null || volunteer.ngoId.isEmpty) {
    return Stream.value({'rank': 0, 'percentile': 0});
  }

  return FirebaseFirestore.instance
      .collection('volunteers')
      .where('ngoId', isEqualTo: volunteer.ngoId)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return {'rank': 0, 'percentile': 0};

        final volunteers = snapshot.docs.map((d) => d.data()).toList();
        
        volunteers.sort((a, b) {
          final m1 = (a['missionsCompleted'] as num? ?? a['totalCompletedMissions'] as num? ?? 0).toInt();
          final m2 = (b['missionsCompleted'] as num? ?? b['totalCompletedMissions'] as num? ?? 0).toInt();
          return m2.compareTo(m1);
        });
        
        final rankIndex = volunteers.indexWhere((v) => v['uid'] == volunteer.uid);
        final rank = rankIndex != -1 ? rankIndex + 1 : volunteers.length;
        final percentile = (rank / volunteers.length) * 100;

        return {
          'rank': rank,
          'percentile': percentile.round(),
        };
      });
});

final _notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final _languageProvider = StateProvider<String>((ref) => 'English');

class VolunteerProfileScreen extends ConsumerWidget {
  const VolunteerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentUserProfileProvider).asData?.value;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final volunteerState = ref.watch(volunteerControllerProvider);
    final volunteerDb = ref.watch(currentVolunteerProvider).asData?.value;
    
    final needsSnapshot = ref.watch(volunteerMissionsStreamProvider).asData?.value;
    final reportsSnapshot = ref.watch(volunteerReportsStreamProvider).asData?.value;

    final missionsCompletedCount = needsSnapshot?.docs.length ?? 0;
    final reportsSubmittedCount = reportsSnapshot?.docs.length ?? 0;

    double hoursServed = 0.0;
    int medicalMissions = 0;
    int reportsVerified = 0;
    int dynamicLivesImpacted = 0;

    if (needsSnapshot != null) {
      for (var doc in needsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        dynamicLivesImpacted += (data['peopleAffected'] as num?)?.toInt() ?? 0;

        final start = data['acceptedAt'] as Timestamp?;
        final end = data['completedAt'] as Timestamp?;
        if (start != null && end != null) {
          final diff = end.toDate().difference(start.toDate()).inMinutes;
          if (diff >= 0 && diff < 600) {
            hoursServed += diff / 60.0;
          }
        }
        final type = data['category'] as String? ?? data['type'] as String? ?? '';
        if (type.toLowerCase().contains('medical') || type.toLowerCase().contains('health')) {
          medicalMissions++;
        }
      }
    }

    if (reportsSnapshot != null) {
      for (var doc in reportsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? '';
        if (status.toLowerCase() == 'verified') {
          reportsVerified++;
        }
      }
    }

    final userName = volunteerDb?.displayName.trim().isNotEmpty == true
        ? volunteerDb!.displayName
        : (appUser?.displayName.trim().isNotEmpty == true
              ? appUser!.displayName
              : (authUser?.displayName?.trim() ?? 'Active Volunteer'));

    final location = volunteerDb != null
        ? '${volunteerDb.city}, ${volunteerDb.country}'
        : 'Aurangabad, India';

    final isOnDuty = volunteerDb?.isActiveOnField ?? volunteerState.isOnDuty;
    final peopleHelped = volunteerDb?.livesImpacted ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'ALLOCARE',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.5,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF1E293B),
                size: 20,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VolunteerProfileSetupScreen(),
                  ),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                context,
                ref,
                userName,
                location,
                isOnDuty,
                volunteerDb?.photoUrl ?? authUser?.photoURL,
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: _buildNavigationCard(
                      context,
                      title: 'Missions Completed',
                      value: missionsCompletedCount.toString(),
                      iconBg: const Color(0xFF10B981).withOpacity(0.1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VolunteerMissionHistoryPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNavigationCard(
                      context,
                      title: 'Reports Submitted',
                      value: reportsSubmittedCount.toString(),
                      iconBg: const Color(0xFF4F46E5).withOpacity(0.1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const VolunteerGroundReportsHistoryPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _buildImpactStatistics(
                peopleAssisted: peopleHelped > 0 ? peopleHelped : dynamicLivesImpacted,
                hoursServed: hoursServed.round(),
                skillsCount: volunteerDb?.skills.length ?? 0,
              ),
              const SizedBox(height: 48),

              _buildSkillsSection(volunteerDb?.skills ?? []),
              const SizedBox(height: 48),
              _buildCommunityImpact(context, ref),
              const SizedBox(height: 48),
              _buildRecentMissions(context, volunteerDb?.uid),
              const SizedBox(height: 48),
              _buildSettings(context, ref),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String userName,
    String location,
    bool isOnDuty,
    String? photoUrl,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'V',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          userName,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Verified Volunteer',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF047857),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          location,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnDuty
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Available for Deployment',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 16),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isOnDuty,
                  onChanged: (_) => ref
                      .read(volunteerControllerProvider.notifier)
                      .toggleDutyStatus(),
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF10B981),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImpactStatistics({
    required int peopleAssisted,
    required int hoursServed,
    required int skillsCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IMPACT STATISTICS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatChip(Icons.favorite_rounded, const Color(0xFFEF4444), 'Lives Impacted', peopleAssisted.toString()),
            _buildStatChip(Icons.timer_rounded, const Color(0xFFF59E0B), 'Hours Served', hoursServed.toString()),
            _buildStatChip(Icons.verified_rounded, const Color(0xFF3B82F6), 'Certified Skills', skillsCount.toString()),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, Color iconColor, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(List<String> rawSkills) {
    final skills = rawSkills.isNotEmpty
        ? rawSkills
        : [
            'First Aid',
            'Disaster Response',
            'Community Outreach',
            'Mental Health Support',
            'Medical Assistance',
            'Driving',
            'Logistics Support',
          ];

    final certifiedSkills = [
      'First Aid',
      'Emergency Response',
      'Community Health',
      'Disaster Management',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SKILLS & CERTIFICATIONS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (var skill in skills) _buildSkillChip(skill, false),
            for (var cert in certifiedSkills) _buildSkillChip(cert, true),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label, bool isCertified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCertified
            ? const Color(0xFF10B981).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCertified
              ? const Color(0xFF10B981).withOpacity(0.2)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        isCertified ? '$label Certified' : label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: isCertified ? FontWeight.w600 : FontWeight.w500,
          color: isCertified
              ? const Color(0xFF047857)
              : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildCommunityImpact(BuildContext context, WidgetRef ref) {
    final rankData = ref.watch(volunteerRankProvider).asData?.value ?? {'rank': 0, 'percentile': 0};
    final rank = rankData['rank'] as int;
    final percentile = rankData['percentile'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNITY IMPACT',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VolunteerRegistryPage(initialTabIndex: 1),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.leaderboard_rounded,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMMUNITY RANKING',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rank > 0 ? 'Rank #$rank' : 'Calculating...',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (rank > 0 && percentile > 0 && percentile <= 100)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Top $percentile%',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'Among active responders',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMissions(BuildContext context, String? volunteerId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT MISSIONS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: const Color(0xFF94A3B8),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VolunteerMissionHistoryPage(),
                ),
              ),
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (volunteerId == null)
          const Text('No recent missions.')
        else
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('needs')
                .where('assignedVolunteerId', isEqualTo: volunteerId)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'No completed missions yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                );
              }

              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTs =
                    aData['completedAt'] as Timestamp? ??
                    aData['createdAt'] as Timestamp?;
                final bTs =
                    bData['completedAt'] as Timestamp? ??
                    bData['createdAt'] as Timestamp?;
                if (aTs == null && bTs == null) return 0;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return bTs.compareTo(aTs);
              });

              final displayDocs = docs.take(5).toList();

              return Column(
                children: displayDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title =
                      data['title']?.toString() ?? 'Emergency Mission';
                  final category = data['category']?.toString() ?? 'General';
                  final ts =
                      data['completedAt'] as Timestamp? ??
                      data['createdAt'] as Timestamp?;

                  String dateStr = 'Unknown';
                  if (ts != null) {
                    final diff = DateTime.now().difference(ts.toDate());
                    if (diff.inDays > 0) {
                      dateStr = '${diff.inDays}d ago';
                    } else if (diff.inHours > 0) {
                      dateStr = '${diff.inHours}h ago';
                    } else if (diff.inMinutes > 0) {
                      dateStr = '${diff.inMinutes}m ago';
                    } else {
                      dateStr = 'Just now';
                    }
                  }
                  return _buildMissionCard(
                    title,
                    category,
                    'Completed',
                    dateStr,
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMissionCard(
    String title,
    String category,
    String status,
    String date,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context, WidgetRef ref) {
    final notificationsEnabled = ref.watch(_notificationsEnabledProvider);
    final language = ref.watch(_languageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SETTINGS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildSettingsRow(
                Icons.notifications_outlined,
                'Notifications',
                isToggle: true,
                toggleValue: notificationsEnabled,
                onToggle: (val) {
                  ref.read(_notificationsEnabledProvider.notifier).state = val;
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSettingsRow(
                Icons.language_rounded,
                'Language ($language)',
                isToggle: false,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Select Language'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ['English', 'Hindi', 'Marathi'].map((lang) {
                          return ListTile(
                            title: Text(lang),
                            onTap: () {
                              ref.read(_languageProvider.notifier).state = lang;
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                onTap: () async {
                  await ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(IconData icon, String title, {bool isToggle = false, bool toggleValue = false, ValueChanged<bool>? onToggle, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF475569)),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E293B),
        ),
      ),
      onTap: onTap,
      trailing: isToggle
          ? Switch(
              value: toggleValue,
              onChanged: onToggle,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF10B981),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE2E8F0),
            )
          : const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
    );
  }
}
