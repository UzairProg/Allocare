import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../insights/presentation/sentinel_strategic_hub_page.dart';
import '../../map/presentation/map_screen.dart';
import '../../needs/presentation/needs_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reports/presentation/report_entry_hub_page.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static MainNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavigationScreenState>();
  }

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  MapLayerCategory _mapLaunchLayer = MapLayerCategory.medical;
  int _mapLaunchNonce = 0;

  void openStrategicMap({required MapLayerCategory layer}) {
    setState(() {
      _mapLaunchLayer = layer;
      _mapLaunchNonce++;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeScreen(),
      MapScreen(
        key: ValueKey<String>('map_${_mapLaunchLayer.name}_$_mapLaunchNonce'),
        initialLayer: _mapLaunchLayer,
        initialZoom: 14.8,
        lockInitialFocus: true,
      ),
      const NeedsScreen(),
      const SentinelStrategicHubPage(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: _index,
        onChanged: (value) {
          setState(() {
            _index = value;
          });
        },
      ),
    );
  }
}

class _PremiumBottomNav extends StatelessWidget {
  const _PremiumBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final scheme = Theme.of(context).colorScheme;

    final navBody = ClipRRect(
      borderRadius: BorderRadius.circular(isWeb ? 30 : 28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isWeb ? 11 : 8,
          sigmaY: isWeb ? 11 : 8,
        ),
        child: Container(
          height: isWeb ? 92 : 78,
          padding: EdgeInsets.symmetric(horizontal: isWeb ? 14 : 10),
          decoration: BoxDecoration(
            gradient: isWeb
                ? const LinearGradient(
                    colors: [Color(0xEDFDFEFF), Color(0xE9EFF4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isWeb ? null : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(isWeb ? 30 : 28),
            border: Border.all(
              color: isWeb
                  ? const Color(0xFFDCE6F8)
                  : Colors.white.withValues(alpha: 0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF1D2A30,
                ).withValues(alpha: isWeb ? 0.16 : 0.12),
                blurRadius: isWeb ? 34 : 24,
                offset: Offset(0, isWeb ? 12 : 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: currentIndex == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                label: 'Map',
                icon: Icons.map_rounded,
                selected: currentIndex == 1,
                onTap: () => onChanged(1),
              ),
              _ReportNavTab(selected: false, scheme: scheme),
              _NavItem(
                label: 'Insights',
                icon: Icons.auto_graph_rounded,
                selected: currentIndex == 3,
                onTap: () => onChanged(3),
              ),
              _NavItem(
                label: 'Profile',
                icon: Icons.person_rounded,
                selected: currentIndex == 4,
                onTap: () => onChanged(4),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, isWeb ? 14 : 10),
      child: isWeb
          ? Align(
              alignment: Alignment.bottomCenter,
              widthFactor: 1,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: navBody,
              ),
            )
          : navBody,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          offset: selected ? const Offset(0, -0.03) : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(vertical: isWeb ? 10 : 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.all(isWeb ? 6 : 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    scale: selected ? 1.08 : 1,
                    child: Icon(
                      icon,
                      size: isWeb ? 26 : 22,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: isWeb ? 5 : 3),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontSize: isWeb ? 12.5 : null,
                  ),
                ),
                SizedBox(height: isWeb ? 3 : 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: selected ? (isWeb ? 20 : 16) : 0,
                  height: isWeb ? 3 : 2.5,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportNavIcon extends StatelessWidget {
  const _ReportNavIcon({required this.isSelected, required this.scheme});

  final bool isSelected;
  final ColorScheme scheme;

  void _openHub(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => const ReportEntryHubPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return GestureDetector(
      onTap: () => _openHub(context),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: isSelected ? 1.02 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: isWeb ? 52 : 40,
          height: isWeb ? 52 : 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.25),
                blurRadius: isWeb ? 18 : 14,
                offset: Offset(0, isWeb ? 9 : 7),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: isWeb ? 27 : 21,
          ),
        ),
      ),
    );
  }
}

class _ReportNavTab extends StatelessWidget {
  const _ReportNavTab({required this.selected, required this.scheme});

  final bool selected;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isWeb ? 2 : 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, isWeb ? -7 : -4),
              child: _ReportNavIcon(isSelected: selected, scheme: scheme),
            ),
            SizedBox(height: isWeb ? 3 : 2),
            Text(
              'Report',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontSize: isWeb ? 12.5 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
