import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../models/ground_report_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/smart_allocation_service.dart';
import '../../map/presentation/map_screen.dart';

class AIIntelReportScreen extends ConsumerStatefulWidget {
  final String reportType;
  final Map<String, dynamic>? aiAnalysisResult;
  final String appLocation;

  const AIIntelReportScreen({
    super.key,
    this.reportType = 'document_scan',
    this.aiAnalysisResult,
    required this.appLocation,
  });

  @override
  ConsumerState<AIIntelReportScreen> createState() => _AIIntelReportScreenState();
}

class _AIIntelReportScreenState extends ConsumerState<AIIntelReportScreen> {
  bool _isSubmitting = false;
  bool _isEditing = false;
  bool _isEvidenceExpanded = false;
  bool _isEnglishTranslated = false;

  late TextEditingController _titleController;
  late TextEditingController _impactController;
  late TextEditingController _summaryController;

  String _getTranslatedText(String key) {
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    if (_isEnglishTranslated && aiData['englishTranslation'] != null) {
      return aiData['englishTranslation'][key]?.toString() ?? aiData[key]?.toString() ?? '';
    }
    return aiData[key]?.toString() ?? '';
  }

  List<String> _getTranslatedList(String key) {
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    if (_isEnglishTranslated && aiData['englishTranslation'] != null) {
      final list = aiData['englishTranslation'][key] as List<dynamic>?;
      if (list != null) return list.map((e) => e.toString()).toList();
    }
    final list = aiData[key] as List<dynamic>?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }

  @override
  void initState() {
    super.initState();
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    _titleController = TextEditingController(text: _getTranslatedText('title').isNotEmpty ? _getTranslatedText('title') : 'Report');
    _impactController = TextEditingController(text: aiData['peopleAffected']?.toString() ?? '0');
    _summaryController = TextEditingController(text: _getTranslatedText('summary').isNotEmpty ? _getTranslatedText('summary') : _getTranslatedText('description'));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _impactController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    setState(() {
      _isEditing = false;
      _isSubmitting = true;
    });
    
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not logged in');

      final raw = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
      final fileMetadata = widget.aiAnalysisResult?['fileMetadata'] as Map<String, dynamic>? ?? {};

      int peopleAffected = int.tryParse(_impactController.text.trim()) ?? 0;
      int urgencyScore = 0;
      try {
        urgencyScore = int.parse(raw['urgency_score']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0');
      } catch (_) {}

      double lat = 0.0;
      try { lat = double.parse(raw['latitude']?.toString() ?? '0'); } catch (_) {}
      double lng = 0.0;
      try { lng = double.parse(raw['longitude']?.toString() ?? '0'); } catch (_) {}

      String rawCategory = (raw['category']?.toString() ?? 'other').toLowerCase();
      String category = 'other';
      if (rawCategory.contains('medical')) category = 'medical';
      else if (rawCategory.contains('fire')) category = 'fire';
      else if (rawCategory.contains('police') || rawCategory.contains('crime')) category = 'police';
      else if (rawCategory.contains('accident')) category = 'accident';
      else if (rawCategory.contains('infrastructure')) category = 'infrastructure';
      else if (rawCategory.contains('natural')) category = 'natural_disaster';

      String subcat = raw['subcategory']?.toString() ?? 'Other';
      if (subcat.isEmpty) subcat = 'Other';

      String formattedLocation = raw['location']?.toString() ?? 'Unknown location';
      if (lat != 0.0 || lng != 0.0) {
        formattedLocation = 'Live location · ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }

      final reportId = FirebaseFirestore.instance.collection('reports').doc().id;
      final payload = {
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'crisis_type': subcat,
        'description': raw['description']?.toString() ?? '',
        'ai_summary': _summaryController.text.trim(),
        'image_url': '',
        'latitude': lat,
        'location': formattedLocation,
        'locationMode': 'ai_scan',
        'longitude': lng,
        'peopleAffected': peopleAffected,
        'reportedBy': user.uid,
        'ngoId': user.uid,
        'ngo_id': user.uid,
        'status': 'open',
        'subcategory': subcat,
        'supportingDocsMetadata': [fileMetadata],
        'title': _titleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'urgency': raw['urgency']?.toString().toLowerCase() ?? 'low',
        'urgency_score': urgencyScore,
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('reports').doc(reportId), payload);
      batch.set(FirebaseFirestore.instance.collection('needs').doc(reportId), payload);
      batch.set(FirebaseFirestore.instance.collection('missions').doc(reportId), payload);
      await batch.commit();

      final allocationService = ref.read(smartAllocationServiceProvider);
      final allocationResult = await allocationService.dispatchVolunteer(
        reportId,
        category,
      );

      if (mounted) {
        if (allocationResult.success && allocationResult.volunteerName != null) {
          _showAllocationBottomSheet(
            volunteerName: allocationResult.volunteerName!,
            crisisType: category,
            areaName: formattedLocation,
            reportPosition: LatLng(lat, lng),
            categoryKey: category,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report saved to Command Center successfully!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showAllocationBottomSheet({
    required String volunteerName,
    required String crisisType,
    required String areaName,
    required LatLng reportPosition,
    required String categoryKey,
  }) {
    MapLayerCategory layer;
    switch (categoryKey) {
      case 'food':
        layer = MapLayerCategory.food;
        break;
      case 'airborne':
        layer = MapLayerCategory.airborne;
        break;
      case 'waterborne':
      case 'water':
        layer = MapLayerCategory.waterborne;
        break;
      case 'mental_health':
      case 'mental':
        layer = MapLayerCategory.mentalHealth;
        break;
      case 'natural_disaster':
        layer = MapLayerCategory.naturalDisaster;
        break;
      default:
        layer = MapLayerCategory.medical;
    }

    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AllocationResultSheet(
        volunteerName: volunteerName,
        crisisType: crisisType,
        areaName: areaName,
        layer: layer,
        reportPosition: reportPosition,
      ),
    ).then((viewOnMap) {
      if (mounted) {
        Navigator.of(context).pop();
        if (viewOnMap == true) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MapScreen(
                initialLayer: layer,
                initialFocus: reportPosition,
                initialZoom: 15.5,
                lockInitialFocus: true,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Field Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(), // Goes back to re-record
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTranslationToggle(),
                    _buildTopSection(),
                    const SizedBox(height: 32),
                    if (widget.aiAnalysisResult != null) ...[
                      _buildEvidenceVerificationSection(),
                      const SizedBox(height: 32),
                    ],
                    _buildImpactSection(),
                    const SizedBox(height: 32),
                    _buildResourcesSection(),
                    const SizedBox(height: 32),
                    _buildAIAnalysisSection(),
                    const SizedBox(height: 32),
                    _buildEvidenceSection(),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationToggle() {
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    final lang = aiData['detectedLanguage']?.toString().toLowerCase() ?? 'english';
    if (lang == 'english' || lang.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _isEnglishTranslated ? 'Translated to English' : 'Detected: ${aiData['detectedLanguage']}',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _isEnglishTranslated,
            onChanged: (val) {
              setState(() {
                _isEnglishTranslated = val;
                if (!_isEditing) {
                  _titleController.text = _getTranslatedText('incidentType').isNotEmpty ? _getTranslatedText('incidentType') : 'Report';
                  _summaryController.text = _getTranslatedText('summary');
                }
              });
            },
            activeColor: const Color(0xFF4F46E5),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceVerificationSection() {
    final fileMetadata = widget.aiAnalysisResult?['fileMetadata'] as Map<String, dynamic>? ?? {};
    final String fileName = fileMetadata['fileName']?.toString() ?? 'Document';

    return GestureDetector(
      onTap: () => setState(() => _isEvidenceExpanded = !_isEvidenceExpanded),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Extracted from Document', 
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF16A34A), fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(_isEvidenceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF16A34A), size: 16),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Powered by Gemini', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF15803D))),
                ),
              ],
            ),
            if (_isEvidenceExpanded) ...[
              const SizedBox(height: 12),
              Text('Intelligence successfully extracted from $fileName.', style: GoogleFonts.inter(color: const Color(0xFF15803D), fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    final severity = (aiData['urgency']?.toString() ?? 'medium').toLowerCase();
    
    Color severityBg = const Color(0xFFFFFBEB);
    Color severityBorder = const Color(0xFFFDE68A);
    Color severityText = const Color(0xFFD97706);
    
    if (severity == 'critical' || severity == 'high') {
       severityBg = const Color(0xFFFEF2F2);
       severityBorder = const Color(0xFFFECACA);
       severityText = const Color(0xFFDC2626);
    } else if (severity == 'low') {
       severityBg = const Color(0xFFF0FDF4);
       severityBorder = const Color(0xFFBBF7D0);
       severityText = const Color(0xFF16A34A);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 4),
                  Text(
                    'Gemini Intel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: severityBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: severityBorder),
              ),
              child: Text(
                severity[0].toUpperCase() + severity.substring(1),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: severityText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isEditing
            ? TextField(
                controller: _titleController,
                maxLines: null,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter incident title...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                  ),
                ),
              )
            : Text(
                _titleController.text,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.appLocation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Just now',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImpactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimated Impact',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFFDC2626), size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isEditing
                      ? SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _impactController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                              height: 1.0,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : Text(
                          _impactController.text,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                  const SizedBox(height: 6),
                  Text(
                    'People Affected',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResourcesSection() {
    final List<String> resources = _getTranslatedList('requiredResources');
    if (resources.isEmpty) {
      resources.addAll(['Medical Team', 'Clean Water Supply']); // Fallback
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Resources',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: resources.map((res) {
            IconData iconData = Icons.inventory_2_rounded;
            final lowerRes = res.toLowerCase();
            if (lowerRes.contains('medical') || lowerRes.contains('first aid') || lowerRes.contains('medicine') || lowerRes.contains('doctor') || lowerRes.contains('ambulance') || lowerRes.contains('clinic')) {
              iconData = Icons.medical_services_rounded;
            } else if (lowerRes.contains('water') || lowerRes.contains('hydration')) {
              iconData = Icons.water_drop_rounded;
            } else if (lowerRes.contains('food') || lowerRes.contains('meal') || lowerRes.contains('ration')) {
              iconData = Icons.restaurant_rounded;
            } else if (lowerRes.contains('fire')) {
              iconData = Icons.local_fire_department_rounded;
            } else if (lowerRes.contains('police') || lowerRes.contains('security')) {
              iconData = Icons.local_police_rounded;
            } else if (lowerRes.contains('shelter') || lowerRes.contains('tent') || lowerRes.contains('blanket')) {
              iconData = Icons.house_rounded;
            } else if (lowerRes.contains('power') || lowerRes.contains('electricity') || lowerRes.contains('generator')) {
              iconData = Icons.electrical_services_rounded;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: 14, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    res,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, size: 18, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(
                'Incident Report',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Builder(
              builder: (context) {
                final score = widget.aiAnalysisResult?['aiData']?['confidenceScore'] as int? ?? 90;
                final text = score >= 85 ? 'Confidence: $score%' : 'Confidence: Moderate ($score%)';
                return Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4F46E5),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _isEditing
              ? TextField(
                  controller: _summaryController,
                  maxLines: null,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF475569),
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                    ),
                  ),
                )
              : Text(
                  _summaryController.text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return const SizedBox.shrink(); // No supporting evidence thumbnails needed for AI Intel Scan
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : Text(
                      'CONFIRM & SUBMIT',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isSubmitting 
                  ? null 
                  : () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: _isEditing ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                side: BorderSide(
                  color: _isEditing ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1), 
                  width: 1.5
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: _isEditing ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.transparent,
              ),
              child: Text(
                _isEditing ? 'DONE EDITING' : 'EDIT REPORT DETAILS',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationResultSheet extends StatelessWidget {
  const _AllocationResultSheet({
    required this.volunteerName,
    required this.crisisType,
    required this.areaName,
    required this.layer,
    required this.reportPosition,
  });

  final String volunteerName;
  final String crisisType;
  final String areaName;
  final MapLayerCategory layer;
  final LatLng reportPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'VOLUNTEER ASSIGNED',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Volunteer Profile
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      volunteerName.isNotEmpty
                          ? volunteerName[0].toUpperCase()
                          : 'V',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volunteerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deployed to $crisisType · $areaName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Smart match chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Matched via skill profile · Closest $crisisType specialist in range · En route now.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // View on Map button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.map_outlined, size: 20),
                label: const Text(
                  'VIEW ON MAP',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Dismiss link
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
