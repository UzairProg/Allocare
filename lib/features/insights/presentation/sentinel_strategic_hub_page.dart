import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../home/presentation/main_navigation_screen.dart';
import '../../map/presentation/map_screen.dart';

class SentinelStrategicHubPage extends StatefulWidget {
  const SentinelStrategicHubPage({super.key});

  @override
  State<SentinelStrategicHubPage> createState() =>
      _SentinelStrategicHubPageState();
}

class _SentinelStrategicHubPageState extends State<SentinelStrategicHubPage> {
  int _selectedTabIndex = 0; // 0 for Wellness, 1 for Waterborne, 2 for Airborne

  void _onTabChanged(int index) {
    if (_selectedTabIndex != index) {
      setState(() {
        _selectedTabIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        title: const Text(
          'AI Insights Hub',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              // 1. Data Synthesis Core with Convergence Animation
              const _ContinuousDataSynthesisCore(),
              const SizedBox(height: 24),

              // 2. The Proactive Narrative Tabs
              _buildSegmentNavigator(),
              const SizedBox(height: 24),

              // 3. The Briefing Cards (Animated Switch)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  final isNew = child.key == ValueKey('tab_$_selectedTabIndex');
                  final offsetAnim = Tween<Offset>(
                    begin: Offset(isNew ? 0.1 : -0.1, 0),
                    end: Offset.zero,
                  ).animate(animation);

                  return SlideTransition(
                    position: offsetAnim,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _selectedTabIndex == 0
                    ? _buildMentalHealthBriefing(key: const ValueKey('tab_0'))
                    : _selectedTabIndex == 1
                    ? _buildWaterborneBriefing(key: const ValueKey('tab_1'))
                    : _buildAirborneBriefing(key: const ValueKey('tab_2')),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentNavigator() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildNavItem(0, 'WELLNESS', const Color(0xFF0D9488)),
          _buildNavItem(1, 'WATERBORNE', const Color(0xFF0284C7)),
          _buildNavItem(2, 'AIRBORNE', const Color(0xFF9333EA)),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _selectedTabIndex == index
                ? Colors.white
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _selectedTabIndex == index
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _selectedTabIndex == index
                    ? activeColor
                    : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterborneBriefing({Key? key}) {
    return Column(
      key: key,
      children: [
        // Briefing Card
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 8,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF0EA5E9)),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Animated Header Banner
                  SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        // Background Image - small and to the right
                        const Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 160,
                          child: _CardPulsingBackgroundLayer(),
                        ),
                        // Heatmap Animation (Restored Dot)
                        const Positioned(
                          right: 24,
                          top: 0,
                          bottom: 0,
                          child: _WaterborneHeatmapVisualizer(),
                        ),
                        // Icon
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0EA5E9,
                                    ).withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.water_drop_rounded,
                                color: Color(0xFF0284C7),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Text Content
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Predicted Waterborne Outbreak (SDG 3/11)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Based on AI Analysis of 18 fragmented enteric reports, a pattern has been identified in Sector 4.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                            height: 1.5,
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
        const SizedBox(height: 16),
        // Resource Readiness Score Card
        _buildResourceReadinessCard(
          score: 91,
          color: const Color(0xFF16A34A),
          title:
              'Strategic Alignment: NGO Inventory (Water Tablets) matches 91% of projected demand for Sector 4.',
          layerName: 'Waterborne',
        ),
      ],
    );
  }

  Widget _buildAirborneBriefing({Key? key}) {
    return Column(
      key: key,
      children: [
        // Briefing Card
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 8,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF9333EA)),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Animated Header Banner
                  SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        // Vector Lines Animation (Started after the icon)
                        const Positioned(
                          left: 85,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: RepaintBoundary(
                            child: _AirborneVectorVisualizer(),
                          ),
                        ),
                        // Icon
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF).withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF9333EA,
                                    ).withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.air_rounded,
                                color: Color(0xFF7E22CE),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Text Content
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Predicted Airborne Cluster Risk (SDG 3/11)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Respiratory reports intersecting with population density in Zone B.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                            height: 1.5,
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
        const SizedBox(height: 16),
        // Resource Readiness Score Card
        _buildResourceReadinessCard(
          score: 72,
          color: const Color(0xFFD97706), // Amber
          title:
              'Strategic Alignment: NGO Inventory (N95 Masks) matches 72% of projected demand for Zone B.',
          layerName: 'Airborne',
        ),
      ],
    );
  }

  Widget _buildMentalHealthBriefing({Key? key}) {
    return Column(
      key: key,
      children: [
        // Briefing Card
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 8,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF0D9488)),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Animated Header Banner
                  SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        const Positioned(
                          right: 24,
                          top: 0,
                          bottom: 0,
                          child: _MentalHealthPulseVisualizer(),
                        ),
                        // Icon
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFA),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0D9488,
                                    ).withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: Color(0xFF0D9488),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Text Content
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Predicted Wellness Demand (SDG 3)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 12),
                        const Text(
                          'Aggregated sentiment reports indicating high stress-levels and support needs in Zone B.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                            height: 1.5,
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
        const SizedBox(height: 16),
        // Resource Readiness Score Card
        _buildResourceReadinessCard(
          score: 64,
          color: const Color(0xFF0D9488),
          title:
              'Strategic Alignment: Mental Health counselor availability matches 64% of projected crisis support needs for Zone B.',
          layerName: 'Mental Health',
        ),
      ],
    );
  }

  Widget _buildResourceReadinessCard({
    required int score,
    required Color color,
    required String title,
    required String layerName,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resource Readiness Score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: score / 100.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade100,
                            color: color,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${(value * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Button Polish: Glowing/Breathing Button
          SizedBox(
            width: double.infinity,
            child: _GlowingMapButton(layerName: layerName),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: BorderSide(color: Colors.grey.shade300, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Deploy Support',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
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

class _GlowingMapButton extends StatefulWidget {
  final String layerName;
  const _GlowingMapButton({required this.layerName});

  @override
  State<_GlowingMapButton> createState() => _GlowingMapButtonState();
}

class _GlowingMapButtonState extends State<_GlowingMapButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    _triggerAction();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  void _triggerAction() {
    final normalizedLayer = widget.layerName.trim().toLowerCase();
    final mapLayer = normalizedLayer.contains('airborne')
        ? MapLayerCategory.airborne
        : normalizedLayer.contains('waterborne')
        ? MapLayerCategory.waterborne
        : MapLayerCategory.mentalHealth;

    final nav = MainNavigationScreen.of(context);
    if (nav != null) {
      nav.openStrategicMap(layer: mapLayer);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          initialLayer: mapLayer,
          initialZoom: 14.8,
          lockInitialFocus: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF475569).withOpacity(0.3),
                    blurRadius: _glowAnimation.value + 4.0,
                    spreadRadius: _glowAnimation.value * 0.5,
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _triggerAction,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF475569),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  // Disable the internal ink splash to rely completely on our scale haptics
                  splashFactory: NoSplash.splashFactory,
                ),
                icon: const Icon(Icons.location_on_outlined, size: 20),
                label: const Text(
                  'View Priority Map',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 1. The 'Synthesis' Convergence Animations
// ---------------------------------------------------------

class _ContinuousDataSynthesisCore extends StatefulWidget {
  const _ContinuousDataSynthesisCore();

  @override
  State<_ContinuousDataSynthesisCore> createState() =>
      _ContinuousDataSynthesisCoreState();
}

class _ContinuousDataSynthesisCoreState
    extends State<_ContinuousDataSynthesisCore>
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
      duration: const Duration(seconds: 4),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _coreFadeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    // Initialize 8 floating particles
    for (int i = 0; i < 8; i++) {
      _particles.add(_generateParticle());
    }

    _entranceController.forward();
  }

  _Particle _generateParticle() {
    final angle = _rand.nextDouble() * 2 * math.pi;
    final iconChoices = [
      Icons.description_outlined,
      Icons.insert_chart_outlined,
      Icons.chat_bubble_outline,
      Icons.image_outlined,
      Icons.sms_outlined,
    ];
    final icon = iconChoices[_rand.nextInt(iconChoices.length)];
    // Random phase so they don't all start at the edge
    final phase = _rand.nextDouble();
    return _Particle(angle: angle, icon: icon, phase: phase);
  }

  @override
  void dispose() {
    _loopController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'DATA SYNTHESIS: ACTIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0284C7),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 280,
          child: AnimatedBuilder(
            animation: Listenable.merge([_loopController, _entranceController]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Static mesh background for texture
                  CustomPaint(
                    size: const Size(280, 280),
                    painter: _StaticMeshPainter(),
                  ),

                  // Continuously drifting particles
                  ..._particles.map((p) {
                    // Calculate life (0.0 at edge, 1.0 at center)
                    double life = (_loopController.value + p.phase) % 1.0;

                    final maxRadius = 140.0;
                    final minRadius = 60.0; // Stop when hitting core
                    final currentRadius =
                        maxRadius - (life * (maxRadius - minRadius));

                    final pos = Offset(
                      math.cos(p.angle) * currentRadius,
                      math.sin(p.angle) * currentRadius,
                    );

                    // Fade out as it reaches the center
                    final opacity = (1.0 - math.pow(life, 2))
                        .clamp(0.0, 1.0)
                        .toDouble();

                    return Transform.translate(
                      offset: pos,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 0.6 + (0.4 * opacity),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              p.icon,
                              size: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // The Synthesis Core Bubble
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
                            'Data Points',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
        ),
        const SizedBox(height: 20),
        const Text(
          '214 fragmented inputs (field notes, logs, paper surveys) successfully unified into 3 strategic patterns.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Particle {
  final double angle;
  final IconData icon;
  final double phase;
  _Particle({required this.angle, required this.icon, required this.phase});
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
      final endRadius = 70.0 + (random.nextDouble() * 70.0);

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
// 2. The 'Live Pattern' Visualizations
// ---------------------------------------------------------

class _WaterborneHeatmapVisualizer extends StatefulWidget {
  const _WaterborneHeatmapVisualizer();

  @override
  State<_WaterborneHeatmapVisualizer> createState() =>
      _WaterborneHeatmapVisualizerState();
}

class _WaterborneHeatmapVisualizerState
    extends State<_WaterborneHeatmapVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
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
        // Moving to and fro (left and right) further
        final offsetX = (_controller.value * 90.0) - 45.0;

        // Faded, dimming effect
        final opacity =
            0.1 + (_controller.value * 0.25); // Very faded: 0.1 to 0.35

        return SizedBox(
          width: 140,
          height: double.infinity,
          child: Transform.translate(
            offset: Offset(offsetX, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Primary soft blob
                Container(
                  width: 90,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(opacity),
                        blurRadius: 40.0,
                        spreadRadius: 10.0,
                      ),
                    ],
                  ),
                ),
                // Secondary offset blob to create an uneven 'heatmap' shape
                Transform.translate(
                  offset: const Offset(-20, 15),
                  child: Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF38BDF8,
                          ).withOpacity(opacity * 0.8),
                          blurRadius: 30.0,
                          spreadRadius: 5.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AirborneVectorVisualizer extends StatefulWidget {
  const _AirborneVectorVisualizer();

  @override
  State<_AirborneVectorVisualizer> createState() =>
      _AirborneVectorVisualizerState();
}

class _AirborneVectorVisualizerState extends State<_AirborneVectorVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _VectorFlowPainter(progress: _controller.value),
          );
        },
      ),
    );
  }
}

class _VectorFlowPainter extends CustomPainter {
  final double progress;
  _VectorFlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw 4 distinct extended vector lines spanning the width of the card
    for (int i = 0; i < 4; i++) {
      final path = Path();

      final startY = (size.height * 0.3) + (i * 20.0);
      final amplitude = 15.0 + (i * 5.0);
      final frequency = 0.02 + (i * 0.005);

      // Phase offset based on continuous progress
      final phaseOffset = progress * 2 * math.pi + (i * math.pi / 3);

      paint.color = const Color(0xFF9333EA).withOpacity(0.2 - (i * 0.02));

      // Start slightly off-screen left and flow to the right
      for (double x = -20; x <= size.width + 20; x++) {
        final y = startY + math.sin((x * frequency) + phaseOffset) * amplitude;

        if (x == -20) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Gradient shader so they fade out smoothly at edges
      paint.shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF9333EA).withOpacity(0.4),
          const Color(0xFFA855F7).withOpacity(0.8),
          const Color(0xFF9333EA).withOpacity(0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.6, 0.9, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      paint.strokeWidth = 2.0 + (i % 2);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorFlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MentalHealthPulseVisualizer extends StatefulWidget {
  const _MentalHealthPulseVisualizer();

  @override
  State<_MentalHealthPulseVisualizer> createState() =>
      _MentalHealthPulseVisualizerState();
}

class _MentalHealthPulseVisualizerState
    extends State<_MentalHealthPulseVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
        return CustomPaint(
          size: const Size(140, 110),
          painter: _MentalHealthPulsePainter(progress: _controller.value),
        );
      },
    );
  }
}

class _MentalHealthPulsePainter extends CustomPainter {
  final double progress;
  _MentalHealthPulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerY = size.height / 2;
    final width = size.width;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final lineProgress = (progress + (i * 0.33)) % 1.0;
      final opacity = (1.0 - lineProgress).clamp(0.0, 0.6);

      paint.color = const Color(0xFF0D9488).withOpacity(opacity);

      for (double x = 0; x <= width; x += 2) {
        // Brain-wave like multi-sine pattern
        final y =
            centerY +
            math.sin((x / width * 4 * math.pi) + (progress * 2 * math.pi)) *
                15 *
                (1 - lineProgress) +
            math.sin((x / width * 8 * math.pi) - (progress * 4 * math.pi)) *
                8 *
                lineProgress;

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Add a glow shader
      paint.shader = LinearGradient(
        colors: [
          const Color(0xFF0D9488).withOpacity(0),
          const Color(0xFF0D9488).withOpacity(opacity),
          const Color(0xFF5EEAD4).withOpacity(opacity),
          const Color(0xFF0D9488).withOpacity(opacity),
          const Color(0xFF0D9488).withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, size.height));

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MentalHealthPulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CardPulsingBackgroundLayer extends StatefulWidget {
  const _CardPulsingBackgroundLayer();

  @override
  State<_CardPulsingBackgroundLayer> createState() =>
      _CardPulsingBackgroundLayerState();
}

class _CardPulsingBackgroundLayerState
    extends State<_CardPulsingBackgroundLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgPulseController;

  @override
  void initState() {
    super.initState();
    _bgPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgPulseController,
      builder: (context, child) {
        // Slow scale from 1.0 to 1.05
        final scale = 1.0 + (_bgPulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity:
                0.15, // Made slightly lower opacity so it acts strictly as texture inside the white card
            // child: Image.asset(
            // 'assets/bg_img.png',
            // fit: BoxFit.cover,
            // alignment: Alignment.centerRight,
            // errorBuilder: (context, error, stackTrace) => const SizedBox(),
            // ),
          ),
        );
      },
    );
  }
}
