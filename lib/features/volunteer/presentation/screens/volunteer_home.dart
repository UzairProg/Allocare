import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../services/auth_service.dart';
import '../../../../services/user_profile_service.dart';
import '../../../../services/volunteer_service.dart';
import '../../../../models/volunteer_model.dart';
import '../../../../services/smart_allocation_service.dart';
import '../controllers/volunteer_controller.dart';

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
  final int forceRank;
  final String forceRankPercentile;
  final int impactPoints;

  const ImpactMetricsModel({
    required this.livesImpacted,
    required this.livesImpactedChange,
    required this.timeSavedHrs,
    required this.timeSavedChange,
    required this.forceRank,
    required this.forceRankPercentile,
    required this.impactPoints,
  });
}

class TacticalRadarMetricsModel {
  final int nearbyAlerts;
  final double supplyStreamPercent;
  final int activePeers;
  final String safetyIndex;

  const TacticalRadarMetricsModel({
    required this.nearbyAlerts,
    required this.supplyStreamPercent,
    required this.activePeers,
    required this.safetyIndex,
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
  return const GeminiScanFeedModel(
    feedMessages: [
      'Analyzing incoming field reports...',
      'Cross-checking NGO incident streams...',
      'Identifying emerging risk clusters...',
      'Evaluating volunteer suitability...',
      'Generating AI priority brief...',
      'Checking nearby responder availability...',
      'Preparing deployment recommendations...',
    ],
    insightPreviews: [
      AiInsightPreviewModel(
        title: 'AI Insight Detected',
        body: 'Potential water contamination pattern',
        status: 'Confidence increasing...',
      ),
      AiInsightPreviewModel(
        title: 'Emerging Risk Cluster',
        body: 'Sector 4 under review',
        status: 'Correlating field signals...',
      ),
      AiInsightPreviewModel(
        title: 'Anomaly Signal',
        body: 'Field reports indicate anomaly',
        status: 'Analyzing...',
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
  return const ImpactMetricsModel(
    livesImpacted: 128,
    livesImpactedChange: 12,
    timeSavedHrs: 46.5,
    timeSavedChange: 5.3,
    forceRank: 7,
    forceRankPercentile: 'Top 8% in Region',
    impactPoints: 2840,
  );
});

final tacticalRadarProvider = Provider<TacticalRadarMetricsModel>((ref) {
  return const TacticalRadarMetricsModel(
    nearbyAlerts: 8,
    supplyStreamPercent: 92,
    activePeers: 14,
    safetyIndex: 'Moderate',
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
                FadeTransition(
                  opacity: _headerAnimController,
                  child: PulsingGlowCard(
                    isActive: profileData.isOnDuty,
                    child: _buildExecutiveHeaderCard(context, profileData),
                  ),
                ),
                const SizedBox(height: 20),

                 volunteerDb == null
                     ? Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Text(
                                 'GEMINI HANDOFF ENGINE',
                                 style: GoogleFonts.inter(
                                   fontSize: 11,
                                   fontWeight: FontWeight.w800,
                                   color: const Color(0xFF1E3A8A),
                                   letterSpacing: 1.2,
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 8),
                           _buildStandbyScannerCard(
                             context,
                             impactData,
                             scanFeedData,
                           ),
                         ],
                       )
                     : StreamBuilder<QuerySnapshot>(
                         stream: FirebaseFirestore.instance
                             .collection('needs')
                             .where('matchedVolunteerId', isEqualTo: volunteerDb.uid)
                             .where('status', isEqualTo: 'pending_acceptance')
                             .limit(1)
                             .snapshots(),
                         builder: (context, pendingSnapshot) {
                           final hasPending = pendingSnapshot.hasData &&
                               pendingSnapshot.data!.docs.isNotEmpty;
                           final hasActive = volunteerDb.currentMissionId != null;
                           final showReset = hasActive || hasPending;

                           return Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Text(
                                     'GEMINI HANDOFF ENGINE',
                                     style: GoogleFonts.inter(
                                       fontSize: 11,
                                       fontWeight: FontWeight.w800,
                                       color: const Color(0xFF1E3A8A),
                                       letterSpacing: 1.2,
                                     ),
                                   ),
                                   TextButton.icon(
                                     style: TextButton.styleFrom(
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 10,
                                         vertical: 4,
                                       ),
                                       minimumSize: Size.zero,
                                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                     ),
                                     onPressed: () async {
                                       final vId = volunteerDb.uid;
                                       if (hasActive) {
                                         await ref
                                             .read(smartAllocationServiceProvider)
                                             .declineMission(
                                               needId: volunteerDb.currentMissionId!,
                                               volunteerId: vId,
                                             );
                                       } else if (hasPending) {
                                         final pendingDocId =
                                             pendingSnapshot.data!.docs.first.id;
                                         await ref
                                             .read(smartAllocationServiceProvider)
                                             .declineMission(
                                               needId: pendingDocId,
                                               volunteerId: vId,
                                             );
                                       } else {
                                         // Simulate match by writing directly to Firestore
                                         final needDoc = FirebaseFirestore.instance
                                             .collection('needs')
                                             .doc();
                                         final now = Timestamp.now();
                                         final mockNeed = {
                                           'title': 'Suspected Waterborne Risk',
                                           'category': 'water',
                                           'subcategory': 'waterborne',
                                           'urgency': 'critical',
                                           'description':
                                               'Mahananda Colony Sector 4 water contamination reported. 150 people affected.',
                                           'location': 'Mahananda Colony, Sector 4',
                                           'locationMode': 'manual',
                                           'reportedBy': 'AI Agent',
                                           'peopleAffected': 150,
                                           'status': 'pending_acceptance',
                                           'assignmentStatus': 'pending',
                                           'matchedVolunteerId': vId,
                                           'matchedVolunteerName': volunteerDb.displayName,
                                           'assignmentRequestedAt': now,
                                           'createdAt': now,
                                           'updatedAt': now,
                                         };

                                         final batch = FirebaseFirestore.instance.batch();
                                         batch.set(needDoc, mockNeed);
                                         batch.set(
                                           FirebaseFirestore.instance
                                               .collection('reports')
                                               .doc(needDoc.id),
                                           mockNeed,
                                         );
                                         // CRITICAL: We do NOT update the volunteer profile document with currentMissionId.
                                         // That will only happen when the volunteer explicitly approves the match by clicking ACCEPT.
                                         await batch.commit();
                                       }
                                     },
                                     icon: Icon(
                                       showReset
                                           ? Icons.radar_rounded
                                           : Icons.warning_amber_rounded,
                                       size: 14,
                                       color: const Color(0xFF0284C7),
                                     ),
                                     label: Text(
                                       showReset ? 'Reset Simulator' : 'Simulate Match',
                                       style: GoogleFonts.inter(
                                         fontSize: 10,
                                         fontWeight: FontWeight.bold,
                                         color: const Color(0xFF0284C7),
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 8),

                               // 2. Refined Field Dispatch Center (Fixed-Size, Premium States)
                               AnimatedSwitcher(
                                 duration: const Duration(milliseconds: 450),
                                 transitionBuilder: (child, animation) {
                                   return FadeTransition(
                                       opacity: animation, child: child);
                                 },
                                 child: hasActive
                                     ? StreamBuilder<DocumentSnapshot>(
                                         key: ValueKey(
                                             'active_${volunteerDb.currentMissionId}'),
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
                                                 child:
                                                     CircularProgressIndicator(
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
                                             );
                                           }
                                           final needData = activeSnapshot.data!.data()
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
                                             needId: pendingSnapshot
                                                 .data!.docs.first.id,
                                             needData: pendingSnapshot
                                                 .data!.docs.first
                                                 .data() as Map<String, dynamic>,
                                             volunteerStatus: 'pending_response',
                                             volunteerDb: volunteerDb,
                                           )
                                         : _buildStandbyScannerCard(
                                             context,
                                             impactData,
                                             scanFeedData,
                                           ),
                               ),
                             ],
                           );
                         },
                       ),
                const SizedBox(height: 20),

                // 3. Gemma Validation & Impact Section
                _buildGemmaValidationDashboard(validationData, impactData),
                const SizedBox(height: 20),

                // 4. Uniform Tactical Local Radar Grid
                Text(
                  'TACTICAL LOCAL RADAR (3KM RADIUS)',
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
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
                    for (var i = 0; i < data.skillTags.length; i++)
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
  ) {
    return Container(
      key: const ValueKey('standby_state'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF1E3A8A),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GEMINI HANDOFF ENGINE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E3A8A),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
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
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final radarSize = (constraints.maxWidth * 0.42).clamp(
                140.0,
                185.0,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: radarSize,
                    height: radarSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const RadarSweepAnimation(),
                        SvgPicture.asset(
                          'assets/gemini_icon.svg',
                          width: radarSize * 0.12,
                          height: radarSize * 0.12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Scanning...',
                          style: GoogleFonts.inter(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GeminiIntelligenceFeed(messages: scanFeed.feedMessages),
                        const SizedBox(height: 14),
                        AiInsightPreviewCard(
                          insights: scanFeed.insightPreviews,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStandbyMetricTile(
                    Icons.favorite_outline_rounded,
                    'Lives Impacted',
                    '${impact.livesImpacted}',
                    '${impact.livesImpactedChange}',
                    const Color(0xFFEF4444),
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
                    'Response Time Saved',
                    '${impact.timeSavedHrs} hrs',
                    '${impact.timeSavedChange}',
                    const Color(0xFF0284C7),
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
    String value,
    String change,
    Color iconColor,
  ) {
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
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: AnimatedMetricText(
                        value,
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
    final title =
        needData['title'] ?? needData['category'] ?? 'Emergency Incident';
    final urgency = (needData['urgency'] ?? 'medium').toString().toUpperCase();
    final location = needData['location'] ?? 'Unknown Area';
    final peopleAffected = needData['peopleAffected'] ?? 0;

    final category = needData['category']?.toString() ?? 'emergency';
    final recommendedAction =
        needData['recommendedAction'] ??
        needData['recommended_action'] ??
        (category.toLowerCase().contains('water')
            ? 'Deploy Water Purification Support'
            : category.toLowerCase().contains('medical')
            ? 'Deploy Medical First Aid Support'
            : category.toLowerCase().contains('food')
            ? 'Deploy Food & Nutrition Delivery Support'
            : 'Deploy Emergency Response Support');

    final reasons = List<String>.from(
      needData['assignmentReasons'] ??
          needData['assignment_reasons'] ??
          [
            'Approved Specialty Profile',
            'Active On Field Duty Status',
            'Closest responder in geographical range',
          ],
    );

    final isPending = volunteerStatus == 'pending_response';

    // Background and border colors based on status
    final cardBg = isPending
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEFF6FF);
    final cardBorder = isPending
        ? const Color(0xFFFED7AA)
        : const Color(0xFFBFDBFE);
    final cardShadowColor = isPending
        ? const Color(0xFFEA580C)
        : const Color(0xFF1D4ED8);

    return Container(
      key: ValueKey(needId),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMissionBadge(
                icon: isPending
                    ? Icons.campaign_rounded
                    : Icons.verified_user_rounded,
                label: isPending
                    ? 'MISSION REQUEST RECEIVED'
                    : 'MISSION ASSIGNED & ACTIVE',
                bg: isPending
                    ? const Color(0xFFFFEDD5)
                    : const Color(0xFFDBEAFE),
                border: isPending
                    ? const Color(0xFFFED7AA)
                    : const Color(0xFFBFDBFE),
                fg: isPending
                    ? const Color(0xFFEA580C)
                    : const Color(0xFF1E40AF),
              ),
              _buildMissionBadge(
                icon: null,
                label: isPending ? 'Reviewing Request' : 'Active Mission',
                bg: isPending
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFEFF6FF),
                border: isPending
                    ? const Color(0xFFFED7AA)
                    : const Color(0xFFBFDBFE),
                fg: isPending
                    ? const Color(0xFFEA580C)
                    : const Color(0xFF1E40AF),
                showPulse: isPending,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFFEDD5)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPending
                        ? const Color(0xFFFED7AA)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Icon(
                  isPending
                      ? Icons.warning_amber_rounded
                      : Icons.shield_rounded,
                  color: isPending
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF1E40AF),
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚠ $title',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isPending
                        ? const Color(0xFFC2410C)
                        : const Color(0xFF1E3A8A),
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Mission Details',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildMissionDetailItem(
                        icon: Icons.grid_view_rounded,
                        label: urgency,
                        sublabel: location,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      color: cardBorder,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: _buildMissionDetailItem(
                        icon: Icons.verified_outlined,
                        label: '$peopleAffected affected',
                        sublabel: 'Estimated Impact',
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 16,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Estimated Impact',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$peopleAffected People',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3A8A).withOpacity(0.06),
                  const Color(0xFF0284C7).withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBFDBFE).withOpacity(0.8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Action',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recommendedAction,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E3A8A),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Why You Were Assigned',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await ref
                          .read(smartAllocationServiceProvider)
                          .declineMission(
                            needId: needId,
                            volunteerId: volunteerDb.uid,
                          );
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFFCA5A5),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'DECLINE',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: const Color(0xFFB91C1C),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await ref
                          .read(smartAllocationServiceProvider)
                          .acceptMission(
                            needId: needId,
                            volunteerId: volunteerDb.uid,
                            volunteerName: volunteerDb.displayName,
                          );
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'ACCEPT',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            _LaunchMissionButton(
              onTap: () {
                ref.read(volunteerTabControllerProvider.notifier).state = 3;
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await ref
                    .read(smartAllocationServiceProvider)
                    .completeMission(
                      needId: needId,
                      volunteerId: volunteerDb.uid,
                    );
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'COMPLETE MISSION',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
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

  Widget _buildMissionDetailItem({
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFDC2626)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. GEMMA VALIDATION & IMPACT SECTION
  Widget _buildGemmaValidationDashboard(
    ValidationMetricsModel val,
    ImpactMetricsModel imp,
  ) {
    final progress = val.totalCount > 0
        ? val.verifiedCount / val.totalCount
        : 0.0;
    final progressPercent = (progress * 100).round();
    final formattedPoints = NumberFormat('#,###').format(imp.impactPoints);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricSectionHeader(
                    Icons.verified_user_outlined,
                    'GEMMA VALIDATION INDEX',
                    const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${val.verifiedCount} / ${val.totalCount}',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reports Verified',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF2FF),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          val.notes,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$progressPercent%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const VerticalDivider(
              width: 17,
              thickness: 1,
              color: Color(0xFFE2E8F0),
            ),
            // Expanded(
            //   flex: 3,
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       _buildMetricSectionHeader(
            //         Icons.military_tech_outlined,
            //         'LOCAL FORCE RANK',
            //         const Color(0xFF8B5CF6),
            //       ),
            //       const SizedBox(height: 12),
            //       Text(
            //         '#${imp.forceRank}',
            //         style: GoogleFonts.inter(
            //           fontSize: 26,
            //           fontWeight: FontWeight.w800,
            //           color: const Color(0xFF8B5CF6),
            //           letterSpacing: -0.5,
            //         ),
            //       ),
            //       const SizedBox(height: 2),
            //       Text(
            //         imp.forceRankPercentile,
            //         style: GoogleFonts.inter(
            //           fontSize: 11,
            //           color: const Color(0xFF64748B),
            //           fontWeight: FontWeight.w500,
            //         ),
            //       ),
            //       const Spacer(),
            //       SizedBox(
            //         height: 28,
            //         width: double.infinity,
            //         child: CustomPaint(
            //           painter: SparklinePainter(
            //             const [10, 8, 12, 14, 9, 11, 7],
            //             const Color(0xFF8B5CF6),
            //             showFill: true,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            // const VerticalDivider(
            //   width: 17,
            //   thickness: 1,
            //   color: Color(0xFFE2E8F0),
            // ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricSectionHeader(
                    Icons.star_outline_rounded,
                    'IMPACT POINTS',
                    const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formattedPoints,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF59E0B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All time points',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: SparklinePainter(
                        const [100, 150, 120, 200, 180, 250, 280],
                        const Color(0xFFF59E0B),
                        showFill: true,
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

  Widget _buildMetricSectionHeader(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
              subtitle: 'Open incidents',
              icon: Icons.notifications_active_outlined,
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
            ),
            _buildTacticalGridCard(
              title: 'Supply Stream Status',
              value: '${radar.supplyStreamPercent.toInt()}%',
              subtitle: 'Resources flowing',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              sparklinePoints: const [80, 85, 90, 88, 92],
            ),
            _buildTacticalGridCard(
              title: 'Active Peers',
              value: '${radar.activePeers}',
              subtitle: 'Within 3km radius',
              icon: Icons.people_outline_rounded,
              color: const Color(0xFF3B82F6),
              bgColor: const Color(0xFFF0F9FF),
              miniRadar: true,
            ),
            _buildTacticalGridCard(
              title: 'Safety Index',
              value: radar.safetyIndex,
              subtitle: 'Stay alert, stay safe',
              icon: Icons.shield_outlined,
              color: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFEF3C7),
              sparklinePoints: const [50, 40, 60, 45, 55],
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            Expanded(
              child: AnimatedSwitcher(
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
            ),
          ],
        ),
      ],
    );
  }
}

// Subtle AI insight preview during scanning — not the final brief
class AiInsightPreviewCard extends StatefulWidget {
  final List<AiInsightPreviewModel> insights;

  const AiInsightPreviewCard({super.key, required this.insights});

  @override
  State<AiInsightPreviewCard> createState() => _AiInsightPreviewCardState();
}

class _AiInsightPreviewCardState extends State<AiInsightPreviewCard>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _rotateInsights();
  }

  Future<void> _rotateInsights() async {
    while (mounted && widget.insights.length > 1) {
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.insights.length;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) return const SizedBox.shrink();

    final insight = widget.insights[_index];

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: Container(
            key: ValueKey(_index),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Color.lerp(
                const Color(0xFFF8FAFC),
                const Color(0xFFEFF6FF),
                _pulseController.value * 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFBFDBFE).withOpacity(0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: const Color(0xFF0284C7).withOpacity(0.8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      insight.title,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3A8A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.body,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.status,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Smooth number transition for impact metrics
class AnimatedMetricText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AnimatedMetricText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        overflow: TextOverflow.ellipsis,
      ),
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
                'LAUNCH MISSION RADAR',
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
