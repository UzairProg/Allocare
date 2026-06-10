import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/firestore/firestore_paths.dart';
import '../../../../services/smart_allocation_service.dart';
import '../../../../services/volunteer_service.dart';
import '../controllers/volunteer_controller.dart';

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color});
  final Color color;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 3.0, end: 9.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 10 + _animation.value,
                height: 10 + _animation.value,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VolunteerMissionDetailScreen extends ConsumerStatefulWidget {
  const VolunteerMissionDetailScreen({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  final String reportId;
  final Map<String, dynamic> reportData;

  @override
  ConsumerState<VolunteerMissionDetailScreen> createState() => _VolunteerMissionDetailScreenState();
}

class _VolunteerMissionDetailScreenState extends ConsumerState<VolunteerMissionDetailScreen> {
  bool _isCompleting = false;
  bool _isLoading = false;

  Future<void> _launchDirections(double lat, double lng) async {
    final vId = ref.read(currentVolunteerProvider).value?.uid;
    if (vId != null) {
      await ref.read(smartAllocationServiceProvider).startNavigationEvent(
            needId: widget.reportId,
            volunteerId: vId,
          );
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Google Maps.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching navigation: $e')),
        );
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  LatLng? _extractLatLng(Map<String, dynamic> data) {
    final locationRaw = data['location'];
    if (locationRaw is GeoPoint) {
      return LatLng(locationRaw.latitude, locationRaw.longitude);
    }
    if (locationRaw is String) {
      final parts = locationRaw.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    }
    final lat = _toDouble(data['latitude'] ?? data['lat']);
    final lng = _toDouble(data['longitude'] ?? data['lng']);
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  Color _colorForUrgency(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
      case 'normal':
        return const Color(0xFFEAB308);
      default:
        return const Color(0xFF22C55E);
    }
  }

  String _calculateDistanceAndETA(LatLng? target) {
    if (target == null) return 'Calculating...';
    const baseLat = 19.8762;
    const baseLng = 75.3433;
    final dy = (target.latitude - baseLat) * 111.0;
    final dx = (target.longitude - baseLng) * 111.0 * 0.94;
    final distance = math.sqrt(dx * dx + dy * dy);
    final km = distance > 50 ? 2.4 : distance;
    final etaMinutes = (km * 2).round();
    final etaStr = etaMinutes <= 1 ? '1 min' : '$etaMinutes mins';
    return '${km.toStringAsFixed(1)} km ($etaStr)';
  }

  Future<void> _handleAcceptMission(String volunteerId, String volunteerName) async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(smartAllocationServiceProvider).acceptMission(
            needId: widget.reportId,
            volunteerId: volunteerId,
            volunteerName: volunteerName,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mission accepted! Heading en route.'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeclineMission(String volunteerId) async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(smartAllocationServiceProvider).declineMission(
            needId: widget.reportId,
            volunteerId: volunteerId,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mission declined.'), backgroundColor: Colors.orange),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleArrivedOnSite(String volunteerId) async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(smartAllocationServiceProvider).markArrivedOnSite(
            needId: widget.reportId,
            volunteerId: volunteerId,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated: Arrived on site.'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBeginFieldOperations(String volunteerId) async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(smartAllocationServiceProvider).beginFieldOperations(
            needId: widget.reportId,
            volunteerId: volunteerId,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Field Operations active! Reporting unlocked.'), backgroundColor: Colors.green),
          );
          ref.read(volunteerTabControllerProvider.notifier).state = 1;
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCompleteMission(String volunteerId) async {
    setState(() => _isCompleting = true);
    try {
      final success = await ref.read(smartAllocationServiceProvider).completeMission(
            needId: widget.reportId,
            volunteerId: volunteerId,
          );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mission completed successfully! Safe state restored.'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Widget _buildIntelItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildIntelBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final volunteer = ref.watch(currentVolunteerProvider).value;
    final volunteerId = volunteer?.uid ?? '';
    final volunteerName = volunteer?.displayName ?? 'Volunteer Responder';
    final needData = widget.reportData;
    final title = needData['crisis_type'] ?? needData['subcategory'] ?? needData['title'] ?? 'Emergency Mission';
    final description = needData['description'] ?? needData['notes'] ?? 'No description provided for this assignment.';
    final urgency = needData['urgency'] ?? 'Medium';
    final peopleAffected = needData['peopleAffected'] ?? needData['people_affected'] ?? 0;
    final ngoName = needData['ngoName'] ?? needData['ngo_name'] ?? 'Assigned NGO Partner';
    final status = needData['status'] ?? 'assigned';
    final imageUrl = needData['image_url'] ?? needData['imageUrl'];
    final category = needData['category'] ?? needData['crisis_type'] ?? 'General';
    final latLng = _extractLatLng(needData);
    final distanceAndETA = _calculateDistanceAndETA(latLng);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'EMERGENCY CONSOLE',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.5,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(FirestorePaths.reports)
            .doc(widget.reportId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFF0F172A))));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? needData;
          final currentStatus = data['status'] ?? status;
          final currentPeopleAffected = data['peopleAffected'] ?? data['people_affected'] ?? peopleAffected;
          final currentNgoName = data['ngoName'] ?? data['ngo_name'] ?? ngoName;

          String statusChipText = 'Assigned';
          Color statusChipColor = const Color(0xFF0284C7);
          if (currentStatus == 'pending_acceptance') {
            statusChipText = 'Pending Acceptance';
            statusChipColor = const Color(0xFFD97706);
          } else if (currentStatus == 'accepted') {
            statusChipText = 'En Route';
            statusChipColor = const Color(0xFF4F46E5);
          } else if (currentStatus == 'on_site') {
            statusChipText = 'Arrived On Site';
            statusChipColor = const Color(0xFF10B981);
          } else if (currentStatus == 'field_active') {
            statusChipText = 'Field Operations Active';
            statusChipColor = const Color(0xFFEC4899);
          } else if (currentStatus == 'completed') {
            statusChipText = 'Completed';
            statusChipColor = const Color(0xFF10B981);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branded Mission Header Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusChipColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusChipColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: statusChipColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusChipText.toUpperCase(),
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: statusChipColor),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _colorForUrgency(urgency).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _colorForUrgency(urgency).withOpacity(0.2)),
                            ),
                            child: Text(
                              urgency.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _colorForUrgency(urgency),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['address'] ?? data['area_name'] ?? data['city'] ?? 'Target Coordinates Assigned',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.corporate_fare_rounded, color: Color(0xFF4F46E5), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Assigned NGO: ',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                          ),
                          Text(
                            currentNgoName,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Gemini Intelligence Summary Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4F46E5).withOpacity(0.06),
                        const Color(0xFF0284C7).withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_rounded, color: Color(0xFF4F46E5), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'GEMINI INTEL LOG',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4F46E5),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildIntelItem('Recommended Action', 'Deploy standard medical & water purification supplies immediately. Avoid low-lying flooded paths.'),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildIntelBadge('EST. IMPACT', 'High (100+ civilians)', const Color(0xFFEF4444)),
                          ),
                          Expanded(
                            child: _buildIntelBadge('PRIORITY', 'Critical Response', const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Compact Mission Stats Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.map_outlined, 'DISTANCE & ETA', distanceAndETA),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                      _buildStatItem(Icons.people_outline, 'AFFECTED', '$currentPeopleAffected'),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                      _buildStatItem(Icons.category_outlined, 'CATEGORY', category.toString().toUpperCase()),
                    ],
                  ),
                ),

                // Action controls based on status phase
                _buildActionControls(currentStatus, volunteerId, volunteerName, latLng),
                const SizedBox(height: 24),

                // Description
                Text(
                  'MISSION OVERVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stepper/Mission Progress Tracking
                Text(
                  'MISSION PROGRESS TRACKER',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTimelineProgress(currentStatus),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionControls(String status, String volunteerId, String volunteerName, LatLng? latLng) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    switch (status) {
      case 'pending_acceptance':
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PENDING ACCEPTANCE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD97706),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Review details and accept the match to deploy navigation routing.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleDeclineMission(volunteerId),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleAcceptMission(volunteerId, volunteerName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Accept Mission'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'accepted':
        return Column(
          children: [
            if (latLng != null) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _launchDirections(latLng.latitude, latLng.longitude),
                  icon: const Icon(Icons.navigation_rounded, size: 20, color: Colors.white),
                  label: Text(
                    'Navigate To Incident',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _handleArrivedOnSite(volunteerId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Confirm Arrival',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );

      case 'on_site':
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _handleBeginFieldOperations(volunteerId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Begin Field Operations',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

      case 'field_active':
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('needs')
              .doc(widget.reportId)
              .collection('updates')
              .snapshots(),
          builder: (context, snapshot) {
            final hasUpdates = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasUpdates) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'At least 1 situation report is required in the workspace to complete this mission.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref.read(volunteerTabControllerProvider.notifier).state = 1;
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.edit_document, size: 16),
                          label: const Text('Submit Situation Report'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (hasUpdates && !_isCompleting)
                              ? () => _handleCompleteMission(volunteerId)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCompleting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Complete Mission',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: hasUpdates ? Colors.white : const Color(0xFF94A3B8),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );

      case 'completed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION RESOLVED',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF065F46),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thank you for your service! The disaster area has been marked resolved.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  int _getCurrentStepIndex(String status) {
    switch (status) {
      case 'pending_acceptance':
        return 2;
      case 'accepted':
        return 3;
      case 'on_site':
        return 4;
      case 'field_active':
        return 4;
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }

  Widget _buildTimelineProgress(String status) {
    final activeIndex = _getCurrentStepIndex(status);

    final steps = [
      {'title': 'Need Created', 'desc': 'Incident synced in command console.'},
      {'title': 'Match Found', 'desc': 'AI responder matching completed.'},
      {'title': 'Mission Accepted', 'desc': 'Transit clearance confirmed.'},
      {'title': 'Arrived On Site', 'desc': 'Verified at coordinates.'},
      {'title': 'Field Ops Active', 'desc': 'Submitting logs to command.'},
      {'title': 'Mission Completed', 'desc': 'Area declared resolved.'},
    ];

    return Column(
      children: List.generate(steps.length, (idx) {
        final step = steps[idx];
        final isCompleted = idx < activeIndex || (status == 'completed' && idx == 5);
        final isActive = idx == activeIndex && status != 'completed';
        final isLast = idx == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                if (isCompleted)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  )
                else if (isActive)
                  const PulsingDot(color: Color(0xFF4F46E5))
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
                    child: const Icon(Icons.circle, size: 6, color: Color(0xFF94A3B8)),
                  ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title']!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? const Color(0xFF0F172A)
                          : isActive
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step['desc']!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isCompleted || isActive ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
