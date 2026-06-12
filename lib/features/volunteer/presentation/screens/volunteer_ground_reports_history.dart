import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/auth_service.dart';

class VolunteerGroundReportsHistoryPage extends ConsumerStatefulWidget {
  const VolunteerGroundReportsHistoryPage({super.key});

  @override
  ConsumerState<VolunteerGroundReportsHistoryPage> createState() => _VolunteerGroundReportsHistoryPageState();
}

class _VolunteerGroundReportsHistoryPageState extends ConsumerState<VolunteerGroundReportsHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).asData?.value;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ground Reports')),
        body: const Center(child: Text('User not found')),
      );
    }

    final volunteerId = currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFDFE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ground Reports',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Your submitted field intelligence',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('ground_reports')
            .where('volunteerId', isEqualTo: volunteerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
          }

          var docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          // Sort locally to avoid requiring a composite index in Firestore
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = aData['createdAt'] as Timestamp?;
            final bTs = bData['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildReportCard(context, doc);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Reports Submitted',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture field evidence using Voice Report or Photo Report tools.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reportType = data['reportType']?.toString() ?? 'unknown';
    
    final aiAnalysis = data['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final title = aiAnalysis['crisisType']?.toString().toUpperCase() ?? 'Field Intelligence';
    final category = aiAnalysis['crisisType']?.toString() ?? 'General';
    final severity = aiAnalysis['urgency']?.toString() ?? 'Moderate';
    
    final status = data['status']?.toString() ?? 'Pending';
    
    final locData = data['location'] as Map<String, dynamic>?;
    final location = locData != null ? locData['address']?.toString() ?? 'Unknown Location' : 'Unknown Location';
    
    final ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
        : 'Unknown Date';

    IconData typeIcon = Icons.article_rounded;
    Color typeColor = const Color(0xFF64748B);
    String typeLabel = 'Structured';
    
    if (reportType.contains('voice')) {
      typeIcon = Icons.mic_rounded;
      typeColor = const Color(0xFF8B5CF6);
      typeLabel = 'Voice Report';
    } else if (reportType.contains('photo')) {
      typeIcon = Icons.camera_alt_rounded;
      typeColor = const Color(0xFF0EA5E9);
      typeLabel = 'Photo Report';
    }

    Color severityColor = const Color(0xFFF59E0B);
    if (severity.toLowerCase() == 'critical' || severity.toLowerCase() == 'high') {
      severityColor = const Color(0xFFEF4444);
    } else if (severity.toLowerCase() == 'low') {
      severityColor = const Color(0xFF10B981);
    }

    Color statusColor = const Color(0xFF94A3B8);
    IconData statusIcon = Icons.pending_rounded;
    if (status.toLowerCase() == 'verified') {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
    } else if (status.toLowerCase() == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _showReportDetails(context, data);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, size: 16, color: typeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            typeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Middle Row: Category & Severity
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded, size: 10, color: severityColor),
                          const SizedBox(width: 4),
                          Text(
                            severity.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: severityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),

                // Bottom Row: Date & Location
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 13, color: const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time_rounded, size: 13, color: const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
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
      ),
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailSheet(data: data),
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportDetailSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final aiAnalysis = data['aiAnalysis'] as Map<String, dynamic>? ?? {};
    final title = aiAnalysis['crisisType']?.toString().toUpperCase() ?? 'Field Intelligence';
    final summary = aiAnalysis['summary']?.toString() ?? data['transcript']?.toString() ?? 'No details provided.';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      summary,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF334155),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (data['supportingImages'] != null || (data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty))
                    _buildEvidenceSection(context, data),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection(BuildContext context, Map<String, dynamic> data) {
    List<String> urls = [];
    final imagesList = data['supportingImages'] as List<dynamic>?;
    if (imagesList != null) {
      for (var img in imagesList) {
        if (img is Map<String, dynamic> && img['url'] != null) {
          urls.add(img['url'].toString());
        }
      }
    }

    final audioUrl = data['audioUrl']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence Provided',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (audioUrl != null && audioUrl.isNotEmpty && audioUrl != 'mock_audio_url')
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Color(0xFF8B5CF6)),
              ),
              title: Text(
                'Voice Report Recording',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
              subtitle: Text(
                'Tap to listen to the audio report',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF8B5CF6), size: 28),
              onTap: () async {
                final uri = Uri.parse(audioUrl);
                try {
                  // Try opening in a native media player app first
                  final launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                  if (!launched) {
                    // Fallback to standard external application (e.g. browser)
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('Error launching audio: $e');
                  // Fallback if the first intent entirely fails
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
            ),
          ),
        if (urls.isNotEmpty)
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              itemBuilder: (context, index) {
                final isNetwork = urls[index].startsWith('http') || urls[index].startsWith('https');
                final provider = isNetwork 
                    ? NetworkImage(urls[index]) as ImageProvider 
                    : FileImage(File(urls[index]));
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.9),
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: EdgeInsets.zero,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              child: Image(image: provider, fit: BoxFit.contain),
                            ),
                            Positioned(
                              top: 40,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: provider,
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_out_map_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
