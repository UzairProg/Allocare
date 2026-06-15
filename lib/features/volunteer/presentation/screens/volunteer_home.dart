import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';
import '../../../../services/user_profile_service.dart';
import '../../../../services/volunteer_service.dart';
import '../../../../models/volunteer_model.dart';
import '../../../../services/smart_allocation_service.dart';
import '../../../../services/ngo_service.dart';
import '../../../../models/ngo_model.dart';
import '../controllers/volunteer_controller.dart';
import 'volunteer_profile.dart';
import 'volunteer_mission_history_page.dart';
import '../../../map/presentation/map_screen.dart';

// ==========================================
// DATA MODELS FOR DYNAMIC RENDERING
// ==========================================

class VolunteerProfileModel {
  final String name;
  final String region;
  final String? photoUrl;
  final List<String> skillTags;
  final bool isOnDuty;
  final bool isGemmaVerified;

  const VolunteerProfileModel({
    required this.name,
    required this.region,
    this.photoUrl,
    required this.skillTags,
    required this.isOnDuty,
    this.isGemmaVerified = true,
  });
}

class AiInsightPreviewModel {
  final String title;
  final String body;
  final String status;

  const AiInsightPreviewModel({
    required this.title,
    required this.body,
    required this.status,
  });
}

class GeminiScanFeedModel {
  final List<String> feedMessages;
  final List<AiInsightPreviewModel> insightPreviews;

  const GeminiScanFeedModel({
    required this.feedMessages,
    required this.insightPreviews,
  });
}

class GeminiDispatchDataModel {
  final String hazardType;
  final String sector;
  final String location;
  final int reportsVerified;
  final String estImpact;
  final String recommendedAction;
  final List<String> assignmentReasons;
  final String priorityLevel;
  final bool isCritical;

  const GeminiDispatchDataModel({
    required this.hazardType,
    required this.sector,
    required this.location,
    required this.reportsVerified,
    required this.estImpact,
    required this.recommendedAction,
    required this.assignmentReasons,
    required this.priorityLevel,
    this.isCritical = false,
  });
}

class ValidationMetricsModel {
  final int verifiedCount;
  final int totalCount;
  final String notes;

  const ValidationMetricsModel({
    required this.verifiedCount,
    required this.totalCount,
    required this.notes,
  });
}

class ImpactMetricsModel {
  final int livesImpacted;
  final int livesImpactedChange;
  final double timeSavedHrs;
  final double timeSavedChange;
  final int serviceHours;
  final int missionsCompleted;
  final int reportsSubmitted;

  const ImpactMetricsModel({
    required this.livesImpacted,
    required this.livesImpactedChange,
    required this.timeSavedHrs,
    required this.timeSavedChange,
    required this.serviceHours,
    required this.missionsCompleted,
    required this.reportsSubmitted,
  });
}

class TacticalRadarMetricsModel {
  final int nearbyAlerts;
  final int activePeers;
  final String recentMissionType;
  final String recentMissionTime;
  final int partnerNgos;

  const TacticalRadarMetricsModel({
    required this.nearbyAlerts,
    required this.activePeers,
    required this.recentMissionType,
    required this.recentMissionTime,
    required this.partnerNgos,
  });
}

// ==========================================
// STATE PROVIDERS FOR SCALABLE INTEGRATION
// ==========================================

final volunteerProfileProvider = Provider<VolunteerProfileModel>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final authUser = ref.watch(authStateProvider).asData?.value;
  final volunteerState = ref.watch(volunteerControllerProvider);
  final volunteerDb = ref.watch(currentVolunteerProvider).asData?.value;

  final skills =
      (volunteerDb?.specializations ?? volunteerDb?.skills ?? const ['medical'])
          .map((s) {
            switch (s) {
              case 'medical':
                return '🩺 Medical';
              case 'food_nutrition':
                return '🍲 Food & Nutrition';
              case 'shelter_essentials':
                return '⛺ Shelter & Essentials';
              case 'disaster_emergency':
                return '🚨 Disaster & Emergency';
              case 'mental_wellbeing':
                return '🧠 Mental Health';
              case 'education_child_support':
                return '📚 Education';
              case 'elderly_special_care':
                return '👴 Elderly Care';
              case 'livelihood_financial_support':
                return '💼 Livelihood';
              case 'women_safety':
                return '🛡️ Women\'s Safety';
              case 'others':
                return '🤝 General Support';
              default:
                return s;
            }
          })
          .toList();

  return VolunteerProfileModel(
    name:
        volunteerDb?.displayName ??
        profile?.displayName ??
        authUser?.displayName ??
        'Uzair',
    region: volunteerDb != null
        ? '${volunteerDb.city}, ${volunteerDb.state}'
        : 'Chhatrapati Sambhajinagar',
    photoUrl: volunteerDb?.photoUrl ?? authUser?.photoURL,
    skillTags: skills.isNotEmpty ? skills : const ['🩺 Certified Medic'],
    isOnDuty: volunteerDb?.isActiveOnField ?? volunteerState.isOnDuty,
    isGemmaVerified: volunteerDb != null
        ? volunteerDb.verificationStatus.isApproved
        : true,
  );
});

final geminiScanFeedProvider = Provider<GeminiScanFeedModel>((ref) {
  final profile = ref.watch(volunteerProfileProvider);
  final isMedical = profile.skillTags.any(
    (t) =>
        t.toLowerCase().contains('medic') || t.toLowerCase().contains('health'),
  );
  final isLogistics = profile.skillTags.any(
    (t) =>
        t.toLowerCase().contains('logistic') ||
        t.toLowerCase().contains('transport'),
  );
  final isFood = profile.skillTags.any(
    (t) =>
        t.toLowerCase().contains('food') || t.toLowerCase().contains('nutri'),
  );
  final isMental = profile.skillTags.any(
    (t) =>
        t.toLowerCase().contains('mental') || t.toLowerCase().contains('psych'),
  );

  String insightText = '';
  if (isMedical) {
    insightText =
        'Medical assistance requests have increased in nearby sectors during the last 6 hours.';
  } else if (isFood) {
    insightText =
        'Food distribution demand is increasing nearby based on recent field reports.';
  } else if (isLogistics) {
    insightText =
        'Supply movement requirements are increasing. Resource transportation demand detected.';
  } else if (isMental) {
    insightText =
        'Psychological support requests are increasing. Community counseling assistance required.';
  } else {
    insightText =
        'General assistance and emergency response requests have increased in nearby sectors.';
  }

  return GeminiScanFeedModel(
    feedMessages: const [
      'Monitoring NGO incident reports...',
      'Reviewing nearby emergency requests...',
      'Checking verified field reports...',
      'Analyzing resource requirements...',
      'Scanning active disaster alerts...',
    ],
    insightPreviews: [
      AiInsightPreviewModel(
        title: 'Gemini Insight',
        body: insightText,
        status: '',
      ),
    ],
  );
});

final geminiDispatchProvider = Provider<GeminiDispatchDataModel>((ref) {
  final profile = ref.watch(volunteerProfileProvider);

  final reasons = <String>[
    if (profile.skillTags.any((t) => t.toLowerCase().contains('medic')))
      'Certified Medic',
    if (profile.isOnDuty) 'Active On Field',
    '1.4 km from affected area',
    'Previous water-response missions',
  ];

  return GeminiDispatchDataModel(
    hazardType: 'Suspected Waterborne Risk',
    sector: 'Sector 4',
    location: 'Mahananda Colony',
    reportsVerified: 23,
    estImpact: '150–250 People',
    recommendedAction: 'Deploy Water Purification Support',
    assignmentReasons: reasons,
    priorityLevel: 'HIGH',
    isCritical: true,
  );
});

final validationMetricsProvider = Provider<ValidationMetricsModel>((ref) {
  return const ValidationMetricsModel(
    verifiedCount: 12,
    totalCount: 15,
    notes: 'On-device AI validation • Tamper-proof',
  );
});

final impactMetricsProvider = Provider<ImpactMetricsModel>((ref) {
  final volunteerDb = ref.watch(currentVolunteerProvider).asData?.value;
  final missionsSnapshot = ref
      .watch(volunteerMissionsStreamProvider)
      .asData
      ?.value;
  final reportsSnapshot = ref
      .watch(volunteerReportsStreamProvider)
      .asData
      ?.value;

  int dynamicLivesImpacted = 0;
  double hoursServed = 0.0;
  int missionsCompleted = volunteerDb?.missionsCompleted ?? 0;

  if (missionsSnapshot != null) {
    for (var doc in missionsSnapshot.docs) {
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
    }
  }

  int actualLivesImpacted = volunteerDb?.livesImpacted ?? 0;
  if (actualLivesImpacted == 0) {
    actualLivesImpacted = dynamicLivesImpacted;
  }

  int actualMissions = missionsSnapshot != null
      ? missionsSnapshot.docs.length
      : missionsCompleted;
  int actualReports = reportsSnapshot != null ? reportsSnapshot.docs.length : 0;

  return ImpactMetricsModel(
    livesImpacted: actualLivesImpacted,
    livesImpactedChange: 0,
    timeSavedHrs: hoursServed,
    timeSavedChange: 0,
    serviceHours: hoursServed.round(),
    missionsCompleted: actualMissions,
    reportsSubmitted: actualReports,
  );
});

final nearbyAlertsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('needs')
      .where('status', isEqualTo: 'open')
      .snapshots();
});

final activePeersStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((
  ref,
) {
  final ngoId = ref.watch(currentVolunteerProvider).asData?.value?.ngoId;
  if (ngoId == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('volunteers')
      .where('ngoId', isEqualTo: ngoId)
      .where('isActiveOnField', isEqualTo: true)
      .snapshots();
});

final allNgosStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance.collection('ngos').snapshots();
});

final tacticalRadarProvider = Provider<TacticalRadarMetricsModel>((ref) {
  final alertsSnap = ref.watch(nearbyAlertsStreamProvider).asData?.value;
  final peersSnap = ref.watch(activePeersStreamProvider).asData?.value;
  final missionsSnap = ref.watch(volunteerMissionsStreamProvider).asData?.value;
  final ngosSnap = ref.watch(allNgosStreamProvider).asData?.value;

  String recentType = 'No recent missions';
  String recentTime = 'Awaiting deployment';

  if (missionsSnap != null && missionsSnap.docs.isNotEmpty) {
    final docs = missionsSnap.docs.toList();
    docs.sort((a, b) {
      final timeA =
          (a.data() as Map<String, dynamic>)['completedAt'] as Timestamp?;
      final timeB =
          (b.data() as Map<String, dynamic>)['completedAt'] as Timestamp?;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });

    final mostRecent = docs.first.data() as Map<String, dynamic>;
    recentType = mostRecent['category'] as String? ?? 'General Support';

    final completedAt = mostRecent['completedAt'] as Timestamp?;
    if (completedAt != null) {
      final diff = DateTime.now().difference(completedAt.toDate());
      if (diff.inDays > 0) {
        recentTime = 'Completed ${diff.inDays} days ago';
      } else if (diff.inHours > 0) {
        recentTime = 'Completed ${diff.inHours} hours ago';
      } else if (diff.inMinutes > 0) {
        recentTime = 'Completed ${diff.inMinutes} mins ago';
      } else {
        recentTime = 'Completed just now';
      }
    }
  }

  int filteredNgosCount = 0;
  if (ngosSnap != null) {
    filteredNgosCount = ngosSnap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final websiteUrl = data['website'] ?? data['websiteUrl'] ?? data['site'];
      return websiteUrl != null && websiteUrl.toString().trim().isNotEmpty;
    }).length;
  }

  return TacticalRadarMetricsModel(
    nearbyAlerts: alertsSnap?.docs.length ?? 0,
    activePeers: peersSnap?.docs.length ?? 0,
    recentMissionType: recentType,
    recentMissionTime: recentTime,
    partnerNgos: filteredNgosCount,
  );
});

// ==========================================
// MAIN WIDGET SCREEN
// ==========================================

class VolunteerHomeScreen extends ConsumerStatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  ConsumerState<VolunteerHomeScreen> createState() =>
      _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends ConsumerState<VolunteerHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerAnimController;
  int _animationTrigger = 0;

  void _triggerCountAnimation() {
    setState(() {
      _animationTrigger++;
    });
  }

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch dynamic telemetry models
    final profileData = ref.watch(volunteerProfileProvider);
    final volunteerDb = ref.watch(currentVolunteerProvider).asData?.value;
    final scanFeedData = ref.watch(geminiScanFeedProvider);
    final validationData = ref.watch(validationMetricsProvider);
    final impactData = ref.watch(impactMetricsProvider);
    final radarData = ref.watch(tacticalRadarProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFDFE),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            bottom: 130,
          ), // Ensure extra space before bottom navigation bar
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Unified Operational Header (Identity & Status switch in one card)
                _buildExecutiveHeaderCard(context, profileData),
                const SizedBox(height: 20),

                volunteerDb == null
                    ? _buildStandbyScannerCard(
                        context,
                        impactData,
                        scanFeedData,
                        _animationTrigger,
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('needs')
                            .where(
                              'matchedVolunteerId',
                              isEqualTo: volunteerDb.uid,
                            )
                            .where('status', isEqualTo: 'pending_acceptance')
                            .limit(1)
                            .snapshots(),
                        builder: (context, pendingSnapshot) {
                          final hasPending =
                              pendingSnapshot.hasData &&
                              pendingSnapshot.data!.docs.isNotEmpty;
                          final hasActive =
                              volunteerDb.currentMissionId != null;

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: hasActive
                                ? StreamBuilder<DocumentSnapshot>(
                                    key: ValueKey(
                                      'active_${volunteerDb.currentMissionId}',
                                    ),
                                    stream: FirebaseFirestore.instance
                                        .collection('needs')
                                        .doc(volunteerDb.currentMissionId)
                                        .snapshots(),
                                    builder: (context, activeSnapshot) {
                                      if (activeSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const SizedBox(
                                          height: 200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        );
                                      }
                                      if (!activeSnapshot.hasData ||
                                          !activeSnapshot.data!.exists) {
                                        return _buildStandbyScannerCard(
                                          context,
                                          impactData,
                                          scanFeedData,
                                          _animationTrigger,
                                        );
                                      }
                                      final needData =
                                          activeSnapshot.data!.data()
                                              as Map<String, dynamic>;
                                      return _buildRealDispatchCard(
                                        context,
                                        needId: volunteerDb.currentMissionId!,
                                        needData: needData,
                                        volunteerStatus: volunteerDb.status,
                                        volunteerDb: volunteerDb,
                                      );
                                    },
                                  )
                                : hasPending
                                ? _buildRealDispatchCard(
                                    context,
                                    needId: pendingSnapshot.data!.docs.first.id,
                                    needData:
                                        pendingSnapshot.data!.docs.first.data()
                                            as Map<String, dynamic>,
                                    volunteerStatus: 'pending_response',
                                    volunteerDb: volunteerDb,
                                  )
                                : _buildStandbyScannerCard(
                                    context,
                                    impactData,
                                    scanFeedData,
                                    _animationTrigger,
                                  ),
                          );
                        },
                      ),
                const SizedBox(height: 20),

                // 3. Volunteer Impact Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VOLUNTEER IMPACT',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _triggerCountAnimation();
                        _showVolunteerImpactInfoSheet(context);
                      },
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildVolunteerImpactSection(
                  context,
                  impactData,
                  _animationTrigger,
                ),
                const SizedBox(height: 24),

                // 4. Uniform Tactical Local Radar Grid
                Text(
                  'LOCAL INSIGHTS (3KM RADIUS)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _buildTacticalGrid(radarData),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. OPERATIONAL IDENTITY & STATUS HUB (Single Card Layout)
  Widget _buildExecutiveHeaderCard(
    BuildContext context,
    VolunteerProfileModel data,
  ) {
    const chipStyles = <(Color bg, Color fg, Color border, IconData icon)>[
      (
        Color(0xFFF0FDF4),
        Color(0xFF15803D),
        Color(0xFF86EFAC),
        Icons.medical_services_outlined,
      ),
      (
        Color(0xFFEFF6FF),
        Color(0xFF1D4ED8),
        Color(0xFF93C5FD),
        Icons.emergency_outlined,
      ),
      (
        Color(0xFFF5F3FF),
        Color(0xFF7C3AED),
        Color(0xFFC4B5FD),
        Icons.groups_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileAvatar(data),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.name,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data.region,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var i = 0; i < data.skillTags.take(2).length; i++)
                      _buildCompactChip(
                        data.skillTags[i],
                        chipStyles[i % chipStyles.length],
                      ),
                  ],
                ),
                if (data.isGemmaVerified) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'NGO Verified Volunteer',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Go Active On Field',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 8),
                Transform.scale(
                  scale: 0.92,
                  child: Switch(
                    value: data.isOnDuty,
                    onChanged: (_) {
                      ref
                          .read(volunteerControllerProvider.notifier)
                          .toggleDutyStatus();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    thumbColor: WidgetStateProperty.resolveWith(
                      (states) => Colors.white,
                    ),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF10B981);
                      }
                      return const Color(0xFFE2E8F0);
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusIndicatorDot(isActive: data.isOnDuty),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        data.isOnDuty ? 'Active & Syncing' : 'Standby Mode',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: data.isOnDuty
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data.isOnDuty
                      ? 'All systems online'
                      : 'Tap to sync telemetry',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(VolunteerProfileModel data) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: data.isOnDuty
                  ? const Color(0xFF10B981).withOpacity(0.6)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF1F5F9),
            backgroundImage: data.photoUrl != null
                ? NetworkImage(data.photoUrl!)
                : null,
            child: data.photoUrl == null
                ? Text(
                    data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 3),
              ],
            ),
            child: const Icon(
              Icons.g_mobiledata_rounded,
              size: 14,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactChip(
    String label,
    (Color bg, Color fg, Color border, IconData icon) style,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: style.$1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.$3, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.$4, size: 11, color: style.$2),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: style.$2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // 2. HERO FIELD DISPATCH CENTER - STATE A: STANDBY/SCANNING
  Widget _buildStandbyScannerCard(
    BuildContext context,
    ImpactMetricsModel impact,
    GeminiScanFeedModel scanFeed,
    int animationTrigger,
  ) {
    return Container(
      key: const ValueKey('standby_state'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFBFDBFE).withOpacity(0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.radar_rounded,
                size: 24,
                color: Color(0xFF3B82F6),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'STANDBY',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const RadarSweepAnimation(),
                SvgPicture.asset(
                  'assets/gemini_icon.svg',
                  width: 160 * 0.12,
                  height: 160 * 0.12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scanning Nearby Incidents',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          GeminiIntelligenceFeed(messages: scanFeed.feedMessages),
          const SizedBox(height: 24),
          AiInsightPreviewCard(
            insights: scanFeed.insightPreviews,
            onInfoTap: () => _showInsightsInfoSheet(context),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStandbyMetricTile(
                    Icons.favorite_outline_rounded,
                    'Lives Impacted',
                    impact.livesImpacted,
                    '',
                    '${impact.livesImpactedChange}',
                    const Color(0xFFEF4444),
                    animationTrigger,
                    onInfoTap: () {
                      _triggerCountAnimation();
                      _showLivesImpactedInfoSheet(context);
                    },
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildStandbyMetricTile(
                    Icons.access_time_rounded,
                    'Response Time\nSaved',
                    impact.timeSavedHrs,
                    ' hrs',
                    '${impact.timeSavedChange}',
                    const Color(0xFF0284C7),
                    animationTrigger,
                    onInfoTap: null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandbyMetricTile(
    IconData icon,
    String label,
    num value,
    String suffix,
    String change,
    Color iconColor,
    int animationTrigger, {
    VoidCallback? onInfoTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (onInfoTap != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onInfoTap,
                        child: const Icon(
                          Icons.info_outline_rounded,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: AnimatedCountUpText(
                        value: value,
                        suffix: suffix,
                        triggerKey: animationTrigger,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_upward_rounded,
                      size: 11,
                      color: Color(0xFF10B981),
                    ),
                    Text(
                      change,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  'All time',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealDispatchCard(
    BuildContext context, {
    required String needId,
    required Map<String, dynamic> needData,
    required String volunteerStatus,
    required VolunteerModel volunteerDb,
  }) {
    final rawTitle =
        needData['title'] ?? needData['category'] ?? 'Emergency Incident';
    final location = needData['location_name'] ?? 'Mahananda Colony, Sector 4';
    final peopleAffected = needData['peopleAffected'] ?? 0;
    final category = needData['category']?.toString() ?? 'emergency';
    final isPending = volunteerStatus == 'pending_response';
    final fallbackNgoName =
        needData['ngoName'] ?? needData['ngo_name'] ?? 'Unknown NGO';
    final ngoId = needData['ngoId'] ?? needData['ngo_id'] ?? volunteerDb.ngoId;
    final distance = needData['distance'] ?? '1.2';

    final catLabel = '${category[0].toUpperCase()}${category.substring(1)}';

    IconData categoryIcon;
    if (category.toLowerCase().contains('medic') ||
        category.toLowerCase().contains('health')) {
      categoryIcon = Icons.local_hospital_rounded;
    } else if (category.toLowerCase().contains('food') ||
        category.toLowerCase().contains('nutri')) {
      categoryIcon = Icons.restaurant_rounded;
    } else if (category.toLowerCase().contains('logistic') ||
        category.toLowerCase().contains('transport')) {
      categoryIcon = Icons.local_shipping_rounded;
    } else if (category.toLowerCase().contains('mental') ||
        category.toLowerCase().contains('psych')) {
      categoryIcon = Icons.psychology_rounded;
    } else {
      categoryIcon = Icons.warning_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final scale = 0.97 + (0.03 * value);
        final opacity = value.clamp(0.0, 1.0);
        final translateY = 16.0 * (1.0 - value);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(opacity: opacity, child: child),
          ),
        );
      },
      child: Container(
        key: ValueKey(needId),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Watermark Icon
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                categoryIcon,
                size: 140,
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mission Matched Badge with pulse
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF86EFAC,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF16A34A),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mission Matched',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Critical Priority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFFECACA,
                            ).withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFDC2626,
                              ).withValues(alpha: 0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Critical Priority',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Hero Title
                  Text(
                    rawTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$catLabel Response Required',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Snapshot Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMissionFactChip(
                        Icons.location_on_outlined,
                        location,
                      ),
                      _buildMissionFactChip(
                        Icons.people_outline_rounded,
                        '$peopleAffected Affected',
                      ),
                      _buildMissionFactChip(categoryIcon, catLabel),
                      _buildMissionFactChip(
                        Icons.navigation_outlined,
                        '$distance km Away',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // AI Match Insight Panel
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF2563EB),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Matched to your $catLabel specialization, active field status, and proximity to the incident.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E3A8A),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // NGO Partner
                  Row(
                    children: [
                      const Icon(
                        Icons.domain_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Raised by ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<NgoModel?>(
                          stream: ref
                              .watch(ngoServiceProvider)
                              .watchById(ngoId),
                          builder: (context, snapshot) {
                            final currentNgoName =
                                snapshot.data?.ngoName ?? fallbackNgoName;
                            return Text(
                              currentNgoName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // CTA Button
                  GestureDetector(
                    onTap: () async {
                      if (isPending) {
                        await ref
                            .read(smartAllocationServiceProvider)
                            .acceptMission(
                              needId: needId,
                              volunteerId: volunteerDb.uid,
                              volunteerName: volunteerDb.displayName,
                            );
                      }
                      // Navigate to Volunteer Map Screen (Index 3)
                      ref.read(volunteerTabControllerProvider.notifier).state =
                          3;
                    },
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'VIEW MISSION',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionFactChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionReason(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionBadge({
    required IconData? icon,
    required String label,
    required Color bg,
    required Color border,
    required Color fg,
    bool showPulse = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            const PulsingUrgentDot(),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showInsightsInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemini AI Recommendations',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How Gemini Insights Work\n\nGemini analyzes:\nNGO incident reports\nDisaster trends\nMission categories\nVolunteer capabilities\nGeographic response patterns\n\nThese insights help identify where your skills may be most useful and support faster mission matching.\n\nInsights are informational and do not represent confirmed emergencies.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Understood',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLivesImpactedInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lives Impacted',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How Lives Impacted Is Calculated\n\nThis value represents the total estimated number of people affected across missions you successfully participated in.\n\nExample:\n\nMission A → 24 affected\nMission B → 80 affected\nMission C → 24 affected\nTotal Lives Impacted = 128\n\nThis metric represents community reach and impact, not direct rescue count.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Understood',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVolunteerImpactInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Volunteer Impact',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Volunteer Impact reflects service hours, completed missions and community contribution metrics.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Understood',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. VOLUNTEER IMPACT SECTION
  Widget _buildVolunteerImpactSection(
    BuildContext context,
    ImpactMetricsModel imp,
    int animationTrigger,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildImpactCard(
            icon: Icons.timer_outlined,
            iconColor: const Color(0xFF3B82F6),
            value: imp.serviceHours,
            suffix: ' hrs',
            label: 'Service Hours',
            animationTrigger: animationTrigger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildImpactCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF22C55E),
            value: imp.missionsCompleted,
            suffix: '',
            label: 'Missions Completed',
            animationTrigger: animationTrigger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildImpactCard(
            icon: Icons.article_rounded,
            iconColor: const Color(0xFFF59E0B),
            value: imp.reportsSubmitted,
            suffix: '',
            label: 'Field Reports',
            animationTrigger: animationTrigger,
          ),
        ),
      ],
    );
  }

  Widget _buildImpactCard({
    required IconData icon,
    required Color iconColor,
    required num value,
    required String suffix,
    required String label,
    required int animationTrigger,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          AnimatedCountUpText(
            value: value,
            suffix: suffix,
            triggerKey: animationTrigger,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showNgosBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0).copyWith(top: 24),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ngos').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allDocs = snapshot.data!.docs;
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final websiteUrl = data['website'] ?? data['websiteUrl'] ?? data['site'];
                  return websiteUrl != null && websiteUrl.toString().trim().isNotEmpty;
                }).toList();
                
                return ListView.builder(
                  controller: scrollController,
                  itemCount: docs.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified NGO Partners',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real organizations onboarded and validated on AlloCare',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (index == 1) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${docs.length} NGOs Onboarded',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: const Color(0xFF166534),
                                    ),
                                  ),
                                  Text(
                                    'Actively participating in emergency response',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = docs[index - 2].data() as Map<String, dynamic>;
                    final name = data['ngoName'] as String? ?? 'Verified NGO';

                    final city = data['city'] as String?;
                    final state = data['state'] as String?;

                    String area = 'Location unavailable';
                    if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
                      area = '$city, $state';
                    } else if (city != null && city.isNotEmpty) {
                      area = city;
                    } else if (state != null && state.isNotEmpty) {
                      area = state;
                    }
                    
                    final workField = data['workField'] as String? ?? 'Disaster Relief & Humanitarian Aid';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showNgoShowcaseDialog(context, data),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF0FDF4),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.verified_user_rounded,
                                          color: Color(0xFF10B981),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Area: $area',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.handshake_rounded, color: Color(0xFF64748B), size: 12),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    workField,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: const Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
        },
      ),
    );
  }

  void _showNgoShowcaseDialog(BuildContext context, Map<String, dynamic> data) {
    final name = data['ngoName'] as String? ?? 'Verified NGO Partner';
    final description = data['description'] as String? ?? 'Committed to humanitarian response and disaster relief.';
    
    final city = data['city'] as String?;
    final state = data['state'] as String?;
    String area = 'Location unavailable';
    if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
      area = '$city, $state';
    } else if (city != null && city.isNotEmpty) {
      area = city;
    } else if (state != null && state.isNotEmpty) {
      area = state;
    }

    final workField = data['workField'] as String? ?? 'Disaster Relief & Humanitarian Aid';

    // Attempt to read various possible URL keys for website
    final websiteUrl = data['website'] ?? data['websiteUrl'] ?? data['site'];
    final trustDocUrl = data['trustDoc'] ?? data['trustDocUrl'];
    final showcaseUrl = data['showCase'] ?? data['showcaseUrl'] ?? data['showcase'];
    final email = data['email'] as String?;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF16A34A),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Partner',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description.isNotEmpty ? description : 'This organization is fully verified and actively participating in humanitarian efforts.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF475569),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Verification Meta Data Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVerificationRow('Primary Focus Area', workField),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildVerificationRow('Region Served', area),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildVerificationRow('Registration Status', 'Verified Public Trust', isGreen: true),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Trust Doc Button
                  if (trustDocUrl != null && trustDocUrl.toString().isNotEmpty)
                    _buildShowcaseButton(
                      icon: Icons.description_rounded,
                      label: 'View Trust Registration',
                      color: const Color(0xFF16A34A),
                      isPrimary: true,
                      onTap: () => _showTrustDocImage(context, trustDocUrl.toString()),
                    ),
                    
                  if (websiteUrl != null && websiteUrl.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildShowcaseButton(
                      icon: Icons.language_rounded,
                      label: 'Visit Website',
                      color: const Color(0xFF2563EB),
                      onTap: () => _launchUrl(websiteUrl.toString()),
                    ),
                  ],
                  if (showcaseUrl != null && showcaseUrl.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildShowcaseButton(
                      icon: Icons.auto_awesome_mosaic_rounded,
                      label: 'View Work Showcase',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _launchUrl(showcaseUrl.toString()),
                    ),
                  ],
                  if (email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildShowcaseButton(
                      icon: Icons.email_outlined,
                      label: 'Contact NGO',
                      color: const Color(0xFF475569),
                      onTap: () => _launchUrl('mailto:$email'),
                    ),
                  ],
                  
                  if ((websiteUrl == null || websiteUrl.toString().isEmpty) && 
                      (trustDocUrl == null || trustDocUrl.toString().isEmpty)) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Documents verified internally by AlloCare Trust & Safety.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close Verification',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationRow(String label, String value, {bool isGreen = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isGreen ? FontWeight.w700 : FontWeight.w500,
            color: isGreen ? const Color(0xFF10B981) : const Color(0xFF334155),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  void _showTrustDocImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        width: 300,
                        height: 400,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 300,
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Image unavailable',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      String finalUrl = urlString;
      if (!urlString.startsWith('http') && !urlString.startsWith('mailto:')) {
        finalUrl = 'https://$urlString';
      }
      final uri = Uri.parse(finalUrl);
      // On Android 11+, canLaunchUrl might return false if the scheme is not explicitly queried in AndroidManifest.
      // We attempt to launch it directly to let the OS handle the intent.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  Widget _buildShowcaseButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? color : color.withOpacity(0.08),
          foregroundColor: isPrimary ? Colors.white : color,
          elevation: isPrimary ? 2 : 0,
          shadowColor: isPrimary ? color.withOpacity(0.4) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary ? BorderSide.none : BorderSide(color: color.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  // 4. UNIFORM TACTICAL LOCAL RADAR GRID (2x2)
  Widget _buildTacticalGrid(TacticalRadarMetricsModel radar) {
    final alertValue = radar.nearbyAlerts.toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = constraints.maxWidth < 340 ? 1.25 : 1.35;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
            _buildTacticalGridCard(
              title: 'Nearby Alerts',
              value: alertValue,
              subtitle: 'Active Incidents',
              icon: Icons.notifications_active_outlined,
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MapScreen(
                      isVolunteer: true,
                      initialLayer: MapLayerCategory.medical,
                    ),
                  ),
                );
              },
            ),
            _buildTacticalGridCard(
              title: 'Active Responders',
              value: '${radar.activePeers}',
              subtitle: 'Responders Nearby',
              icon: Icons.people_outline_rounded,
              color: const Color(0xFF3B82F6),
              bgColor: const Color(0xFFF0F9FF),
              miniRadar: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MapScreen(
                      isVolunteer: true,
                      initialLayer: MapLayerCategory.medical,
                    ),
                  ),
                );
              },
            ),
            _buildTacticalGridCard(
              title: 'Recent Mission',
              value: radar.recentMissionType,
              subtitle: radar.recentMissionTime,
              icon: Icons.history_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VolunteerMissionHistoryPage(),
                  ),
                );
              },
            ),
            _buildTacticalGridCard(
              title: 'Verified Partners',
              value: '${radar.partnerNgos}',
              subtitle: 'NGO Ecosystem',
              icon: Icons.verified_user_outlined,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              onTap: () {
                _showNgosBottomSheet(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTacticalGridCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    List<double>? sparklinePoints,
    bool miniRadar = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.08),
        highlightColor: color.withOpacity(0.04),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: color.withOpacity(0.5),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: color == const Color(0xFFEF4444)
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (sparklinePoints != null)
                    SizedBox(
                      width: 52,
                      height: 24,
                      child: CustomPaint(
                        painter: SparklinePainter(
                          sparklinePoints,
                          color,
                          showFill: true,
                        ),
                      ),
                    ),
                  if (miniRadar) const MiniRadarIndicator(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUB-COMPONENTS & ANIMATIONS
// ==========================================

// Rotating Gemini intelligence feed — one message at a time
class GeminiIntelligenceFeed extends StatefulWidget {
  final List<String> messages;

  const GeminiIntelligenceFeed({super.key, required this.messages});

  @override
  State<GeminiIntelligenceFeed> createState() => _GeminiIntelligenceFeedState();
}

class _GeminiIntelligenceFeedState extends State<GeminiIntelligenceFeed> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  Future<void> _startRotation() async {
    while (mounted && widget.messages.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 2800));
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.messages.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: const Color(0xFF0284C7).withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            widget.messages[_index],
            key: ValueKey(_index),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class AiInsightPreviewCard extends StatelessWidget {
  final List<AiInsightPreviewModel> insights;
  final VoidCallback onInfoTap;

  const AiInsightPreviewCard({
    super.key,
    required this.insights,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    final insight = insights.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/gemini_icon.svg',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Gemini Insight',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onInfoTap,
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.body,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// Smooth number transition for impact metrics
class AnimatedCountUpText extends StatelessWidget {
  final num value;
  final String suffix;
  final TextStyle style;
  final int triggerKey;

  const AnimatedCountUpText({
    super.key,
    required this.value,
    this.suffix = '',
    required this.style,
    required this.triggerKey,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('count_$triggerKey'),
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        String displayValue;
        if (value is int) {
          displayValue = val.toInt().toString();
        } else {
          displayValue = val.toStringAsFixed(1);
        }
        return Text(
          '$displayValue$suffix',
          style: style,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// Pulsing card container for Top Header Glow
class PulsingGlowCard extends StatefulWidget {
  final bool isActive;
  final Widget child;

  const PulsingGlowCard({
    super.key,
    required this.isActive,
    required this.child,
  });

  @override
  State<PulsingGlowCard> createState() => _PulsingGlowCardState();
}

class _PulsingGlowCardState extends State<PulsingGlowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnimation = Tween<double>(begin: 3.0, end: 10.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsingGlowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowValue = widget.isActive ? _glowAnimation.value : 0.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFE2E8F0),
              width: widget.isActive ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isActive
                    ? const Color(0xFF10B981).withOpacity(0.06)
                    : Colors.black.withOpacity(0.015),
                blurRadius: widget.isActive ? 12.0 + glowValue : 16.0,
                spreadRadius: widget.isActive ? glowValue * 0.12 : 0.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

// Pulsing red dot for urgent dispatch badge
class PulsingUrgentDot extends StatefulWidget {
  const PulsingUrgentDot({super.key});

  @override
  State<PulsingUrgentDot> createState() => _PulsingUrgentDotState();
}

class _PulsingUrgentDotState extends State<PulsingUrgentDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.3 + _controller.value * 0.5,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withOpacity(0.5),
                ),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Full-width mission launch CTA with gradient glow
class _LaunchMissionButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LaunchMissionButton({required this.onTap});

  @override
  State<_LaunchMissionButton> createState() => _LaunchMissionButtonState();
}

class _LaunchMissionButtonState extends State<_LaunchMissionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Manage Mission',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              Positioned(
                right: 14,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom animated dot indicating active status
class StatusIndicatorDot extends StatefulWidget {
  final bool isActive;
  const StatusIndicatorDot({super.key, required this.isActive});

  @override
  State<StatusIndicatorDot> createState() => _StatusIndicatorDotState();
}

class _StatusIndicatorDotState extends State<StatusIndicatorDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isActive)
              Opacity(
                opacity: _animationController.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.4),
                  ),
                ),
              ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Sparkline Painter for visual graphs without edge clipping
class SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final bool showFill;

  SparklinePainter(this.points, this.color, {this.showFill = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || points.length < 2) return;

    final stepX = size.width / (points.length - 1);
    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    const heightPadding = 4.0;
    final usableHeight = size.height - (heightPadding * 2);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y =
          size.height -
          heightPadding -
          ((points[i] - minVal) / range * usableHeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (showFill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final lastY =
        size.height -
        heightPadding -
        ((points.last - minVal) / range * usableHeight);
    canvas.drawCircle(Offset(size.width, lastY), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.points != points ||
        oldDelegate.showFill != showFill;
  }
}

// Rotating radar sweep animation with dynamic telemetry particles
class RadarSweepAnimation extends StatefulWidget {
  const RadarSweepAnimation({super.key});

  @override
  State<RadarSweepAnimation> createState() => _RadarSweepAnimationState();
}

class _RadarSweepAnimationState extends State<RadarSweepAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _sweepController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return AnimatedBuilder(
          animation: Listenable.merge([_sweepController, _pulseController]),
          builder: (context, child) {
            return CustomPaint(
              size: Size(size, size),
              painter: RadarSweepPainter(
                _sweepController.value * 2 * math.pi,
                _pulseController.value,
              ),
            );
          },
        );
      },
    );
  }
}

class RadarSweepPainter extends CustomPainter {
  final double angle;
  final double pulseValue;

  RadarSweepPainter(this.angle, this.pulseValue);

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const segments = 48;
    const dashFraction = 0.55;
    for (var i = 0; i < segments; i++) {
      final start = (i / segments) * 2 * math.pi;
      final sweep = (dashFraction / segments) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    final ringPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final scale in [1.0, 0.8, 0.6, 0.4, 0.2]) {
      _drawDashedCircle(canvas, center, radius * scale, ringPaint);
    }

    final crossPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.08)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crossPaint,
    );

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF0284C7).withOpacity(0.32),
          const Color(0xFF0284C7).withOpacity(0.08),
          const Color(0xFF0284C7).withOpacity(0.0),
        ],
        stops: const [0.0, 0.12, 0.28],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, sweepPaint);

    final particleOffsets = [
      Offset(-radius * 0.42, -radius * 0.35),
      Offset(radius * 0.35, -radius * 0.55),
      Offset(-radius * 0.55, radius * 0.38),
      Offset(radius * 0.48, radius * 0.22),
      Offset(-radius * 0.15, -radius * 0.62),
      Offset(radius * 0.12, radius * 0.5),
    ];

    for (var i = 0; i < particleOffsets.length; i++) {
      final pos = center + particleOffsets[i];
      final opacity = (0.25 + 0.55 * math.sin(angle * 2.2 + i * 1.1)).clamp(
        0.1,
        0.9,
      );

      canvas.drawCircle(
        pos,
        2.5 + math.sin(angle * 4 + i) * 0.8,
        Paint()
          ..color = const Color(0xFF0284C7).withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        pos,
        5 + 2 * math.sin(angle * 3.2 + i),
        Paint()
          ..color = const Color(0xFF38BDF8).withOpacity(opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    final glowRadius = 6 + 10 * pulseValue;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..color = const Color(0xFF0284C7).withOpacity(0.15 * (1 - pulseValue))
        ..style = PaintingStyle.fill,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + this.angle * 0.15;
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final innerAngle = angle + math.pi / 4;
      final inner = Offset(
        center.dx + math.cos(innerAngle) * radius * 0.35,
        center.dy + math.sin(innerAngle) * radius * 0.35,
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.pulseValue != pulseValue;
  }
}

// Mini radar visualizer for tactical active peers card
class MiniRadarIndicator extends StatefulWidget {
  const MiniRadarIndicator({super.key});

  @override
  State<MiniRadarIndicator> createState() => _MiniRadarIndicatorState();
}

class _MiniRadarIndicatorState extends State<MiniRadarIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 45,
      height: 25,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: MiniRadarPainter(_controller.value * 2 * math.pi),
          );
        },
      ),
    );
  }
}

class MiniRadarPainter extends CustomPainter {
  final double angle;
  MiniRadarPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;

    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.5, paint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.35),
          const Color(0xFF3B82F6).withOpacity(0.0),
        ],
        stops: const [0.0, 0.3],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant MiniRadarPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

// Slowly alternating text loop for scanning state
class TextScannerLoop extends StatefulWidget {
  const TextScannerLoop({super.key});

  @override
  State<TextScannerLoop> createState() => _TextScannerLoopState();
}

class _TextScannerLoopState extends State<TextScannerLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  final List<String> _phrases = [
    "System Scanning... Analyzing regional data streams.",
    "Gemini matching profile to active incidents...",
    "Listening to field signals...",
    "Cross-checking with NGO network...",
    "Standing by for priority match...",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    _startLoop();
  }

  void _startLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await _controller.reverse();
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _phrases.length;
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        _phrases[_currentIndex],
        style: GoogleFonts.inter(
          fontSize: 10,
          color: const Color(0xFF334155),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Heart pulse animation on value text
class HeartPulseText extends StatefulWidget {
  final String text;
  const HeartPulseText({super.key, required this.text});

  @override
  State<HeartPulseText> createState() => _HeartPulseTextState();
}

class _HeartPulseTextState extends State<HeartPulseText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        widget.text,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
