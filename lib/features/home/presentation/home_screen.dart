import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';

import '../../insights/presentation/sentinel_strategic_hub_page.dart';
import '../../insights/presentation/smart_allocation_center_page.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_profile_service.dart';
import '../application/home_live_data_providers.dart';
import '../../reports/presentation/report_entry_hub_page.dart';
import 'main_navigation_screen.dart';
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
                            GestureDetector(
                              onTap: () => MainNavigationScreen.of(context)
                                  ?.setIndex(4),
                              child: CircleAvatar(
                                radius: isWeb ? 28 : 22,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : const NetworkImage(
                                        'https://i.pravatar.cc/150?u=aditi',
                                      ),
                                backgroundColor: const Color(0xFFF0F0F0),
                              ),
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
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => _MissionLogPage(activities: recent)),
                                  );
                                },
                                icon: const Icon(Icons.terminal_rounded, size: 16),
                                label: const Text('VIEW FULL TACTICAL LOG'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFE4ECF9)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                                ),
                              ),
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

class _ActivityListTile extends StatefulWidget {
  const _ActivityListTile({required this.item});
  final RecentActivityItem item;

  @override
  State<_ActivityListTile> createState() => _ActivityListTileState();
}

class _ActivityListTileState extends State<_ActivityListTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final theme = Theme.of(context);
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
        border: Border.all(color: const Color(0xFFF5F5F5)),
        boxShadow: [
          if (_isExpanded)
            BoxShadow(
              color: item.accentColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isWeb ? 16 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(width: 8),
                          _buildUrgencyBadge(item),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${item.subtitle} · ${item.timeAgo}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: isWeb ? 12 : 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSourceTray(item),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildAllocationStatus(item),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isExpanded)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: item.accentColor.withOpacity(0.05),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.psychology_rounded, size: 16, color: item.accentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Gemini Reasoning: ${item.aiReasoning}',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.accentColor.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge(RecentActivityItem item) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: item.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: item.accentColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.urgencyScore.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: item.accentColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isExpanded ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              size: 12,
              color: item.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTray(RecentActivityItem item) {
    return Row(
      children: item.dataSources.map((icon) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(icon, size: 12, color: Colors.grey.withOpacity(0.4)),
      )).toList(),
    );
  }

  Widget _buildAllocationStatus(RecentActivityItem item) {
    if (item.assignedVolunteer != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCFCE7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
            const SizedBox(width: 6),
            Text(
              'STRATEGIC MATCH: ${item.assignedVolunteer}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16A34A),
              ),
            ),
            if (item.proximity != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.proximity!,
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
              ),
            ],
            if (item.volunteerRank != null) ...[
              const SizedBox(width: 6),
              Text(
                '· ${item.volunteerRank}',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A).withOpacity(0.7)),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 12, color: item.accentColor.withOpacity(0.5)),
        const SizedBox(width: 8),
        Text(
          'OPTIMIZING HUMANITY FORCE RESPONSE...',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: item.accentColor.withOpacity(0.8),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MissionLogPage extends StatelessWidget {
  final List<RecentActivityItem> activities;
  const _MissionLogPage({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('TACTICAL MISSION LOG', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: activities.length + 4,
        itemBuilder: (context, index) {
          if (index < activities.length) {
            final item = activities[index];
            return _buildLogEntry(
              time: item.timeAgo,
              msg: '${item.title} -> ${item.aiReasoning}',
              type: 'report',
              color: item.accentColor,
            );
          }
          
          final extraIndex = index - activities.length;
          final extras = [
            {'time': 'SYSTEM', 'msg': 'Syncing with Global Sentinel Inventory...', 'type': 'system'},
            {'time': 'AI', 'msg': 'Density clusters updated in Kranti Chowk. Re-routing unassigned guardians.', 'type': 'ai'},
            {'time': 'IOT', 'msg': 'Water Quality sensors in CIDCO Sector 4 reporting improvement.', 'type': 'iot'},
            {'time': 'MATCH', 'msg': 'Optimizing 12 pending reports for 100% strategic coverage.', 'type': 'match'},
          ];
          final e = extras[extraIndex];
          return _buildLogEntry(
            time: e['time']!,
            msg: e['msg']!,
            type: e['type']!,
          );
        },
      ),
    );
  }

  Widget _buildLogEntry({required String time, required String msg, required String type, Color? color}) {
    Color msgColor = Colors.white70;
    if (type == 'ai') msgColor = const Color(0xFF3B82F6);
    if (type == 'report') msgColor = color ?? Colors.white;
    if (type == 'match') msgColor = const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '[$time]',
              style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: msgColor,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
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
