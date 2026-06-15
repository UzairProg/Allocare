import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../map/presentation/map_screen.dart';

class SentinelStrategicHubPage extends StatefulWidget {
  const SentinelStrategicHubPage({super.key});

  @override
  State<SentinelStrategicHubPage> createState() =>
      _SentinelStrategicHubPageState();
}

class _SentinelStrategicHubPageState extends State<SentinelStrategicHubPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _sheetAnimationController;

  @override
  void initState() {
    super.initState();
    // 1.0 = fully hidden at the bottom, 0.05 = fully expanded leaving 5% top margin
    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _sheetAnimationController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    double delta = details.primaryDelta! / MediaQuery.of(context).size.height;
    _sheetAnimationController.value += delta;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! < -300) {
      _sheetAnimationController.animateTo(0.02, curve: Curves.easeOutCubic);
    } else if (details.primaryVelocity! > 300) {
      _sheetAnimationController.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      if (_sheetAnimationController.value < 0.6) {
        _sheetAnimationController.animateTo(0.02, curve: Curves.easeOutCubic);
      } else {
        _sheetAnimationController.animateTo(1.0, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _sheetAnimationController,
          builder: (context, child) {
            double pos = _sheetAnimationController.value.clamp(0.02, 1.0);
            double progress = 1.0 - pos; 
            
            double backgroundScale = 1.0 - (0.06 * progress); // Shrinks to 94%
            double blur = 12.0 * progress;
            double dim = 0.5 * progress;

            return Stack(
              children: [
                // 1. MAIN BACKGROUND
                Transform.scale(
                  scale: backgroundScale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(progress * 32),
                    child: Container(
                      color: const Color(0xFFF8F9FA),
                      child: Column(
                        children: [
                          SafeArea(
                            bottom: false,
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              child: const Text(
                                'Community Intelligence',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildMainIntelligenceScreen(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. DIM / BLUR OVERLAY
                if (progress > 0)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: Container(
                        color: const Color(0xFF0F172A).withOpacity(dim),
                      ),
                    ),
                  ),

                // 3. THE RISK BRIEFINGS SHEET
                Positioned(
                  top: MediaQuery.of(context).size.height * pos,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.98, // 98% screen height
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), // Pure white background for the sheet
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3 * progress),
                          blurRadius: 40,
                          spreadRadius: 0,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Grab Handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 4),
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Briefing Deck inside Sheet
                        const Expanded(
                          child: _RiskBriefingsDeck(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainIntelligenceScreen() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(), // Let GestureDetector capture all vertical swipes
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 4),
            const _ContinuousDataSynthesisCoreV4(),
            const SizedBox(height: 8),
            const Text(
              'Monitoring community and environmental signals to identify emerging risks & turn it into actionable intelligence.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'COMMUNITY INTELLIGENCE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                          ),
                          SizedBox(height: 12),
                          _VerifiedSourceItem(
                            'Volunteer Reports',
                            tooltip: 'Volunteer ground reports help us understand the situation more. The real-time feedback loop continues!',
                          ),
                          _VerifiedSourceItem('NGO Reports'),
                          _VerifiedSourceItem('Community Reports'),
                        ],
                      ),
                    ),
                    const VerticalDivider(color: Color(0xFFE2E8F0), width: 24, thickness: 1.5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'VERIFIED PUBLIC SIGNALS',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                          ),
                          SizedBox(height: 12),
                          _VerifiedSourceItem(
                            'Google Weather',
                            tooltip: 'Climate data helps predict major events (droughts, floods, storms) before they escalate.',
                          ),
                          _VerifiedSourceItem(
                            'Government Alerts',
                            tooltip: 'Official advisories provide a highly trusted baseline for predictive hazard warnings.',
                          ),
                          _VerifiedSourceItem(
                            'Historical Trends',
                            tooltip: 'Analysis of past incidents reveals patterns to forecast upcoming resource demands.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('How AlloCare Works', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  SizedBox(height: 8),
                  Text(
                    'AlloCare combines community reports, weather intelligence, government alerts, and historical patterns to identify risks before they escalate and recommend proactive response actions.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _AnimatedBottomCTA(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// COMPONENT: Risk Briefings Deck
// ---------------------------------------------------------
class _RiskBriefingsDeck extends StatefulWidget {
  const _RiskBriefingsDeck();

  @override
  State<_RiskBriefingsDeck> createState() => _RiskBriefingsDeckState();
}

class _RiskBriefingsDeckState extends State<_RiskBriefingsDeck> {
  final PageController _pageController = PageController(viewportFraction: 0.95);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: const [
              _RiskBriefingCardContent(
                insightId: 'insight_resource_shortage_001',
                isPrimary: true,
                badge: 'PRIMARY AI INSIGHT',
                title: 'Resource Shortage Risk Detected',
                location: 'Aurangabad, Maharashtra',
                updatedAt: 'Updated 10:45 AM • 14 June 2026',
                mapCategory: MapLayerCategory.naturalDisaster,
                alertExplanation: 'Ongoing flood response operations are increasing demand for volunteers and emergency supplies across affected sectors.',
                impactNumber: '4,100+',
                impactDescription: 'Residents',
                radiusNumber: '3.1 km',
                radiusDescription: 'Radius',
                whyAlertRows: [
                  {'icon': Icons.warning_amber_rounded, 'label': 'Active Flood Sectors', 'value': '3', 'subValue': 'Relief Zones'},
                  {'icon': Icons.groups_rounded, 'label': 'Volunteer Availability', 'value': '68%', 'subValue': 'Remaining'},
                  {'icon': Icons.fact_check_rounded, 'label': 'Community Reports', 'value': '47', 'subValue': 'Verified'},
                  {'icon': Icons.inventory_2_rounded, 'label': 'Resource Utilization', 'value': '86%', 'subValue': 'Allocated'},
                ],
                immediateAction: 'Deploy additional volunteers to high-demand sectors',
                next4HoursAction: 'Mobilize emergency supplies and medical kits',
                preparednessAction: 'Activate reserve volunteer network',
              ),
              _RiskBriefingCardContent(
                insightId: 'insight_scarcity_001',
                isPrimary: false,
                badge: 'WATER SCARCITY',
                title: 'Water Scarcity Warning',
                location: 'Beed Bypass Region',
                updatedAt: 'Updated 10:15 AM • 13 June 2026',
                mapCategory: MapLayerCategory.waterborne,
                alertExplanation: 'Low reservoir levels and high consumption rates indicate potential water shortage in 3-5 days.',
                impactNumber: '8,200',
                impactDescription: 'Residents',
                radiusNumber: '12 km',
                radiusDescription: 'Radius',
                whyAlertRows: [
                  {'icon': Icons.thermostat_outlined, 'label': 'Temperature', 'value': '42°C', 'subValue': '(Last 24 hrs)'},
                  {'icon': Icons.water_drop_outlined, 'label': 'Reservoir Level', 'value': '-15%', 'subValue': '(Past 3 days)'},
                  {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Community Reports', 'value': '42', 'subValue': 'Verified'},
                  {'icon': Icons.bar_chart_rounded, 'label': 'Risk Zone Match', 'value': '76%', 'subValue': 'Historical Match'},
                ],
                immediateAction: 'Implement water rationing',
                next4HoursAction: 'Activate supply tanks',
                preparednessAction: 'Monitor groundwater',
              ),
              _RiskBriefingCardContent(
                insightId: 'insight_airborne_001',
                isPrimary: false,
                badge: 'AIRBORNE DISEASE',
                title: 'Respiratory Illness Trend',
                location: 'Waluj Industrial Area',
                updatedAt: 'Updated 11:30 AM • 12 June 2026',
                mapCategory: MapLayerCategory.airborne,
                alertExplanation: 'Spike in respiratory distress reports correlating with sudden drop in air quality index.',
                impactNumber: '1,200',
                impactDescription: 'Workers',
                radiusNumber: '5.5 km',
                radiusDescription: 'Radius',
                whyAlertRows: [
                  {'icon': Icons.air_outlined, 'label': 'AQI Level', 'value': '340', 'subValue': '(Last 12 hrs)'},
                  {'icon': Icons.local_hospital_outlined, 'label': 'Clinic Admissions', 'value': '+24%', 'subValue': '(Past 24 hrs)'},
                  {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Community Reports', 'value': '18', 'subValue': 'Verified'},
                  {'icon': Icons.compare_arrows_rounded, 'label': 'Wind Shift', 'value': 'NW', 'subValue': '15km/h'},
                ],
                immediateAction: 'Distribute N95 masks',
                next4HoursAction: 'Alert respiratory clinics',
                preparednessAction: 'Issue indoors advisory',
              ),
            ],
          ),
        ),
        
        // Pagination (Below CTA)
        Padding(
          padding: const EdgeInsets.only(bottom: 24, top: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 6 : 4,
                    height: _currentPage == index ? 6 : 4,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// COMPONENT: Final No-Scroll Premium Briefing Card
// ---------------------------------------------------------
class _RiskBriefingCardContent extends StatefulWidget {
  final String insightId;
  final bool isPrimary;
  final String badge;
  final String title;
  final String location;
  final String updatedAt;
  final String alertExplanation;
  final String impactNumber;
  final String impactDescription;
  final String radiusNumber;
  final String radiusDescription;
  final List<Map<String, dynamic>> whyAlertRows;
  final String immediateAction;
  final String next4HoursAction;
  final String preparednessAction;
  final MapLayerCategory mapCategory;

  const _RiskBriefingCardContent({
    required this.insightId,
    required this.isPrimary,
    required this.badge,
    required this.title,
    required this.location,
    required this.updatedAt,
    required this.alertExplanation,
    required this.impactNumber,
    required this.impactDescription,
    required this.radiusNumber,
    required this.radiusDescription,
    required this.whyAlertRows,
    required this.immediateAction,
    required this.next4HoursAction,
    required this.preparednessAction,
    required this.mapCategory,
  });

  @override
  State<_RiskBriefingCardContent> createState() => _RiskBriefingCardContentState();
}

class _RiskBriefingCardContentState extends State<_RiskBriefingCardContent> with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 40,
      ),
    ]).animate(_likeController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_likeController);
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_likeController.isAnimating) return;
    _likeController.forward(from: 0.0);
    _saveInsightToFirebase();
  }

  Future<void> _saveInsightToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final ngoId = userDoc.data()?['ngoId'] as String?;

      // 1. Add insight ID to user's savedInsights
      await firestore.collection('users').doc(user.uid).update({
        'ngoProfile.savedInsights': FieldValue.arrayUnion([widget.insightId])
      });

      // 2. Add insight ID to NGO's savedInsights
      if (ngoId != null && ngoId.trim().isNotEmpty) {
        await firestore.collection('ngos').doc(ngoId).set({
          'savedInsights': FieldValue.arrayUnion([widget.insightId])
        }, SetOptions(merge: true));
      }

      // 3. Increment saveCount and link NGO on the insight itself
      final insightUpdates = <String, dynamic>{
        'saveCount': FieldValue.increment(1),
      };
      if (ngoId != null && ngoId.trim().isNotEmpty) {
        insightUpdates['savedByNgoIds'] = FieldValue.arrayUnion([ngoId]);
      }

      await firestore.collection('insights').doc(widget.insightId).set(
        insightUpdates, 
        SetOptions(merge: true)
      );
    } catch (e) {
      debugPrint('Error saving insight: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final title = widget.title;
    final location = widget.location;
    final updatedAt = widget.updatedAt;
    final alertExplanation = widget.alertExplanation;
    final impactNumber = widget.impactNumber;
    final impactDescription = widget.impactDescription;
    final radiusNumber = widget.radiusNumber;
    final radiusDescription = widget.radiusDescription;
    final whyAlertRows = widget.whyAlertRows;
    final immediateAction = widget.immediateAction;
    final next4HoursAction = widget.next4HoursAction;
    final preparednessAction = widget.preparednessAction;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(left: 6, right: 6, top: 0, bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 14, top: 16, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            // 1. Badge & 3-Dot Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        badge, 
                        style: const TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.w800, 
                          color: Color(0xFF2563EB)
                        )
                      ),
                    ),
                    if (widget.isPrimary) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Double tap to save & generate brief',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(
                  height: 24,
                  width: 24,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF0F172A)),
                    onSelected: (value) {
                      if (value == 'save') {
                        _handleDoubleTap();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'save', child: Text('Save Brief', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // 2. Title
            Text(
              title, 
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)
            ),
            const SizedBox(height: 6),
            
            // 3. Location & Time
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(location, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 2),
            Text(updatedAt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
            
            const SizedBox(height: 12),
            
            // 4. Alert Explanation Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alertExplanation,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 5. Combined Stats & Why This Alert Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              ),
              child: Column(
                children: [
                  // Top Half: Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        // Left Column
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                                  SizedBox(width: 6),
                                  Text('Potentially Affected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(impactNumber, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), height: 1.0)),
                              const SizedBox(height: 2),
                              Text(impactDescription, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Container(width: 1.5, height: 60, color: const Color(0xFFF1F5F9)),
                        // Right Column
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.adjust_rounded, size: 14, color: Color(0xFF64748B)),
                                  SizedBox(width: 6),
                                  Text('Affected Radius', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _InteractiveRadiusMapWidget(
                                radiusNumber: radiusNumber,
                                radiusDescription: radiusDescription,
                                mapCategory: widget.mapCategory,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('Tap to view map', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFFDC2626)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Divider
                  Container(height: 1.5, width: double.infinity, color: const Color(0xFFF1F5F9)),
                  
                  // Bottom Half: Why This Alert?
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Why This Alert?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...whyAlertRows.map((row) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(row['icon'] as IconData, size: 14, color: const Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(row['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                              ),
                              Text(row['value'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: Text(row['subValue'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)), textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 7. Recommended Next Steps (Clean & Compact)
            const Text('Recommended Next Steps', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            _buildCompactActionRow(Icons.flash_on_rounded, 'NOW', immediateAction, const Color(0xFF2563EB)),
            _buildCompactActionRow(Icons.schedule_rounded, 'NEXT 4 HRS', next4HoursAction, const Color(0xFF0F172A)),
            _buildCompactActionRow(Icons.shield_rounded, 'PREPARE', preparednessAction, const Color(0xFF64748B)),
            
            // Map button uniquely integrated into Affected Radius above.
            const SizedBox(height: 20),
          ],
        ),
        ),
        
        // The animated overlay perfectly bounded to the card's rounded borders
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _likeController,
              builder: (context, child) {
                if (_likeController.value == 0.0 || _likeController.value == 1.0) {
                  return const SizedBox.shrink();
                }
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: _opacityAnimation.value * 1.2,
                        sigmaY: _opacityAnimation.value * 1.2,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(_opacityAnimation.value * 0.04),
                      ),
                    ),
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Color(0xFF2563EB),
                          size: 76,
                          shadows: [
                            Shadow(color: Colors.white, blurRadius: 24),
                            Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildCompactActionRow(IconData icon, String label, String action, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: themeColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: themeColor, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// COMPONENT: Interactive Radius Map Flipper
// ---------------------------------------------------------
class _InteractiveRadiusMapWidget extends StatefulWidget {
  final String radiusNumber;
  final String radiusDescription;
  final MapLayerCategory mapCategory;

  const _InteractiveRadiusMapWidget({
    required this.radiusNumber,
    required this.radiusDescription,
    required this.mapCategory,
  });

  @override
  State<_InteractiveRadiusMapWidget> createState() => _InteractiveRadiusMapWidgetState();
}

class _InteractiveRadiusMapWidgetState extends State<_InteractiveRadiusMapWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (_isFlipping) return;
    _isFlipping = true;
    
    // 1. Flip to Map icon
    await _controller.forward();
    
    // 2. Add a tiny delay for user to see the map icon.
    await Future.delayed(const Duration(milliseconds: 300));
    
    // 3. Navigate directly to MapScreen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(initialLayer: widget.mapCategory),
        ),
      );
    }
    
    // 4. Flip back after brief moment so it's ready when user returns
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      _controller.reverse();
    }
    _isFlipping = false;
  }

  Widget _buildFront() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: 0.65,
              strokeWidth: 5,
              backgroundColor: const Color(0xFFFEF2F2),
              color: const Color(0xFFDC2626),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.radiusNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text(widget.radiusDescription, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFDC2626),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.map_rounded, size: 20, color: Colors.white),
          SizedBox(height: 2),
          Text('MAP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          bool isBack = angle > math.pi / 2;

          return Transform(
            transform: Matrix4.rotationY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.rotationY(math.pi),
                    alignment: Alignment.center,
                    child: _buildBack(),
                  )
                : _buildFront(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// COMPONENT: Verified Source Item
// ---------------------------------------------------------
class _VerifiedSourceItem extends StatelessWidget {
  final String label;
  final String? tooltip;
  
  const _VerifiedSourceItem(this.label, {this.tooltip});

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (tooltip != null) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF94A3B8),
            size: 14,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: tooltip != null
          ? Tooltip(
              message: tooltip!,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                height: 1.4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 3),
              child: content,
            )
          : content,
    );
  }
}

// ---------------------------------------------------------
// COMPONENT: Continuous Data Synthesis Core
// ---------------------------------------------------------
class _ContinuousDataSynthesisCoreV4 extends StatefulWidget {
  const _ContinuousDataSynthesisCoreV4();

  @override
  State<_ContinuousDataSynthesisCoreV4> createState() =>
      _ContinuousDataSynthesisCoreV4State();
}

class _ContinuousDataSynthesisCoreV4State
    extends State<_ContinuousDataSynthesisCoreV4>
    with TickerProviderStateMixin {
  late AnimationController _loopController;
  late AnimationController _entranceController;
  late Animation<double> _coreFadeScale;

  final math.Random _rand = math.Random();
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _coreFadeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    for (int i = 0; i < 6; i++) {
      _particles.add(_generateParticle(i));
    }

    _entranceController.forward();
  }

  _Particle _generateParticle(int index) {
    final baseAngle = (index / 6) * 2 * math.pi;
    final jitter = (_rand.nextDouble() - 0.5) * (math.pi / 8);
    final angle = baseAngle + jitter;
    
    final sourceConfigs = [
      {'icon': Icons.description_outlined, 'label': 'Reports'},
      {'icon': Icons.health_and_safety_rounded, 'label': 'NGO'},
      {'icon': Icons.cloud_queue_rounded, 'label': 'Weather'},
      {'icon': Icons.campaign_rounded, 'label': 'Alerts'},
      {'icon': Icons.location_on_rounded, 'label': 'Community'},
      {'icon': Icons.bar_chart_rounded, 'label': 'Trends'},
    ];
    final config = sourceConfigs[index % sourceConfigs.length];
    final phase = _rand.nextDouble();
    return _Particle(
      angle: angle,
      icon: config['icon'] as IconData,
      label: config['label'] as String,
      phase: phase,
    );
  }

  @override
  void dispose() {
    _loopController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: AnimatedBuilder(
        animation: Listenable.merge([_loopController, _entranceController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(280, 280),
                painter: _StaticMeshPainter(),
              ),
              ..._particles.map((p) {
                double life = (_loopController.value + p.phase) % 1.0;
                final maxRadius = 135.0;
                final minRadius = 65.0;
                final currentRadius =
                    maxRadius - (life * (maxRadius - minRadius));

                final pos = Offset(
                  math.cos(p.angle) * currentRadius,
                  math.sin(p.angle) * currentRadius,
                );

                final opacity = (1.0 - math.pow(life, 2))
                    .clamp(0.0, 1.0)
                    .toDouble();

                return Transform.translate(
                  offset: pos,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: 0.7 + (0.3 * opacity),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              p.icon,
                              size: 16,
                              color: const Color(0xFF475569),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.label,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              Transform.scale(
                scale: _coreFadeScale.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '214',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Signals Analyzed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double angle;
  final IconData icon;
  final String label;
  final double phase;
  _Particle({
    required this.angle,
    required this.icon,
    required this.label,
    required this.phase,
  });
}

class _StaticMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final angle = random.nextDouble() * 2 * math.pi;

      final endRadius = 70.0 + (random.nextDouble() * 65.0);

      final startPoint = Offset(
        center.dx + 70.0 * math.cos(angle),
        center.dy + 70.0 * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticMeshPainter oldDelegate) => false;
}

// ---------------------------------------------------------
// COMPONENT: Animated Bottom CTA
// ---------------------------------------------------------
class _AnimatedBottomCTA extends StatefulWidget {
  const _AnimatedBottomCTA();

  @override
  State<_AnimatedBottomCTA> createState() => _AnimatedBottomCTAState();
}

class _AnimatedBottomCTAState extends State<_AnimatedBottomCTA>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -6.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -6.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: const Icon(
                    Icons.keyboard_double_arrow_up_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '3 Emerging Risks Identified',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: const Icon(
                    Icons.keyboard_double_arrow_up_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Swipe Up To Explore Briefings',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
