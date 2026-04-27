import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../insights/presentation/sentinel_strategic_hub_page.dart';
import '../../insights/presentation/smart_allocation_center_page.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';
import '../application/home_live_data_providers.dart';
import '../../reports/presentation/report_entry_hub_page.dart';
import 'widgets/micro_visualizations.dart';
import 'widgets/sync_core_animation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showVolunteerDetails = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeb = kIsWeb;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final recent =
        ref.watch(homeRecentActivityProvider).asData?.value ?? homeDemoRecent;
    final needsSummary =
        ref.watch(homeNeedsSummaryProvider).asData?.value ?? homeDemoNeeds;

    final userName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : (authUser?.displayName?.trim() ?? 'Aditi');

    final photoUrl = authUser?.photoURL;

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFFF2F5FA) : Colors.white,
      body: SafeArea(
        child: Container(
          decoration: isWeb
              ? const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF9FBFF), Color(0xFFEFF3FA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                )
              : null,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWeb ? 1180 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWeb ? 28 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // 1. Personalized Header
                      _Reveal(
                        controller: _controller,
                        interval: const Interval(
                          0.0,
                          0.2,
                          curve: Curves.easeOutCubic,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good morning, $userName!',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1D2A30),
                                        fontSize: isWeb ? 34 : null,
                                      ),
                                ),
                                Text(
                                  'Chhatrapati Sambhajinagar Operation Hub',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                    fontSize: isWeb ? 16 : null,
                                  ),
                                ),
                              ],
                            ),
                            CircleAvatar(
                              radius: isWeb ? 28 : 22,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : const NetworkImage(
                                      'https://i.pravatar.cc/150?u=aditi',
                                    ),
                              backgroundColor: const Color(0xFFF0F0F0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Workforce Deployment Hero
                      _Reveal(
                        controller: _controller,
                        interval: const Interval(
                          0.1,
                          0.4,
                          curve: Curves.easeOutCubic,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compactWeb =
                                isWeb && constraints.maxWidth < 940;

                            if (compactWeb) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AllocationProgressCard(
                                    title: 'Volunteer Deployment',
                                    total: 58,
                                    assigned: 42,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SmartAllocationCenterPage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _ResourceSynthesisCard(
                                    title: 'Resource Intelligence',
                                    header: 'Fragmented Field Intelligence',
                                    value: '214',
                                    supply: 140,
                                    demand: 214,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SentinelStrategicHubPage(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _AllocationProgressCard(
                                    title: 'Volunteer Deployment',
                                    total: 58,
                                    assigned: 42,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SmartAllocationCenterPage(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _ResourceSynthesisCard(
                                    title: 'Resource Intelligence',
                                    header: 'Fragmented Field Intelligence',
                                    value: '214',
                                    supply: 140,
                                    demand: 214,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SentinelStrategicHubPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Priority Bridge Banner
                      _Reveal(
                        controller: _controller,
                        interval: const Interval(
                          0.2,
                          0.5,
                          curve: Curves.easeOutCubic,
                        ),
                        child: const _PriorityBridgeBanner(
                          message:
                              'Strategic Priority Alignment: Diverting Waluj Medical Team to Pundlik Nagar based on Active Cluster Detection.',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3b. Report a Need Box (Emotional Hook)
                      _Reveal(
                        controller: _controller,
                        interval: const Interval(
                          0.25,
                          0.55,
                          curve: Curves.easeOutCubic,
                        ),
                        child: _ReportNeedBox(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportEntryHubPage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 4. Active Needs (Emergency Focus)
                      _Reveal(
                        controller: _controller,
                        interval: const Interval(
                          0.3,
                          0.6,
                          curve: Curves.easeOutCubic,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Needs (Emergency Focus)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D2A30),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: isWeb ? 142 : 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: needsSummary.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) =>
                                    _NeedSummaryCard(
                                      summary: needsSummary[index],
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 5. Hyper-Local Live Feed
                      _Reveal(
                        controller: _controller,
                        interval: const Interval(
                          0.5,
                          0.8,
                          curve: Curves.easeOutCubic,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Priority-Based Allocation',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1D2A30),
                                  ),
                                ),
                                Text(
                                  'LIVE FEED',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: recent.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _ActivityListTile(item: recent[index]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
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
}

class _AllocationProgressCard extends StatelessWidget {
  const _AllocationProgressCard({
    required this.title,
    required this.total,
    required this.assigned,
    this.onTap,
  });

  final String title;
  final int total;
  final int assigned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isWeb ? 228 : 180,
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 28 : 24),
          border: Border.all(
            color: isWeb ? const Color(0xFFE4ECF9) : const Color(0xFFF0F0F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isWeb ? 0.06 : 0.04),
              blurRadius: isWeb ? 26 : 20,
              offset: Offset(0, isWeb ? 10 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isWeb ? 12 : 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Verified & Ready to Deploy: $total',
              style: TextStyle(
                fontSize: isWeb ? 13 : 11,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isWeb ? 10 : 8),
            Center(
              child: SizedBox(
                height: isWeb ? 80 : 60,
                width: isWeb ? 132 : 100,
                child: CustomPaint(
                  painter: _SemiCircularProgressPainter(
                    percentage: assigned / total,
                    color: Colors.green,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        '$assigned',
                        style: TextStyle(
                          fontSize: isWeb ? 28 : 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D2A30),
                        ),
                      ),
                      Text(
                        'Strategically\nPositioned',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isWeb ? 9 : 6.5,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'View Smart Allocation →',
                  style: TextStyle(
                    fontSize: kIsWeb ? 11 : 7.5,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceSynthesisCard extends StatelessWidget {
  const _ResourceSynthesisCard({
    required this.title,
    required this.header,
    required this.value,
    required this.supply,
    required this.demand,
    this.onTap,
  });

  final String title;
  final String header;
  final String value;
  final double supply;
  final double demand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isWeb ? 228 : 180,
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 28 : 24),
          border: Border.all(
            color: isWeb ? const Color(0xFFE4ECF9) : const Color(0xFFF0F0F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isWeb ? 0.06 : 0.04),
              blurRadius: isWeb ? 26 : 20,
              offset: Offset(0, isWeb ? 10 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isWeb ? 12 : 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: isWeb ? 10 : 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isWeb ? 40 : 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1D2A30),
              ),
            ),
            Text(
              header,
              style: TextStyle(
                fontSize: isWeb ? 11 : 9,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniBar(
                  label: 'Resources',
                  value: supply,
                  maxValue: demand,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _MiniBar(
                  label: 'Field Priorities',
                  value: demand,
                  maxValue: demand,
                  color: Colors.orange,
                ),
                const Spacer(),
                const Text(
                  'Insights →',
                  style: TextStyle(
                    fontSize: kIsWeb ? 11 : 8,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });
  final String label;
  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final maxBarHeight = isWeb ? 48.0 : 36.0;
    final height = (value / maxValue) * maxBarHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: isWeb ? 28 : 24,
          height: height.clamp(4, maxBarHeight),
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: isWeb ? 56 : 42,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: isWeb ? 10.5 : 7.5,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SemiCircularProgressPainter extends CustomPainter {
  _SemiCircularProgressPainter({required this.percentage, required this.color});
  final double percentage;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = Colors.grey[100]!
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 3.14, 3.14, false, bgPaint);
    canvas.drawArc(rect, 3.14, 3.14 * percentage, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PriorityBridgeBanner extends StatelessWidget {
  const _PriorityBridgeBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 20 : 16,
        vertical: isWeb ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(isWeb ? 18 : 16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.green,
            size: isWeb ? 24 : 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: isWeb ? 13 : 11,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedSummaryCard extends StatelessWidget {
  const _NeedSummaryCard({required this.summary});
  final NeedCategorySummary summary;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return Container(
      width: isWeb ? 196 : 150,
      padding: EdgeInsets.all(isWeb ? 14 : 12),
      decoration: BoxDecoration(
        color: summary.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(isWeb ? 22 : 20),
        border: Border.all(color: summary.color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(summary.icon, color: summary.color, size: isWeb ? 28 : 22),
          const Spacer(),
          Text(
            '${summary.category}: ${summary.total}',
            style: TextStyle(
              fontSize: isWeb ? 18 : 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D2A30),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '[${summary.urgent} Urgent]',
            style: TextStyle(
              fontSize: isWeb ? 13 : 11,
              color: Color(0xFFD32F2F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityListTile extends StatelessWidget {
  const _ActivityListTile({required this.item});
  final RecentActivityItem item;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isWeb ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
        border: Border.all(color: const Color(0xFFF5F5F5)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isWeb ? 12 : 10),
            decoration: BoxDecoration(
              color: item.accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: item.accentColor,
              size: isWeb ? 22 : 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D2A30),
                          fontSize: isWeb ? 16 : null,
                        ),
                      ),
                    ),
                    if (item.isHighPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HIGH PRIORITY',
                          style: TextStyle(
                            fontSize: kIsWeb ? 9 : 7,
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.subtitle} · ${item.timeAgo}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: isWeb ? 12 : 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (item.vizType != ActivityVizType.none)
            MicroVisualization(type: item.vizType, color: item.accentColor),
        ],
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.interval,
    required this.child,
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Keep web sections always visible; animated opacity can stay at 0 when
      // ticker mode is muted in nested navigation layouts.
      return child;
    }

    final curved = CurvedAnimation(parent: controller, curve: interval);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _ReportNeedBox extends StatelessWidget {
  const _ReportNeedBox({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isWeb ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A73E8),
              const Color(0xFF1A73E8).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isWeb ? 28 : 24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withOpacity(0.25),
              blurRadius: isWeb ? 28 : 20,
              offset: Offset(0, isWeb ? 12 : 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Be the Bridge to Care',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: kIsWeb ? 22 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Report a need! Save a Life. Help us identify and realign resources to those in need.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isWeb ? 14 : 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: EdgeInsets.all(isWeb ? 14 : 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: Color(0xFF1A73E8),
                size: isWeb ? 32 : 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
