import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/smart_allocation_service.dart';
import '../../../../services/volunteer_service.dart';
import '../../../../services/ngo_service.dart';
import '../../../../models/ngo_model.dart';
import '../controllers/volunteer_controller.dart';
import 'volunteer_report.dart';
import 'volunteer_mission_history_page.dart';

class VolunteerTasksScreen extends ConsumerStatefulWidget {
  const VolunteerTasksScreen({super.key});
  @override
  ConsumerState<VolunteerTasksScreen> createState() =>
      _VolunteerTasksScreenState();
}

class CompletionFlowState {
  final bool inFlow;
  final bool showSuccess;
  final String? missionId;
  final Map<String, dynamic>? missionData;

  CompletionFlowState({
    this.inFlow = false,
    this.showSuccess = false,
    this.missionId,
    this.missionData,
  });

  CompletionFlowState copyWith({
    bool? inFlow,
    bool? showSuccess,
    String? missionId,
    Map<String, dynamic>? missionData,
  }) {
    return CompletionFlowState(
      inFlow: inFlow ?? this.inFlow,
      showSuccess: showSuccess ?? this.showSuccess,
      missionId: missionId ?? this.missionId,
      missionData: missionData ?? this.missionData,
    );
  }
}

class CompletionFlowNotifier extends StateNotifier<CompletionFlowState> {
  CompletionFlowNotifier() : super(CompletionFlowState());

  void startFlow(String missionId, Map<String, dynamic> data) {
    state = CompletionFlowState(
      inFlow: true,
      showSuccess: false,
      missionId: missionId,
      missionData: data,
    );
  }

  void showSuccess() {
    state = state.copyWith(showSuccess: true);
  }

  void exitFlow() {
    state = CompletionFlowState();
  }
}

final completionFlowProvider =
    StateNotifierProvider<CompletionFlowNotifier, CompletionFlowState>(
        (ref) => CompletionFlowNotifier());


class _VolunteerTasksScreenState extends ConsumerState<VolunteerTasksScreen> {
  bool _isLoading = false;
  final Map<String, bool> _checklist = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activeStepKey = GlobalKey();
  int _lastStage = -1;

  // Feedback state
  bool _showFeedback = false;
  int _feedbackRating = 0;
  final Set<String> _feedbackTags = {};
  final TextEditingController _feedbackNotes = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _feedbackNotes.dispose();
    super.dispose();
  }

  void _scrollToActiveStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeStepKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    });
  }

  int _stageIndex(String status) {
    switch (status) {
      case 'pending_acceptance':
        return 0;
      case 'accepted':
        return 0; // Still stage 0 until they click BEGIN DEPLOYMENT
      case 'en_route':
        return 1;
      case 'on_site':
      case 'arrived':
        return 2;
      case 'field_active':
        return 2;
      case 'completed':
        return 3;
      default:
        print('[MISSION UI] Unknown status: $status, defaulting to stage 0');
        return 0;
    }
  }

  List<String> _checklistForCategory(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('medic') || c.contains('health')) {
      return [
        'Assess casualties',
        'Setup triage area',
        'Verify medical supplies',
        'Log critical cases',
      ];
    } else if (c.contains('water') || c.contains('sanitation')) {
      return [
        'Inspect contamination source',
        'Verify water supply',
        'Distribute purification kits',
        'Upload field evidence',
      ];
    } else if (c.contains('food') || c.contains('nutri')) {
      return [
        'Verify affected households',
        'Distribute food kits',
        'Capture delivery proof',
        'Confirm completion',
      ];
    }
    return [
      'Assess situation on ground',
      'Coordinate with NGO lead',
      'Distribute resources',
      'Document with photos',
    ];
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Check completion flow FIRST, before ANY provider access.
    // When completeMission() clears currentMissionId, the provider rebuilds
    // and volunteer.currentMissionId becomes null. We must intercept here.
    final flowState = ref.watch(completionFlowProvider);
    if (flowState.inFlow && flowState.missionId != null && flowState.missionData != null) {
      print('[MISSION UI] build() → inFlow=true, showing completion scaffold');
      return _buildCompletionScaffold(flowState);
    }

    final volunteerAsync = ref.watch(currentVolunteerProvider);
    final volunteer = volunteerAsync.value;
    print('[MISSION UI] build() → inFlow=${flowState.inFlow}, volunteer=${volunteer != null}, missionId=${volunteer?.currentMissionId}');
    
    if (volunteer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final missionId = volunteer.currentMissionId;
    if (missionId == null || missionId.isEmpty) return _buildNoMission();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('needs')
            .doc(missionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data()!;
          final status = data['status'] ?? 'pending_acceptance';
          print('[MISSION UI] Firestore listener fired. status=$status');
          final stage = _stageIndex(status);
          final title =
              data['title'] ?? data['category'] ?? 'Emergency Mission';
          final category = data['category']?.toString() ?? 'emergency';
          final peopleAffected = data['peopleAffected'] ?? 0;
          final urgency = data['urgency'] ?? 'critical';
          final ngoId = data['ngoId'] ?? data['ngo_id'] ?? volunteer.ngoId;
          
          double? lat = _toDouble(data['latitude']);
          double? lng = _toDouble(data['longitude']);
          if (lat == null || lng == null) {
            final loc = data['location'];
            if (loc is GeoPoint) {
              lat = loc.latitude;
              lng = loc.longitude;
            } else if (loc is Map) {
              lat = _toDouble(loc['latitude']) ?? _toDouble(loc['lat']);
              lng = _toDouble(loc['longitude']) ?? _toDouble(loc['lng']);
            }
          }
          // Default fallback if completely missing so button always shows
          lat ??= 19.8762; 
          lng ??= 75.3433;
          // Auto-scroll when stage changes
          if (stage != _lastStage) {
            _lastStage = stage;
            _scrollToActiveStep();
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                toolbarHeight: 64,
                title: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      urgency.toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history_rounded, color: Color(0xFF64748B)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VolunteerMissionHistoryPage()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Mission Info Card
                    _buildMissionInfoCard(
                      context,
                      data,
                      title,
                      ngoId,
                    ),
                    const SizedBox(height: 24),

                    // TIMELINE
                    _buildTimelineSection(
                      stage,
                      status,
                      data,
                      volunteer.uid,
                      title,
                      category,
                      peopleAffected,
                      lat,
                      lng,
                      missionId,
                    ),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Widget _buildNoMission() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Operational Workspace',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDBEAFE), width: 8),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  size: 64,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Standby Mode',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your workspace is currently clear. When an emergency dispatch is matched to your skills, your operational briefing will appear right here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VolunteerMissionHistoryPage(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View Mission History',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionInfoCard(
    BuildContext context,
    Map<String, dynamic> data,
    String title,
    String ngoId,
  ) {
    final description = data['description'] ??
        'No additional details provided for this mission. Please proceed with standard protocols for this emergency category.';
    final locationName = data['location_name'] ?? 'Mahananda Colony, Sector 4';
    final imageUrl = data['imageUrl'] ?? data['image_url'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mission Details',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),
          
          // Details Grid (Location & NGO)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.domain_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: StreamBuilder<NgoModel?>(
                        stream: ref.watch(ngoServiceProvider).watchById(ngoId),
                        builder: (ctx, snap) {
                          return Text(
                            snap.data?.ngoName ?? 'NGO Partner',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
              height: 1.6,
            ),
          ),
          
          if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'ATTACHED MEDIA',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(imageUrl),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TIMELINE SECTION
  Widget _buildTimelineSection(
    int stage,
    String status,
    Map<String, dynamic> data,
    String odId,
    String title,
    String category,
    dynamic affected,
    double? lat,
    double? lng,
    String missionId,
  ) {
    final steps = [
      {
        'label': 'Assignment Received',
        'time': _formatTime(data['assignedAt'] ?? data['assigned_at']),
      },
      {'label': 'Navigate To Site', 'time': ''},
      {'label': 'On-Site Operations', 'time': ''},
      {'label': 'Mission Resolved', 'time': ''},
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final isCompleted = i < stage;
        final isActive = i == stage;
        final isFuture = i > stage;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thread + Node
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  // Node
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF22C55E)
                          : isActive
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        if (isActive)
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                            blurRadius: 8,
                          ),
                      ],
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                  // Line
                  if (i < steps.length - 1)
                    Container(
                      width: 2,
                      height: isActive ? null : 40,
                      constraints: isActive
                          ? const BoxConstraints(minHeight: 40)
                          : null,
                      color: isCompleted
                          ? const Color(0xFF22C55E)
                          : isActive
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 16 : 0),
                child: isActive
                    ? KeyedSubtree(
                        key: _activeStepKey,
                        child: _buildActiveStep(
                          i,
                          status,
                          data,
                          odId,
                          category,
                          affected,
                          lat,
                          lng,
                          missionId,
                          title,
                        ),
                      )
                    : _buildInactiveStep(
                        steps[i]['label']!,
                        steps[i]['time']!,
                        isCompleted,
                        isFuture,
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Widget _buildInactiveStep(
    String label,
    String time,
    bool completed,
    bool future,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(future ? 0.5 : 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(future ? 0xFF94A3B8 : 0xFF334155),
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveStep(
    int stepIdx,
    String status,
    Map<String, dynamic> data,
    String odId,
    String category,
    dynamic affected,
    double? lat,
    double? lng,
    String missionId,
    String title,
  ) {
    if (stepIdx == 1)
      return _buildDeploymentStep(
        status,
        data,
        odId,
        category,
        lat,
        lng,
        missionId,
      );
    if (stepIdx == 2)
      return _buildOnSiteStep(
        status,
        data,
        odId,
        category,
        affected,
        missionId,
      );
    if (stepIdx == 3)
      return _buildCompletionStep(data, title, affected, missionId);
    return _buildAssignedStep(odId, missionId);
  }

  // STAGE 0: ASSIGNED
  Widget _buildAssignedStep(String odId, String missionId) {
    return _activeCard(
      badge: 'ASSIGNED',
      title: 'Start Your Mission',
      child: Column(
        children: [
          Text(
            'Review the mission details above and start your mission when ready.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _primaryButton('START MISSION', () async {
            print('[MISSION UI] START MISSION pressed');
            setState(() => _isLoading = true);
            await ref
                .read(smartAllocationServiceProvider)
                .startNavigationEvent(needId: missionId, volunteerId: odId);
            print(
              '[MISSION UI] BEGIN DEPLOYMENT completed, waiting for Firestore listener',
            );
            if (mounted) setState(() => _isLoading = false);
          }),
        ],
      ),
    );
  }

  // STAGE 1: DEPLOYMENT
  Widget _buildDeploymentStep(
    String status,
    Map<String, dynamic> data,
    String odId,
    String category,
    double? lat,
    double? lng,
    String missionId,
  ) {
    return _activeCard(
      badge: 'ACTIVE STEP',
      title: 'Navigate To Site',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '4',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2563EB),
            ),
          ),
          Text(
            'MIN',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          // Objective
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT OBJECTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2563EB),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Proceed to the incident location. Meet NGO coordinator at community center entrance.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Buttons
          if (lat != null && lng != null)
            GestureDetector(
              onTap: () => _launchMaps(lat, lng),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/open_maps.svg',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Navigate on Map',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          _outlineButton('📍 ARRIVED ON SITE', () async {
            print('[MISSION UI] ARRIVED ON SITE pressed');
            setState(() => _isLoading = true);
            await ref
                .read(smartAllocationServiceProvider)
                .markArrivedOnSite(needId: missionId, volunteerId: odId);
            print(
              '[MISSION UI] ARRIVED ON SITE completed, waiting for Firestore listener',
            );
            if (mounted) setState(() => _isLoading = false);
          }),
        ],
      ),
    );
  }

  // STAGE 2: ON SITE
  Widget _buildOnSiteStep(
    String status,
    Map<String, dynamic> data,
    String odId,
    String category,
    dynamic affected,
    String missionId,
  ) {
    final items = _checklistForCategory(category);
    for (var item in items) {
      _checklist.putIfAbsent(item, () => false);
    }
    final completed = _checklist.values.where((v) => v).length;
    final total = items.length;

    return _activeCard(
      badge: 'ON SITE',
      title: 'Field Operations',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF22C55E),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completed/$total',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Checklist
          ...items.map(
            (item) => CheckboxListTile(
              value: _checklist[item] ?? false,
              onChanged: (v) => setState(() => _checklist[item] = v ?? false),
              title: Text(
                item,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 16),
          // Field Report
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIELD REPORT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Report new observations from the field to help the NGO coordinate resources.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                _outlineButton('Submit Report', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VolunteerReportScreen(),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton('COMPLETE MISSION', () async {
            print('[MISSION] ═══ COMPLETE MISSION PRESSED ═══');
            print('[MISSION] status=$status, missionId=$missionId, odId=$odId');
            // Cache everything BEFORE Firestore clears currentMissionId
            print('[MISSION] Cached data. Setting _inCompletionFlow=true BEFORE await');
            // CRITICAL: Set _inCompletionFlow BEFORE the await.
            // The Firestore listener fires DURING the await and triggers a rebuild.
            // If _inCompletionFlow is false at that point, the rebuild shows "No Active Mission".
            ref.read(completionFlowProvider.notifier).startFlow(missionId, Map<String, dynamic>.from(data));
            setState(() {
              _isLoading = true;
            });
            print('[MISSION] Calling completeMission service...');
            await ref
                .read(smartAllocationServiceProvider)
                .completeMission(needId: missionId, volunteerId: odId);
            print('[MISSION] completeMission returned. mounted=$mounted');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }),
        ],
      ),
    );
  }

  // STAGE 3: COMPLETION + FEEDBACK
  Widget _buildCompletionStep(
    Map<String, dynamic> data,
    String title,
    dynamic affected,
    String missionId,
  ) {
    if (_showFeedback) return _buildFeedbackScreen(title, affected);

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFDCFCE7),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFF22C55E),
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Mission Completed',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _statCard('People Assisted', '$affected'),
            const SizedBox(width: 10),
            _statCard('Response Time', '42 Min'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('Reports Filed', '1'),
            const SizedBox(width: 10),
            _statCard('Lives Impacted', '+$affected'),
          ],
        ),
        const SizedBox(height: 24),
        _primaryButton('Share Feedback', () {
          setState(() => _showFeedback = true);
        }),
        const SizedBox(height: 10),
        _outlineButton('Skip & Return Home', () {
          ref.read(volunteerTabControllerProvider.notifier).state = 0;
        }),
      ],
    );
  }

  Widget _buildFeedbackScreen(String title, dynamic affected) {
    final tags = [
      'Good Coordination',
      'Fast Response',
      'Clear Instructions',
      'Resource Availability',
      'Communication Issues',
      'Navigation Issues',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: const Color(0xFF22C55E),
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Mission Feedback',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Star Rating
          Text(
            'How was your field experience?',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => setState(() => _feedbackRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _feedbackRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i < _feedbackRating
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFCBD5E1),
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Tags
          Text(
            'Quick Tags',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final selected = _feedbackTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(
                  () => selected
                      ? _feedbackTags.remove(tag)
                      : _feedbackTags.add(tag),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Notes
          Text(
            'Additional Comments',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackNotes,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any observations or suggestions...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit
          _primaryButton('Submit Feedback', () {
            // TODO: Save feedback to Firestore
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thank you for your service!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Future.delayed(const Duration(milliseconds: 1200), () {
              ref.read(completionFlowProvider.notifier).showSuccess();
            });
          }),
        ],
      ),
    );
  }

  // ── COMPLETION SCAFFOLD ── renders feedback or success using cached data
  Widget _buildCompletionScaffold(CompletionFlowState flowState) {
    final data = flowState.missionData!;
    final title = data['title'] ?? data['category'] ?? 'Emergency Mission';
    final category = data['category']?.toString() ?? 'emergency';
    final affected = data['peopleAffected'] ?? 0;
    final ngoId = data['ngoId'] ?? data['ngo_id'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: flowState.showSuccess
              ? _buildSuccessScreen(title, category, affected, ngoId)
              : _buildFeedbackScreen(title, affected),
        ),
      ),
    );
  }

  void _exitCompletionFlow() {
    ref.read(completionFlowProvider.notifier).exitFlow();
    setState(() {
      _showFeedback = false;
      _feedbackRating = 0;
      _feedbackTags.clear();
      _feedbackNotes.clear();
    });
    ref.read(volunteerTabControllerProvider.notifier).state = 0;
  }

  // ── MISSION SUCCESS SCREEN ──
  Widget _buildSuccessScreen(String title, String category, dynamic affected, String ngoId) {
    final catLabel = category.isNotEmpty ? '${category[0].toUpperCase()}${category.substring(1)}' : 'Emergency';

    return Column(
      children: [
        const SizedBox(height: 24),
        // Animated success icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDCFCE7),
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 52),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Mission Successfully\nCompleted',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.2),
        ),
        const SizedBox(height: 10),
        Text(
          'All operational objectives completed successfully.\nThank you for supporting this response effort.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 32),

        // Impact Summary Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IMPACT SUMMARY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 1)),
              const SizedBox(height: 16),
              _summaryRow('Mission Type', '$catLabel Response'),
              _summaryRow('Location', 'Mahananda Colony'),
              _summaryRow('People Assisted', '$affected'),
              ngoId.isNotEmpty
                  ? StreamBuilder<NgoModel?>(
                      stream: ref.watch(ngoServiceProvider).watchById(ngoId),
                      builder: (ctx, snap) => _summaryRow('NGO Partner', snap.data?.ngoName ?? 'NGO Partner'),
                    )
                  : _summaryRow('NGO Partner', 'Local Partner'),
              _summaryRow('Status', 'Resolved', isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Impact Overview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF22C55E), size: 28),
              const SizedBox(height: 10),
              Text(
                'Your response helped provide $catLabel assistance to approximately $affected affected people.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF166534), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Contribution Metrics
        Row(children: [
          _statCard('People Helped', '$affected'),
          const SizedBox(width: 10),
          _statCard('Reports Filed', '1'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _statCard('Category', catLabel),
          const SizedBox(width: 10),
          _statCard('Status', 'Resolved'),
        ]),
        const SizedBox(height: 16),

        // Lives Impacted highlight
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            children: [
              Text('LIVES IMPACTED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB), letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('+$affected', style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Mission Evidence
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.verified, color: Color(0xFF22C55E), size: 18),
                const SizedBox(width: 8),
                Text('Field Verification Successful', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              ]),
              const SizedBox(height: 10),
              Text('Mission ID: ${ref.read(completionFlowProvider).missionId?.substring(0, math.min(8, ref.read(completionFlowProvider).missionId?.length ?? 0))}...', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF94A3B8))),
              const SizedBox(height: 4),
              Text('Verified \u2022 ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Thank you acknowledgment
        Text(
          'Your field response has been logged. This mission is now marked as resolved and has been added to your volunteer history.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 24),

        // Primary CTA
        _primaryButton('Return To Home', () => _exitCompletionFlow()),
        const SizedBox(height: 12),
        // Secondary CTA
        _outlineButton('View Mission History', () {
          _exitCompletionFlow();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VolunteerMissionHistoryPage()),
          );
        }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shared UI helpers
  Widget _activeCard({
    required String badge,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _outlineButton(String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
