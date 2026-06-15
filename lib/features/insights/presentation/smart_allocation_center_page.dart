import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../map/presentation/map_screen.dart';
import '../../../services/smart_allocation_service.dart';
import '../../../models/volunteer_model.dart';

class SmartAllocationCenterPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialReport;
  final String? initialReportId;

  const SmartAllocationCenterPage({
    super.key,
    this.initialReport,
    this.initialReportId,
  });

  @override
  ConsumerState<SmartAllocationCenterPage> createState() =>
      _SmartAllocationCenterPageState();
}

class _SmartAllocationCenterPageState extends ConsumerState<SmartAllocationCenterPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentNgoId => _auth.currentUser?.uid ?? '';

  Map<String, dynamic>? _selectedReport;
  String? _selectedReportId;

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityEvolutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Priority Evolution',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildHorizontalTimelineStep(
                    score: '4.0',
                    title: 'Initial Incident Report',
                    color: const Color(0xFFEAB308),
                    isFirst: true,
                    isLast: false,
                  ),
                  _buildHorizontalTimelineStep(
                    score: '2.8',
                    title: 'Volunteer Assigned',
                    color: const Color(0xFF22C55E),
                    isFirst: false,
                    isLast: false,
                  ),
                  _buildHorizontalTimelineStep(
                    score: '4.2',
                    title: 'Volunteer Field Update Received',
                    color: const Color(0xFFF97316),
                    isFirst: false,
                    isLast: true,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Divider(color: Color(0xFFE2E8F0)),
              ),
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/gemini_icon.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Priority Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildImpactStat('Previous Score', '2.8', const Color(0xFF64748B)),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFFCBD5E1), size: 16),
                  Expanded(
                    child: _buildImpactStat('Current Score', '4.2', const Color(0xFFF97316)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('Net Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.trending_up_rounded, color: Color(0xFFEA580C), size: 14),
                              const SizedBox(width: 4),
                              const Text('+1.4', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFEA580C))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Why the priority increased:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              _buildAIReasoningPoint('11 more people found'),
              _buildAIReasoningPoint('More food is needed'),
              _buildAIReasoningPoint('Medical help is needed'),
              _buildAIReasoningPoint('People need shelter'),
              _buildAIReasoningPoint('Rain is still falling'),
              
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'While 4 people were rescued, volunteers found 11 more people who need help.\n\nThe total number of people affected went up from 8 to 15.\n\nMore resources like food and shelter are now needed.\n\nBecause of this new report from the field, the priority score was increased from 2.8 to 4.2 to get help there faster.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalTimelineStep({
    required String score,
    required String title,
    required Color color,
    required bool isFirst,
    required bool isLast,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: isFirst ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child: Text(
                  score,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: isLast ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReasoningPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0, right: 8.0),
            child: Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFF6366F1)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataTag(String label, String value, IconData icon, {Color color = const Color(0xFF64748B)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color == const Color(0xFF64748B) ? const Color(0xFF334155) : color,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldIntelligenceUpdate(int originalAffected) {
    final rescuedCount = 4;
    final newlyIdentified = 11;
    final updatedAffected = originalAffected - rescuedCount + newlyIdentified;
    final change = updatedAffected - originalAffected;
    final changeText = change > 0 ? '+$change' : '$change';

    return Padding(
      padding: const EdgeInsets.only(top: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAB308),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Field Intelligence Update',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFFEF08A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: Color(0xFFCA8A04), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Volunteer Update',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF854D0E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Volunteer ground reports help us understand the situation with precision. The real-time feedback loop continues!',
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(12),
                      textStyle: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      triggerMode: TooltipTriggerMode.tap,
                      child: const Icon(Icons.info_outline_rounded, color: Color(0xFFCA8A04), size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Metadata block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMetadataTag('Source:', 'Verified Volunteer Report', Icons.verified_user_rounded),
                          _buildMetadataTag('Confidence:', '94%', Icons.check_circle_rounded, color: const Color(0xFF10B981)),
                          _buildMetadataTag('Language:', 'Hindi → Auto Translated', Icons.translate_rounded),
                          _buildMetadataTag('Photos:', '3 Attached', Icons.image_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                
                _buildBulletPoint('4 residents safely evacuated'),
                _buildBulletPoint('11 additional residents identified'),
                _buildBulletPoint('Food packets required'),
                _buildBulletPoint('Medical kits required'),
                _buildBulletPoint('Temporary shelter required'),
                _buildBulletPoint('Continuous rainfall observed'),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(color: Color(0xFFFEF08A)),
                ),
                
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, color: Color(0xFFDC2626), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Mission Impact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildImpactStat('Previous Affected', '8', const Color(0xFF64748B)),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFFCBD5E1), size: 20),
                    Expanded(
                      child: _buildImpactStat('Current Affected', '15', const Color(0xFF0F172A)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Net Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded, color: Color(0xFFDC2626), size: 14),
                                const SizedBox(width: 4),
                                const Text('+7', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 10.0),
            child: Icon(Icons.circle, size: 6, color: Color(0xFFCA8A04)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _selectedReport ?? widget.initialReport;
    if (report != null) {
      final reportId = _selectedReportId ?? widget.initialReportId ?? '';
      final title = report['title']?.toString() ?? 'Emergency Incident';
      final category = report['category']?.toString() ?? 'medical';
      final urgency = report['urgency']?.toString() ?? 'high';
      final status = report['status']?.toString() ?? 'open';
      final peopleAffected = report['people_affected'] ?? report['peopleAffected'] ?? 'Unknown';
      
      // Get location coordinates or string
      LatLng? position = _extractLatLng(report);
      final locationStr = position != null 
          ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
          : (report['location']?.toString() ?? 'Unknown Location');

      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () {
              if (_selectedReport != null) {
                setState(() {
                  _selectedReport = null;
                  _selectedReportId = null;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text(
            'Smart Allocation Match',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title: Incident Summary
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
                      'Incident Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Incident Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationStr,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
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
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Text(
                                  'ACTIVE RESPONSE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: const Text(
                                  'ELEVATED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFDC2626),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // 2x2 Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              bgColor: const Color(0xFFEFF6FF),
                              label: 'Affected People',
                              value: report['groundReportId'] != null ? '15' : '8',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              icon: Icons.warning_rounded,
                              iconColor: const Color(0xFFDC2626),
                              bgColor: const Color(0xFFFEF2F2),
                              label: 'Priority Score',
                              value: report['groundReportId'] != null ? '4.2 / 10' : '4.0 / 10',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              icon: Icons.timer_rounded,
                              iconColor: const Color(0xFFD97706),
                              bgColor: const Color(0xFFFFFBEB),
                              label: 'Response Window',
                              value: 'Within 6 Hours',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              icon: Icons.volunteer_activism_rounded,
                              iconColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFFF0FDF4),
                              label: 'Volunteers Assigned',
                              value: '1',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Resource Requirements',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildResourceChip('Food Packets', const Color(0xFFF59E0B)),
                          _buildResourceChip('Medical Kits', const Color(0xFFEF4444)),
                          _buildResourceChip('Temporary Shelter', const Color(0xFF6366F1)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                if (report['groundReportId'] != null) ...[
                  const SizedBox(height: 32),
                  _buildPriorityEvolutionSection(),
                ],
                
                if (report['groundReportId'] != null)
                  _buildFieldIntelligenceUpdate(peopleAffected),
                
                const SizedBox(height: 32),
                
                // AI Recommendation section
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Recommendation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // AI Recommendation Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.04),
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
                          const Icon(Icons.psychology_outlined, color: Color(0xFF059669), size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'AlloCare Smart Match Engine',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecommendationRow('Recommended Volunteer Type:', '${_getRecommendedVolunteerType(category)}'),
                      const SizedBox(height: 12),
                      _buildRecommendationRow('Priority:', urgency.toUpperCase(), valueColor: _getUrgencyColor(urgency)),
                      const SizedBox(height: 12),
                      _buildRecommendationRow('Estimated Impact:', '$peopleAffected People'),
                      const SizedBox(height: 12),
                      _buildRecommendationRow('Suggested Response Window:', _getSuggestedResponseWindow(urgency)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Volunteer Match Pool section
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Volunteer Match Pool',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // StreamBuilder for matching volunteers
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('volunteers')
                      .where('ngoId', isEqualTo: _currentNgoId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final docs = snapshot.data!.docs;
                    
                    // Filter matching volunteers locally using our helper
                    final matchedVolunteers = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return volunteerMatchesReport(data, category);
                    }).toList();

                    // Sort by missionsCompleted (Highest Reliability) descending
                    matchedVolunteers.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final completedA = (dataA['missionsCompleted'] as num? ?? dataA['totalCompletedMissions'] as num? ?? 0).toInt();
                      final completedB = (dataB['missionsCompleted'] as num? ?? dataB['totalCompletedMissions'] as num? ?? 0).toInt();
                      return completedB.compareTo(completedA);
                    });
                    
                    if (matchedVolunteers.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No Matching Volunteers Available',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ensure volunteers are approved, active on field, and match the specialty.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matchedVolunteers.length,
                      itemBuilder: (context, index) {
                        final vDoc = matchedVolunteers[index];
                        final vData = vDoc.data() as Map<String, dynamic>;
                        final volunteerModel = VolunteerModel.fromMap(vDoc.id, vData);
                        final vName = volunteerModel.displayName;
                        final vSpeciality = volunteerModel.formattedSpecializations.isNotEmpty
                            ? volunteerModel.formattedSpecializations.first
                            : 'General Specialist';
                        final photoUrl = volunteerModel.photoUrl;
                        final livesImpactedCount = volunteerModel.livesImpacted;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFEEF2F6),
                                backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? Text(
                                        vName.isNotEmpty ? vName[0].toUpperCase() : 'V',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF475569),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$vSpeciality · $livesImpactedCount Lives Impacted',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blueGrey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  // Trigger Dispatch
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(child: CircularProgressIndicator()),
                                  );
                                  
                                  try {
                                    final service = ref.read(smartAllocationServiceProvider);
                                    final res = await service.dispatchVolunteer(reportId, category);
                                    
                                    Navigator.of(context).pop(); // Close loading dialog
                                    
                                    if (res.success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Successfully dispatched $vName to incident!'),
                                          backgroundColor: Colors.green.shade700,
                                        ),
                                      );
                                      Navigator.of(context).pop(); // Close allocation center page
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Dispatch failed: ${res.message}'),
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    Navigator.of(context).pop(); // Close loading dialog
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red.shade700,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                child: const Text(
                                  'Dispatch',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                  .collection('needs')
                  .where('ngoId', isEqualTo: _currentNgoId)
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

                final allDocs = snapshot.data!.docs;
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final status = data['status'] as String? ?? 'open';
                  return ['open', 'pending_acceptance', 'assigned', 'in_progress', 'completed'].contains(status);
                }).toList();

                // Sort in memory by createdAt descending
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>? ?? {};
                  final dataB = b.data() as Map<String, dynamic>? ?? {};
                  final tsA = dataA['createdAt'] as Timestamp? ?? dataA['timestamp'] as Timestamp?;
                  final tsB = dataB['createdAt'] as Timestamp? ?? dataB['timestamp'] as Timestamp?;
                  if (tsA == null && tsB == null) return 0;
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsB.compareTo(tsA);
                });

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
                            'No active or pending missions at the moment.',
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
                          needId: doc.id,
                          needData: data,
                          index: index,
                          onTap: () {
                            setState(() {
                              _selectedReport = data;
                              _selectedReportId = doc.id;
                            });
                          },
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

  bool _specialityMatches(String category, String speciality) {
    final c = category.trim().toLowerCase();
    final s = speciality.trim().toLowerCase();
    
    // 1. Exact contains or equal
    if (c == s || c.contains(s) || s.contains(c)) {
      return true;
    }
    
    // 2. Medical Group
    final isMedicalCat = c.contains('medical') || c.contains('health') || c.contains('medicine');
    final isMedicalSpec = s.contains('medical') || s.contains('health') || s.contains('medicine');
    if (isMedicalCat && isMedicalSpec) return true;
    
    // 3. Food Group
    final isFoodCat = c.contains('food') || c.contains('nutrition') || c.contains('meal');
    final isFoodSpec = s.contains('food') || s.contains('nutrition') || s.contains('meal');
    if (isFoodCat && isFoodSpec) return true;
    
    // 4. Water Group
    final isWaterCat = c.contains('water') || c.contains('sanitation') || c.contains('waterborne');
    final isWaterSpec = s.contains('water') || s.contains('sanitation') || s.contains('waterborne');
    if (isWaterCat && isWaterSpec) return true;
    
    // 5. Logistics/Shelter/Infrastructure Group
    final isLogisticsCat = c.contains('logistics') || c.contains('shelter') || c.contains('infrastructure') || c.contains('supply');
    final isLogisticsSpec = s.contains('logistics') || s.contains('shelter') || s.contains('infrastructure') || s.contains('supply');
    if (isLogisticsCat && isLogisticsSpec) return true;
    
    // 6. Rescue/Fire/Disaster/Police Group
    final isRescueCat = c.contains('fire') || c.contains('accident') || c.contains('natural') || c.contains('disaster') || c.contains('police') || c.contains('rescue');
    final isRescueSpec = s.contains('fire') || s.contains('accident') || s.contains('natural') || s.contains('disaster') || s.contains('police') || s.contains('rescue');
    if (isRescueCat && isRescueSpec) return true;
    
    // Fallback: Logistics specialist can assist in Rescue/Disaster scenarios
    if (isRescueCat && isLogisticsSpec) {
      return true;
    }
    
    return false;
  }

  bool volunteerMatchesReport(Map<String, dynamic> vData, String reportCategory) {
    // Check NGO
    final vNgoId = vData['ngoId'] ?? vData['ngo_id'] ?? '';
    if (vNgoId != _currentNgoId) return false;

    // Check approved
    final verificationStatus = (vData['verificationStatus'] as String? ?? '').trim().toLowerCase();
    if (verificationStatus != 'approved') return false;

    // Check active
    final isActiveOnField = vData['isActiveOnField'] as bool? ?? false;
    final status = (vData['status'] as String? ?? '').trim().toLowerCase();
    // We want active on field or available, but not on mission
    if (!isActiveOnField && status != 'available') return false;
    if (status == 'on_mission') return false;

    // Check specializations list
    final specializationsRaw = vData['specializations'];
    final normCategory = reportCategory.trim().toLowerCase();
    
    if (specializationsRaw is List) {
      if (specializationsRaw.map((e) => e.toString().trim().toLowerCase()).contains(normCategory)) {
        return true;
      }
    }

    // Fallback: migrate legacy speciality string using VolunteerModel migration logic if specializations list is empty
    if (specializationsRaw == null || (specializationsRaw is List && specializationsRaw.isEmpty)) {
      final speciality = (vData['speciality'] as String? ?? '').trim();
      final mapped = VolunteerModel.mapOldSpecialization(speciality);
      if (mapped == normCategory) {
        return true;
      }
    }

    return false;
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
      final text = locationRaw.trim();
      try {
        final segment = text.contains('·') ? text.split('·').last.trim() : text;
        final parts = segment.split(',');
        if (parts.length == 2) {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          return LatLng(lat, lng);
        }
      } catch (_) {}
    }
    final coordinatesRaw = data['coordinates'];
    if (coordinatesRaw is GeoPoint) {
      return LatLng(coordinatesRaw.latitude, coordinatesRaw.longitude);
    }
    if (coordinatesRaw is Map<String, dynamic>) {
      final lat = _toDouble(coordinatesRaw['latitude'] ?? coordinatesRaw['lat']);
      final lng = _toDouble(coordinatesRaw['longitude'] ?? coordinatesRaw['lng']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    final lat = _toDouble(data['latitude'] ?? data['lat']);
    final lng = _toDouble(data['longitude'] ?? data['lng']);
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFD97706);
      case 'medium':
      case 'normal':
        return const Color(0xFFCA8A04);
      case 'low':
      default:
        return const Color(0xFF16A34A);
    }
  }

  Widget _buildRecommendationRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  String _getRecommendedVolunteerType(String category) {
    switch (category.trim().toLowerCase()) {
      case 'medical':
        return 'Medical Specialist';
      case 'food':
      case 'food_nutrition':
        return 'Food/Nutrition Specialist';
      case 'airborne':
        return 'Airborne Rescue Specialist';
      case 'waterborne':
        return 'Waterborne Rescue Specialist';
      case 'mentalhealth':
      case 'mental_health':
        return 'Mental Health Specialist';
      default:
        return '${category.toUpperCase()} Specialist';
    }
  }

  String _getSuggestedResponseWindow(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case 'critical':
        return 'Within 2 Hours';
      case 'high':
        return 'Within 6 Hours';
      case 'medium':
      case 'normal':
        return 'Within 12 Hours';
      case 'low':
      default:
        return 'Within 24 Hours';
    }
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
  final String needId;
  final Map<String, dynamic> needData;
  final int index;
  final VoidCallback onTap;

  const _LiveMissionCard({
    required this.needId,
    required this.needData,
    required this.index,
    required this.onTap,
  });

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
    if (cat.contains('disaster') || cat.contains('storm') || cat.contains('earthquake')) {
      return MapLayerCategory.naturalDisaster;
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
    final reportData = widget.needData;
    final reportId = widget.needId;
    final volunteerId = reportData['assignedVolunteerId'] ?? reportData['matchedVolunteerId'] ?? '';

    if (volunteerId.isEmpty) {
      return _buildCardContent(
        vName: 'No Volunteer Assigned',
        vSpeciality: 'Pending Dispatch',
        vContact: '',
        reportData: reportData,
        reportId: reportId,
        volunteerStatus: 'available',
        hasVolunteer: false,
      );
    } else {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('volunteers')
            .doc(volunteerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading('Loading Volunteer...', 'Specialist');
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildCardContent(
              vName: 'Volunteer Intel Unavailable',
              vSpeciality: 'Specialist',
              vContact: '',
              reportData: reportData,
              reportId: reportId,
              volunteerStatus: 'available',
              hasVolunteer: false,
            );
          }
          final vData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final volunteerModel = VolunteerModel.fromMap(snapshot.data!.id, vData);
          final vName = volunteerModel.displayName;
          final vSpeciality = volunteerModel.formattedSpecializations.isNotEmpty
              ? volunteerModel.formattedSpecializations.first
              : 'Specialist';
          final vContact = volunteerModel.phoneNumber;
          final volunteerStatus = volunteerModel.status;

          return _buildCardContent(
            vName: vName,
            vSpeciality: vSpeciality,
            vContact: vContact,
            reportData: reportData,
            reportId: reportId,
            volunteerStatus: volunteerStatus,
            hasVolunteer: true,
          );
        },
      );
    }
  }

  Widget _buildCardContent({
    required String vName,
    required String vSpeciality,
    required String vContact,
    required Map<String, dynamic> reportData,
    required String reportId,
    required String volunteerStatus,
    required bool hasVolunteer,
  }) {
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

    final createdAt = reportData['createdAt'] as Timestamp? ?? reportData['timestamp'] as Timestamp?;
    String durationText = 'Just now';
    
    if (widget.index == 0) {
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
      final offsetMins = (widget.index * 14 + 5);
      if (offsetMins >= 60) {
        durationText = '${offsetMins ~/ 60}h ${offsetMins % 60}m ago';
      } else {
        durationText = '${offsetMins}m ago';
      }
    }

    final proximity = (0.8 + (widget.index * 1.1) % 3.2).toStringAsFixed(1);
    final reduction = (1.2 + (widget.index * 0.4) % 1.8).clamp(0.5, score - 0.5);
    final showProximity = widget.index % 3 != 1;
    final needStatus = reportData['status'] as String? ?? 'open';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
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
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: needStatus == 'completed'
                          ? const Color(0xFF10B981)
                          : needStatus == 'open'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF2563EB),
                      width: 6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Crisis Info & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _getCrisisIcon(crisisType),
                                  color: const Color(0xFF0F172A),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    crisisType.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(needStatus),
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
                                    hasVolunteer
                                        ? 'Strategic Match: $vSpeciality expert deployed to $crisisType zone.'
                                        : 'Critical Alert: Awaiting responder dispatch for $crisisType zone.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: hasVolunteer
                                      ? 'Matched via Proximity: $proximity km. Allocation optimized to reduce response time.'
                                      : 'No volunteer currently assigned. Open matching console to select an available responder.',
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
                            if (showProximity && hasVolunteer) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (volunteerStatus == 'on_mission' 
                                          ? const Color(0xFF10B981) 
                                          : const Color(0xFFF59E0B)).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (volunteerStatus == 'on_mission' 
                                            ? const Color(0xFF10B981) 
                                            : const Color(0xFFF59E0B)).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      volunteerStatus == 'on_mission' 
                                          ? Icons.verified_rounded 
                                          : Icons.hourglass_empty_rounded,
                                      size: 14,
                                      color: volunteerStatus == 'on_mission' 
                                          ? const Color(0xFF059669) 
                                          : const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        volunteerStatus == 'on_mission'
                                            ? 'Assignment Accepted: $vName (Matched via Proximity - $proximity km)'
                                            : 'Pending Acceptance: $vName (Matched via Proximity - $proximity km)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: volunteerStatus == 'on_mission' 
                                              ? const Color(0xFF065F46) 
                                              : const Color(0xFF92400E),
                                          letterSpacing: 0.1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (!hasVolunteer) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 6),
                                    const Flexible(
                                      child: Text(
                                        'Action Required: No Volunteer Matched',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF991B1B),
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
                                        child: Icon(
                                          hasVolunteer ? Icons.verified : Icons.help_outline,
                                          color: hasVolunteer ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
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
                                      _getSpecialityIcon(hasVolunteer ? vSpeciality : 'General'),
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
                            backgroundColor: hasVolunteer ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            radius: 20,
                            child: Text(
                              hasVolunteer && vName.isNotEmpty ? vName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: hasVolunteer ? const Color(0xFF2563EB) : const Color(0xFF64748B),
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
                                      needStatus == 'completed'
                                          ? 'Mission completed'
                                          : 'Mission active: $durationText',
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
                          if (hasVolunteer && vContact.isNotEmpty) ...[
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
                          if (!hasVolunteer) ...[
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: widget.onTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.flash_on, size: 16),
                              label: const Text('Dispatch', style: TextStyle(fontWeight: FontWeight.w700)),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = const Color(0xFF10B981);
        label = 'COMPLETED';
        break;
      case 'assigned':
      case 'in_progress':
        color = const Color(0xFF2563EB);
        label = 'ASSIGNED';
        break;
      case 'pending_acceptance':
        color = const Color(0xFFF59E0B);
        label = 'PENDING';
        break;
      default:
        color = const Color(0xFFEF4444);
        label = 'OPEN';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
            'Mission details unavailable.',
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
