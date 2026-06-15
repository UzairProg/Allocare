import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void showVerifiedNgosBottomSheet(BuildContext context) {
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
        foregroundColor: isPrimary ? Colors.white : color,
        backgroundColor: isPrimary ? color : color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
