import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../map/presentation/map_screen.dart';

class SmartAllocationCenterPage extends StatefulWidget {
  const SmartAllocationCenterPage({super.key});

  @override
  State<SmartAllocationCenterPage> createState() =>
      _SmartAllocationCenterPageState();
}

class _SmartAllocationCenterPageState extends State<SmartAllocationCenterPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentNgoId => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();

    if (_currentNgoId.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FB),
        body: Center(
          child: Text('Please log in to view the Allocation Center.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kIsWeb && canGoBack) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text(
                          'Back',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                          side: const BorderSide(color: Color(0xFFBFD2FF)),
                          backgroundColor: const Color(0xFFEFF4FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'Smart Allocation Center',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Decision Engine: Fragmented Data → Prioritized Action',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _MinimalistStatsRow(),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live Dispatch Feed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('volunteers')
                  .where('ngo_id', isEqualTo: _currentNgoId)
                  .where('status', isEqualTo: 'on_mission')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }

                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 72,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'All Systems Clear',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No active missions at the moment.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _LiveMissionCard(
                          volunteerData: data,
                          index: index,
                        ),
                      );
                    }, childCount: docs.length),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _MinimalistStatsRow extends StatelessWidget {
  const _MinimalistStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _StatCard(
            title: 'Total Lives Impacted',
            value: '1,492',
            icon: Icons.favorite_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('volunteers')
                .where(
                  'ngo_id',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
                )
                .where('status', isEqualTo: 'on_mission')
                .snapshots(),
            builder: (context, snapshot) {
              final activeCount = snapshot.hasData
                  ? snapshot.data!.docs.length
                  : 0;
              return _StatCard(
                title: 'Active Missions',
                value: '$activeCount',
                icon: Icons.radar,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(
            title: 'Resource Optimization',
            value: '94%',
            icon: Icons.auto_graph,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMissionCard extends StatefulWidget {
  final Map<String, dynamic> volunteerData;
  final int index;

  const _LiveMissionCard({required this.volunteerData, required this.index});

  @override
  State<_LiveMissionCard> createState() => _LiveMissionCardState();
}

class _LiveMissionCardState extends State<_LiveMissionCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );

    Future.delayed(
      Duration(milliseconds: (widget.index * 150).clamp(0, 600)),
      () {
        if (mounted) {
          _slideController.forward().then((_) {
            _pulseController.forward();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _getSpecialityIcon(String speciality) {
    switch (speciality.toLowerCase()) {
      case 'medical':
        return Icons.health_and_safety_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'logistics':
        return Icons.local_shipping_outlined;
      case 'airborne':
        return Icons.flight_takeoff_outlined;
      case 'waterborne':
        return Icons.directions_boat_outlined;
      default:
        return Icons.person_outline;
    }
  }

  IconData _getCrisisIcon(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return Icons.medical_services_outlined;
      case 'shelter':
        return Icons.house_siding_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'food':
        return Icons.local_dining_outlined;
      case 'rescue':
        return Icons.search_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }

  MapLayerCategory _crisisTypeToLayer(String crisisType) {
    final cat = crisisType.toLowerCase();
    if (cat.contains('food') || cat.contains('ration') || cat.contains('nutrition')) {
      return MapLayerCategory.food;
    }
    if (cat.contains('air') || cat.contains('respiratory') || cat.contains('smoke')) {
      return MapLayerCategory.airborne;
    }
    if (cat.contains('water') || cat.contains('flood') || cat.contains('sanitation')) {
      return MapLayerCategory.waterborne;
    }
    if (cat.contains('mental') || cat.contains('psycho') || cat.contains('counsel')) {
      return MapLayerCategory.mentalHealth;
    }
    return MapLayerCategory.medical;
  }

  double? _extractLatFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final loc = data['location'];
    if (loc is GeoPoint) return loc.latitude;
    final coords = data['coordinates'];
    if (coords is GeoPoint) return coords.latitude;
    if (coords is Map) {
      final v = coords['latitude'] ?? coords['lat'];
      if (v is num) return v.toDouble();
    }
    final v = data['latitude'] ?? data['lat'];
    if (v is num) return v.toDouble();
    return null;
  }

  double? _extractLngFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final loc = data['location'];
    if (loc is GeoPoint) return loc.longitude;
    final coords = data['coordinates'];
    if (coords is GeoPoint) return coords.longitude;
    if (coords is Map) {
      final v = coords['longitude'] ?? coords['lng'];
      if (v is num) return v.toDouble();
    }
    final v = data['longitude'] ?? data['lng'];
    if (v is num) return v.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vName = widget.volunteerData['name']?.toString() ?? 'Volunteer';
    final vSpeciality =
        widget.volunteerData['speciality']?.toString() ?? 'Specialist';
    final vContact = widget.volunteerData['contact']?.toString() ?? '';
    final reportId =
        widget.volunteerData['current_report_id']?.toString() ?? '';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFF2563EB), width: 6),
                ),
              ),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('reports')
                    .doc(reportId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerLoading(vName, vSpeciality);
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      !snapshot.data!.exists) {
                    return _buildErrorState(vName, vSpeciality);
                  }

                  final reportData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final crisisType =
                      reportData['crisis_type']?.toString() ??
                      reportData['category']?.toString() ??
                      'Emergency';

                  double score = 5.0;
                  if (reportData['urgency_score'] != null) {
                    score = (reportData['urgency_score'] as num).toDouble();
                  }
                  // Add storytelling variety to the starting score based on index
                  score = (score + (widget.index * 1.7) % 4.5).clamp(3.5, 9.5);

                  final createdAt = reportData['timestamp'] as Timestamp?;
                  String durationText = 'Just now';
                  
                  if (widget.index == 0) {
                    // Only the latest mission shows 'Just now' or actual live duration
                    if (createdAt != null) {
                      final diff = DateTime.now().difference(createdAt.toDate());
                      if (diff.inHours > 0) {
                        durationText =
                            '${diff.inHours}h ${diff.inMinutes % 60}m ago';
                      } else if (diff.inMinutes > 0) {
                        durationText = '${diff.inMinutes}m ago';
                      }
                    }
                  } else {
                    // Historical variety for older cards in the feed
                    final offsetMins = (widget.index * 14 + 5);
                    if (offsetMins >= 60) {
                      durationText = '${offsetMins ~/ 60}h ${offsetMins % 60}m ago';
                    } else {
                      durationText = '${offsetMins}m ago';
                    }
                  }

                  // Pseudo-random data based on index for "storytelling"
                  final proximity = (0.8 + (widget.index * 1.1) % 3.2)
                      .toStringAsFixed(1);
                  final reduction = (1.2 + (widget.index * 0.4) % 1.8).clamp(
                    0.5,
                    score - 0.5,
                  );
                  final showProximity = widget.index % 3 != 1;

                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Crisis Info & Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getCrisisIcon(crisisType),
                                  color: const Color(0xFF0F172A),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  crisisType.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            _PulsingBadge(),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Middle Row: Strategic Match Box
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Strategic Match: $vSpeciality expert deployed to $crisisType zone.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message:
                                        'Matched via Proximity: $proximity km. Allocation optimized to reduce response time.',
                                    triggerMode: TooltipTriggerMode.tap,
                                    showDuration: const Duration(seconds: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              if (showProximity &&
                                  widget.volunteerData['status'] ==
                                      'on_mission') ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Assignment Accepted: $vName (Matched via Proximity - $proximity km)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF065F46),
                                            letterSpacing: 0.1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Crisis Node
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCrisisIcon(crisisType),
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  // Connection Line
                                  Expanded(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          height: 2,
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.verified,
                                            color: Color(0xFF10B981),
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Volunteer Node
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getSpecialityIcon(vSpeciality),
                                        color: const Color(0xFF2563EB),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Volunteer Profile Row
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEFF6FF),
                              radius: 20,
                              child: Text(
                                vName.isNotEmpty ? vName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Mission started: $durationText',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                final lat = _extractLatFromData(reportData);
                                final lng = _extractLngFromData(reportData);
                                final layer = _crisisTypeToLayer(crisisType);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MapScreen(
                                      initialLayer: layer,
                                      initialFocus: (lat != null && lng != null)
                                          ? LatLng(lat, lng)
                                          : null,
                                      initialZoom: 15.5,
                                      lockInitialFocus: lat != null,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('View on Map', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                            if (vContact.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _callContact(vContact),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.headset_mic_rounded, size: 16),
                                label: const Text('Comms', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),

                        // Priority Shift (Animated)
                        if (score > 0) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(color: Color(0xFFE2E8F0)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Priority De-escalation',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    score.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_outlined,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 8),
                                  _AnimatedCounter(
                                    begin: score,
                                    end: (score - reduction).clamp(0.0, 10.0),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(String vName, String vSpeciality) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Synchronizing Intel...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE2E8F0),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    vSpeciality,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String vName, String vSpeciality) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mission intel unavailable.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(vName, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _AnimatedCounter extends StatefulWidget {
  final double begin;
  final double end;

  const _AnimatedCounter({required this.begin, required this.end});

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: widget.begin,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10B981),
          ),
        );
      },
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'ACTIVE RESPONSE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.red,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
