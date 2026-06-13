import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/volunteer_controller.dart';
import 'volunteer_home.dart';
import 'volunteer_map.dart';
import 'volunteer_profile.dart';
import 'volunteer_report.dart';
import 'volunteer_tasks.dart';

class VolunteerMainShell extends ConsumerStatefulWidget {
  const VolunteerMainShell({super.key});

  @override
  ConsumerState<VolunteerMainShell> createState() => _VolunteerMainShellState();
}

class _VolunteerMainShellState extends ConsumerState<VolunteerMainShell> {
  final List<Widget> _pages = [
    const VolunteerHomeScreen(),
    const VolunteerTasksScreen(),
    const VolunteerReportScreen(),
    const VolunteerMapScreen(),
    const VolunteerProfileScreen(),
  ];

  void _onTabTapped(int index) {
    ref.read(volunteerTabControllerProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(volunteerTabControllerProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF0B1F4D).withOpacity(0.05),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, 'Home', currentIndex),
              _buildNavItem(3, Icons.map_outlined, 'Map', currentIndex),
              _buildCenterReportButton(currentIndex),
              _buildNavItem(1, Icons.dashboard_customize_outlined, 'Workspace', currentIndex),
              _buildNavItem(4, Icons.person_outline_rounded, 'Profile', currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, int currentIndex) {
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF0B1F4D) : const Color(0xFF94A3B8);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0B1F4D).withOpacity(0.08) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: AnimatedScale(
                scale: isSelected ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: -0.1,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterReportButton(int currentIndex) {
    final isSelected = currentIndex == 2;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(2),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0B1F4D) : const Color(0xFF94A3B8),
                  letterSpacing: -0.1,
                ),
                child: const Text('Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
