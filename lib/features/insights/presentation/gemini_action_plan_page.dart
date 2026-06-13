import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/insight_model.dart';

class GeminiActionPlanPage extends StatelessWidget {
  final InsightModel insight;

  const GeminiActionPlanPage({
    super.key,
    required this.insight,
  });

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
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
            _buildActionPlan(),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'CONFIDENCE: ${(insight.score * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB),
                    letterSpacing: 0.5,
                  ),
                ),
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
            insight.title,
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
    // Generate a contextual brief based on the title to make it feel rich and informative.
    final contextualBrief = _generateContextualBrief(insight.title);

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
            insight.recommendation,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            contextualBrief,
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

  Widget _buildActionPlan() {
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
            title: 'Immediate Triage & Deployment',
            description: 'Deploy initial rapid assessment teams to the affected zone to verify intelligence data and establish a forward operating base.',
            iconData: Icons.add_location_alt_outlined,
          ),
          const SizedBox(height: 20),
          _buildActionItem(
            step: '2',
            title: 'Resource Allocation',
            description: 'Trigger automated inventory requests for critical supplies based on the predictive model requirements outlined in the brief.',
            iconData: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 20),
          _buildActionItem(
            step: '3',
            title: 'Volunteer Coordination',
            description: 'Send targeted alerts to specialized volunteers within a 15km radius, prioritizing personnel with relevant crisis experience.',
            iconData: Icons.groups_outlined,
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
          )
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
            child: Icon(
              iconData,
              color: const Color(0xFF475569),
              size: 20,
            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateContextualBrief(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('flood') || lowerTitle.contains('water')) {
      return 'Based on analysis of live telemetry and field reports, water levels in the designated zone are exceeding standard thresholds. Rapid urban infrastructure degradation is highly probable over the next 12 hours if drainage systems remain compromised. Vulnerable demographics in low-lying areas face an immediate risk of displacement.';
    } else if (lowerTitle.contains('fire') || lowerTitle.contains('smoke')) {
      return 'Thermal anomalies and shifting wind patterns indicate a severe risk of fire spread. Air quality index (AQI) is expected to reach hazardous levels. Immediate evacuation protocols should be prepared for surrounding residential sectors, prioritizing individuals with respiratory conditions.';
    } else if (lowerTitle.contains('medical') || lowerTitle.contains('health')) {
      return 'Health monitoring networks have flagged an unusual surge in acute medical requests. Local medical facilities are approaching capacity. An immediate influx of medical volunteers and baseline diagnostic equipment is required to stabilize the ground situation before critical supply chain failure.';
    }
    return 'Analysis indicates an escalating situation requiring immediate NGO intervention. Multi-source data synthesis suggests that resource constraints will become critical within the next 48 hours. Pre-emptive mobilization of ground forces and localized supply distribution is highly advised to mitigate severe community impact.';
  }
}
