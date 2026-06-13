import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../reports/data/repositories/ground_report_repository.dart';
import '../../../../models/ground_report_model.dart';
import '../../../../services/volunteer_service.dart';

class VolunteerAIGeneratedReportScreen extends ConsumerStatefulWidget {
  final List<File> supportingImages;
  final String audioPath;
  final String reportType;
  final Map<String, dynamic>? aiAnalysisResult;
  final String appLocation;

  const VolunteerAIGeneratedReportScreen({
    super.key,
    required this.supportingImages,
    required this.audioPath,
    this.reportType = 'voice',
    this.aiAnalysisResult,
    required this.appLocation,
  });

  @override
  ConsumerState<VolunteerAIGeneratedReportScreen> createState() => _VolunteerAIGeneratedReportScreenState();
}

class _VolunteerAIGeneratedReportScreenState extends ConsumerState<VolunteerAIGeneratedReportScreen> {
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
    _titleController = TextEditingController(text: _getTranslatedText('incidentType').isNotEmpty ? _getTranslatedText('incidentType') : 'Report');
    _impactController = TextEditingController(text: aiData['estimatedAffected']?.toString() ?? '0');
    _summaryController = TextEditingController(text: _getTranslatedText('summary'));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _impactController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    // If they are in edit mode when they tap submit, just submit the edited values
    setState(() {
      _isEditing = false;
      _isSubmitting = true;
    });
    
    try {
      final volunteer = ref.read(currentVolunteerProvider).asData?.value;
      if (volunteer == null) throw Exception('User not logged in');

      final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
      final audioUrl = widget.aiAnalysisResult?['audioUrl'] as String? ?? 'mock_audio_url';
      final uploadedImages = widget.aiAnalysisResult?['uploadedImages'] as List<Map<String, dynamic>>? ?? [];

      // Create dummy report with user-edited data directly to Firestore
      final report = GroundReportModel(
        reportId: '', // Will be assigned by repo
        missionId: volunteer.currentMissionId ?? '',
        ngoId: volunteer.ngoId,
        volunteerId: volunteer.uid,
        volunteerName: volunteer.displayName,
        reportType: widget.reportType,
        audioUrl: audioUrl, 
        transcript: aiData['summary'] ?? '',
        supportingImages: uploadedImages,
        location: {
          'latitude': 0.0, 
          'longitude': 0.0, 
          'address': widget.appLocation
        },
        aiAnalysis: {
          'summary': _summaryController.text.trim(),
          'urgency': aiData['severity'] ?? 'medium',
          'estimatedImpact': int.tryParse(_impactController.text.trim()) ?? 0,
          'suggestedResources': aiData['requiredResources'] ?? [],
          'crisisType': aiData['recommendedCategory'] ?? 'other',
          'confidenceScore': aiData['confidenceScore'] ?? 90,
          'detectedRisks': aiData['detectedRisks'] ?? [],
          'recommendedActions': aiData['recommendedActions'] ?? [],
        },
        status: 'submitted',
        missionStatusAtReportTime: 'active',
        urgencyAtReportTime: aiData['severity'] ?? 'high',
      );

      await ref.read(groundReportRepositoryProvider).createReport(report);
      await ref.read(volunteerServiceProvider).incrementReportsSubmitted(volunteer.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reports Report Submitted.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        // Navigate back to the very first route (Report Tab / Hub)
        Navigator.of(context).popUntil((route) => route.isFirst);
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
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    final bool evidenceMatched = aiData['evidenceMatched'] == true;
    final String evidenceReason = _getTranslatedText('evidenceReason');

    if (evidenceMatched) {
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
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Text('Matched Evidence', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF16A34A), fontSize: 14)),
                      const SizedBox(width: 4),
                      Icon(_isEvidenceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF16A34A), size: 16),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Powered by Gemma', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF15803D))),
                  ),
                ],
              ),
              if (_isEvidenceExpanded) ...[
                const SizedBox(height: 12),
                Text(evidenceReason.isNotEmpty ? evidenceReason : 'Voice observations align with uploaded evidence perfectly.', style: GoogleFonts.inter(color: const Color(0xFF15803D), fontSize: 13, height: 1.4)),
              ],
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => setState(() => _isEvidenceExpanded = !_isEvidenceExpanded),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Text('Evidence Mismatch', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFFDC2626), fontSize: 14)),
                      const SizedBox(width: 4),
                      Icon(_isEvidenceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFDC2626), size: 16),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Powered by Gemma', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                  ),
                ],
              ),
              if (_isEvidenceExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  'Inconsistent evidence detected:\n${evidenceReason.isNotEmpty ? evidenceReason : 'Uploaded evidence is entirely irrelevant to the voice observation. Please review.'}',
                  style: GoogleFonts.inter(color: const Color(0xFFB91C1C), fontSize: 13, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTopSection() {
    final aiData = widget.aiAnalysisResult?['aiData'] as Map<String, dynamic>? ?? {};
    final severity = (aiData['severity']?.toString() ?? 'medium').toLowerCase();
    
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
        Row(
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
                    'AI Generated',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supporting Evidence',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.supportingImages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
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
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.image_not_supported_rounded, size: 32, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 8),
                  Text(
                    'No Supporting Evidence Attached',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.supportingImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.9),
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: Image.file(
                                  widget.supportingImages[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                top: 40,
                                right: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(widget.supportingImages[index]),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_out_map_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
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
