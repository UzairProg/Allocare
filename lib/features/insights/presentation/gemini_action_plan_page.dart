import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/insight_model.dart';

class GeminiActionPlanPage extends StatelessWidget {
  final InsightModel insight;

  const GeminiActionPlanPage({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF2563EB),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Gemini Intelligence',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () async {
                try {
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File('${dir.path}/Gemini_Intelligence_Brief.txt');
                  
                  final content = '''
GEMINI INTELLIGENCE BRIEF
=========================
Title: ${insight.title}
Confidence Score: ${(insight.score * 100).toStringAsFixed(0)}%

RECOMMENDATION:
${insight.recommendation}

Please deploy resources accordingly.
                  ''';
                  
                  await file.writeAsString(content);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Brief Exported! Opening document...'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  
                  await OpenFilex.open(file.path);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error exporting: $e'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(
                Icons.download_rounded,
                size: 16,
                color: Color(0xFF2563EB),
              ),
              label: Text(
                'Export Docs',
                style: GoogleFonts.inter(
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportHeader(),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSituationBrief(),
            _buildDataSynthesis(),
            _buildActionPlan(context),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                // child: Text(
                //   'CONFIDENCE: ${(insight.score * 100).toStringAsFixed(0)}%',
                //   style: GoogleFonts.inter(
                //     fontSize: 10,
                //     fontWeight: FontWeight.bold,
                //     color: const Color(0xFF2563EB),
                //     letterSpacing: 0.5,
                //   ),
                // ),
              ),
              const SizedBox(width: 12),
              Text(
                'Generated Just Now',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Resource Shortage Risk (Underserved Areas Detected)',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSituationBrief() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Situation Brief',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Volunteer deployments have stabilized critical flood zones; however, incoming field reports indicate rising demand in surrounding localities.\n\nAnalysis suggests that existing resources may become insufficient if incident volume continues to increase over the next several hours.\n\nEarly intervention is recommended to prevent delays in response coverage.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF334155),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSynthesis() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.hub_outlined,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Data Synthesis & Conclusion',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSynthesisRow(
                  'Primary Data Sources',
                  '• Flood Incident Report\n• 47 Verified Community Reports\n• 11 Volunteer Ground Updates\n• Weather Intelligence Signals\n• Historical Flood Patterns',
                ),
                const SizedBox(height: 12),
                _buildSynthesisRow(
                  'Verification Status',
                  'Cross-referenced through volunteer reports, NGO assessments, weather intelligence, and historical response data.',
                ),
                const SizedBox(height: 12),
                _buildSynthesisRow(
                  'Conclusion',
                  'Several flood-affected sectors are approaching operational capacity limits.\n\nWithout reinforcement, response delays and localized supply shortages may emerge within the next 12 hours.',
                  isHighlight: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynthesisRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
              color: isHighlight
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionPlan(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Actionable Plan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionItem(
            step: '1',
            title: 'Immediate Deployment',
            description:
                'Dispatch 8 additional volunteers to sectors showing increasing community reports and delayed response times.',
            iconData: Icons.add_location_alt_outlined,
          ),
          const SizedBox(height: 20),
          _buildActionItem(
            step: '2',
            title: 'Resource Allocation',
            description:
                'Pre-position drinking water, first-aid kits, and emergency shelter materials near affected localities.',
            iconData: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 20),
          _buildActionItem(
            step: '3',
            title: 'Volunteer Coordination',
            description:
                'Notify trained volunteers within a 15 km radius and activate standby response personnel.',
            iconData: Icons.groups_outlined,
            actionWidget: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No active volunteers near that location!'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.campaign_rounded, size: 16),
                label: Text(
                  'Notify Volunteers / Raise Need',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String step,
    required String title,
    required String description,
    required IconData iconData,
    Widget? actionWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: const Color(0xFF475569), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
                if (actionWidget != null) ...[
                  const SizedBox(height: 16),
                  actionWidget,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
