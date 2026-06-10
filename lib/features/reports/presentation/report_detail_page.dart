import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../insights/presentation/smart_allocation_center_page.dart';

class ReportDetailsPage extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const ReportDetailsPage({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _geminiKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToGemini() {
    final context = _geminiKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return const Color(0xFFEF4444);
      case 'fire':
        return const Color(0xFFF97316);
      case 'police':
        return const Color(0xFF3B82F6);
      case 'accident':
        return const Color(0xFFF59E0B);
      case 'infrastructure':
        return const Color(0xFF14B8A6);
      case 'natural_disaster':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return Icons.medical_services_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'police':
        return Icons.local_police_rounded;
      case 'accident':
        return Icons.car_crash_rounded;
      case 'infrastructure':
        return Icons.construction_rounded;
      case 'natural_disaster':
        return Icons.thunderstorm_rounded;
      default:
        return Icons.report_problem_rounded;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return 'Medical Support';
      case 'fire':
        return 'Fire Emergency';
      case 'police':
        return 'Police/Security';
      case 'accident':
        return 'Road Accident';
      case 'infrastructure':
        return 'Infrastructure';
      case 'natural_disaster':
        return 'Natural Disaster';
      default:
        return 'General Incident';
    }
  }

  String _getRecommendedAction(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return '• Deploy primary trauma response unit.\n• Setup emergency triage center at designated safe coordinates.\n• Contact closest medical facility for patient intake readiness.\n• Deploy active oxygen supply and medical kits.';
      case 'fire':
        return '• Dispatch primary fire containment team.\n• Establish evacuation corridor for adjacent structures.\n• Alert water utility grid for high-pressure emergency support.\n• Check for structural compromise after containment.';
      case 'police':
        return '• Dispatch police units to secure the perimeter.\n• Restrict vehicular access to prevent gridlock.\n• Establish communications link with county dispatch.\n• Deploy surveillance drones for aerial oversight.';
      case 'accident':
        return '• Coordinate with traffic services to cordon the area.\n• Alert ambulance dispatcher for immediate trauma response.\n• Secure the crash debris to prevent secondary hazards.\n• Route oncoming traffic through alternative detours.';
      case 'infrastructure':
        return '• Deploy engineering assessment team.\n• Cordon off structural hazard zones to civilian access.\n• Notify utility provider for gas, water, or electrical shutoffs.\n• Formulate stabilization and repair roadmap.';
      case 'natural_disaster':
        return '• Establish temporary emergency shelter grid.\n• Distribute emergency nutrition, clean water, and thermal blankets.\n• Initiate search-and-rescue protocols in high-risk zones.\n• Sync satellite telemetry with provincial crisis command.';
      default:
        return '• Deploy local responder check-in team.\n• Gather field photographs and update damage assessment log.\n• Liaise with neighborhood crisis liaison.\n• Stand by for automated resource allocation.';
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
      final lat = _toDouble(
        coordinatesRaw['latitude'] ?? coordinatesRaw['lat'],
      );
      final lng = _toDouble(
        coordinatesRaw['longitude'] ?? coordinatesRaw['lng'],
      );
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

  String? _resolveImageUrl() {
    final candidates = [
      widget.reportData['image_url'],
      widget.reportData['imageUrl'],
      widget.reportData['secure_url'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  Future<void> _launchMaps(String coordinateText) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(coordinateText)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openAttachment(
    Map<String, dynamic> docMap,
    String reportImageUrl,
  ) async {
    final fileName = docMap['fileName']?.toString() ?? 'unknown_file';
    final fileUrl =
        docMap['fileUrl']?.toString() ??
        docMap['secureUrl']?.toString() ??
        docMap['secure_url']?.toString() ??
        docMap['url']?.toString() ??
        '';
    final base64Data = docMap['base64Data']?.toString() ?? '';
    final fileType =
        docMap['fileType']?.toString() ?? 'application/octet-stream';
    final isImage =
        fileType.startsWith('image/') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg');
    final isPdf =
        fileType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');

    if (isImage) {
      final imgUrl = fileUrl.isNotEmpty ? fileUrl : reportImageUrl;
      if (imgUrl.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ReportImageViewerPage(
              imageUrl: imgUrl,
              heroTag: 'report-image-${widget.reportId}',
            ),
          ),
        );
      } else if (base64Data.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            final imageBytes = base64Decode(base64Data);
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        color: Colors.black,
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4,
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image data is unavailable')),
        );
      }
      return;
    }

    if (fileUrl.isNotEmpty) {
      final uri = Uri.tryParse(fileUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (base64Data.isNotEmpty) {
      try {
        if (kIsWeb) {
          final ext = fileName.split('.').last.toLowerCase();
          String mimeType = 'application/octet-stream';
          if (ext == 'pdf') mimeType = 'application/pdf';
          else if (ext == 'png') mimeType = 'image/png';
          else if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
          else if (ext == 'txt') mimeType = 'text/plain';

          final uri = Uri.parse('data:$mimeType;base64,$base64Data');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            throw Exception('Unable to open attachment preview on browser.');
          }
          return;
        }

        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}${Platform.pathSeparator}$fileName',
        );
        await file.writeAsBytes(base64Decode(base64Data), flush: true);
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open attachment: $e')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachment content is unavailable.')),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color badgeColor;
    final String label;

    switch (status.toLowerCase()) {
      case 'open':
      case 'pending':
        badgeColor = const Color(0xFF2563EB); // blue
        label = 'Pending Dispatch';
        break;
      case 'in progress':
      case 'assigned':
        badgeColor = const Color(0xFFD97706); // orange
        label = 'Assigned';
        break;
      case 'resolved':
      case 'closed':
      case 'completed':
        badgeColor = const Color(0xFF10B981); // green
        label = 'Completed';
        break;
      default:
        badgeColor = const Color(0xFF64748B); // grey
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    final Color color;
    switch (urgency.toLowerCase()) {
      case 'critical':
      case 'high':
        color = const Color(0xFFDC2626);
        break;
      case 'medium':
        color = const Color(0xFFD97706);
        break;
      default:
        color = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${urgency.toUpperCase()} URGENCY',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildParameterRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportingDocsSection(Map<String, dynamic> reportData) {
    final docs = reportData['supportingDocsMetadata'] as List<dynamic>?;
    final imageUrl = _resolveImageUrl();

    if ((docs == null || docs.isEmpty) &&
        (imageUrl == null || imageUrl.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<Widget> children = [];

    if (imageUrl != null && imageUrl.isNotEmpty) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supporting Asset (Image)',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ReportImageViewerPage(
                      imageUrl: imageUrl,
                      heroTag: 'report-image-${widget.reportId}',
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'report-image-${widget.reportId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Color(0xFF94A3B8),
                            size: 48,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    if (docs != null && docs.isNotEmpty) {
      for (final doc in docs) {
        if (doc is! Map<String, dynamic>) continue;
        final fileName = doc['fileName']?.toString() ?? 'unknown_file';
        final byteSize = doc['fileSizeBytes'] as int? ?? 0;
        final fileType =
            doc['fileType']?.toString() ?? 'application/octet-stream';
        final isImage = fileType.startsWith('image/');
        final isPdf =
            fileType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
        final sizeStr = byteSize > 0
            ? '${(byteSize / 1024).toStringAsFixed(1)} KB'
            : 'Unknown size';

        children.add(
          InkWell(
            onTap: () => _openAttachment(doc, imageUrl ?? ''),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          (isImage
                                  ? Colors.blue
                                  : (isPdf ? Colors.red : Colors.indigo))
                              .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isImage
                          ? Icons.image_rounded
                          : (isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.description_rounded),
                      color: isImage
                          ? Colors.blue
                          : (isPdf ? Colors.red : Colors.indigo),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$sizeStr • ${isImage ? 'Image' : (isPdf ? 'PDF Document' : 'Document')}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFF94A3B8),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 12));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'SUPPORTING ASSETS',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reportId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid Report ID.')),
      );
    }

    final reportData = widget.reportData;
    final category = reportData['category']?.toString() ?? 'other';
    final accentColor = _getCategoryColor(category);
    final status = reportData['status']?.toString() ?? 'open';
    final urgency = reportData['urgency']?.toString() ?? 'low';
    final urgencyScore = reportData['urgency_score'] is num
        ? (reportData['urgency_score'] as num).toDouble()
        : 3.0;

    final createdTs =
        reportData['createdAt'] as Timestamp? ??
        reportData['timestamp'] as Timestamp?;
    final createdDate = createdTs?.toDate() ?? DateTime.now();

    final hasAiSummary =
        reportData.containsKey('ai_summary') &&
        reportData['ai_summary'].toString().trim().isNotEmpty;
    final aiSummary = hasAiSummary
        ? reportData['ai_summary'].toString()
        : reportData['description']?.toString() ?? 'No AI summary generated.';

    final latLng = _extractLatLng(reportData);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Allocare Intelligence',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getCategoryIcon(category), color: accentColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  _getCategoryLabel(category).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & Urgency Banner Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _buildStatusBadge(status),
                  const SizedBox(width: 8),
                  _buildUrgencyBadge(urgency),
                  const Spacer(),
                  Text(
                    'Score: ${urgencyScore.toStringAsFixed(1)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Incident Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reportData['title']?.toString() ?? 'Untitled Incident',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reportData['description']?.toString() ??
                            'No description provided.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                      const Divider(height: 32, color: Color(0xFFF1F5F9)),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                reportData['reportedBy'] == null ||
                                        reportData['reportedBy']
                                            .toString()
                                            .trim()
                                            .isEmpty
                                    ? Text(
                                        'Allocare Operator',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      )
                                    : FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(
                                              reportData['reportedBy']
                                                  .toString(),
                                            )
                                            .get(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data!.exists) {
                                            final uData =
                                                snapshot.data!.data()
                                                    as Map<String, dynamic>?;
                                            final uName =
                                                uData?['displayName']
                                                    ?.toString() ??
                                                '';
                                            return Text(
                                              uName.isNotEmpty
                                                  ? uName
                                                  : 'Commander',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            );
                                          }
                                          return Text(
                                            'Allocare Operator',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          );
                                        },
                                      ),
                                Text(
                                  'Uploaded Report Creator',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${createdDate.day}/${createdDate.month}/${createdDate.year}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              Text(
                                '${createdDate.hour.toString().padLeft(2, '0')}:${createdDate.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tactical Parameters Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF0F172A),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TACTICAL PARAMETERS',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Location field
                      _buildParameterRow(
                        icon: Icons.location_on_rounded,
                        iconColor: accentColor,
                        title: 'Location',
                        subtitle:
                            reportData['location']?.toString() ??
                            'Not specified',
                      ),
                      const SizedBox(height: 16),

                      // Coordinates field
                      _buildParameterRow(
                        icon: Icons.map_rounded,
                        iconColor: Colors.blueGrey,
                        title: 'Coordinates',
                        subtitle: latLng != null
                            ? '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}'
                            : 'Unavailable',
                      ),
                      const SizedBox(height: 16),

                      // People Affected field
                      _buildParameterRow(
                        icon: Icons.people_outline_rounded,
                        iconColor: const Color(0xFF0EA5E9),
                        title: 'People Affected',
                        subtitle: reportData['peopleAffected'] != null
                            ? '${reportData['peopleAffected']} individuals'
                            : 'Unknown',
                      ),
                      const SizedBox(height: 16),

                      // Supporting Documents
                      _buildSupportingDocsSection(reportData),
                    ],
                  ),
                ),
              ),
            ),

            // Gemini Intelligence Section
            Padding(
              key: _geminiKey,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF38BDF8,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.psychology_alt_rounded,
                              color: Color(0xFF38BDF8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GEMINI COGNITIVE ASSESSMENT',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF38BDF8),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'AlloCare Live Intelligence',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Extracted Summary
                      Text(
                        'AI SUMMARY',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        aiSummary,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFFE2E8F0),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Crisis Type
                      Text(
                        'CLASSIFIED CRISIS TYPE',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            color: const Color(0xFF38BDF8),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            reportData['crisis_type']?.toString() ??
                                _getCategoryLabel(category),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Recommended Action
                      Text(
                        'TACTICAL RECOMMENDATIONS',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getRecommendedAction(category),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFCBD5E1),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status of generated Needs/Assigned Responder
                      const Divider(color: Color(0xFF334155)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            reportData['assigned_volunteer_id'] != null ||
                                    reportData['assigned_volunteer_name'] !=
                                        null
                                ? Icons.check_circle_rounded
                                : Icons.published_with_changes_rounded,
                            color:
                                reportData['assigned_volunteer_id'] != null ||
                                    reportData['assigned_volunteer_name'] !=
                                        null
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFBBF24),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reportData['assigned_volunteer_id'] != null ||
                                      reportData['assigned_volunteer_name'] !=
                                          null
                                  ? 'Dispatched to responder: ${reportData['assigned_volunteer_name']}'
                                  : 'Need Generated - Awaiting dispatch',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Volunteer Information Card (when assigned)
                      if (reportData['assigned_volunteer_id'] != null ||
                          reportData['assigned_volunteer_name'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ASSIGNED RESPONDER PROFILE',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          reportData['assigned_volunteer_name']
                                                  ?.toString() ??
                                              'Unknown Volunteer',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          reportData['assigned_volunteer_speciality']
                                                  ?.toString() ??
                                              'Specialist',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (reportData['assigned_volunteer_contact'] !=
                                      null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone_rounded,
                                        color: Color(0xFF4ADE80),
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        final phone =
                                            reportData['assigned_volunteer_contact']
                                                .toString();
                                        final uri = Uri.parse('tel:$phone');
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Sticky actions footer
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (latLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Location unavailable for this report'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                    return;
                  }
                  _launchMaps('${latLng.latitude},${latLng.longitude}');
                },
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text('Navigate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _scrollToGemini,
                icon: const Icon(Icons.analytics_rounded, size: 16),
                label: const Text('Intelligence'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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

class _ReportImageViewerPage extends StatelessWidget {
  const _ReportImageViewerPage({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
