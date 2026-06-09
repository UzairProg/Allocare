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
      extendBody: true, // Allows notches and bottom bar transparency
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(2),
        backgroundColor: const Color(0xFF0284C7),
        elevation: 6,
        shape: const CircleBorder(),
        child: AnimatedRotation(
          turns: currentIndex == 2 ? 0.125 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: const Icon(
            Icons.sensors,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 16,
        shadowColor: Colors.black.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // Home Tab
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                primaryColor: const Color(0xFF0284C7),
                currentIndex: currentIndex,
              ),
              // Map Tab
              _buildNavItem(
                index: 3,
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map',
                primaryColor: const Color(0xFF0284C7),
                currentIndex: currentIndex,
              ),
              // Spacer for the center FAB
              const SizedBox(width: 48),
              // Tasks Tab (maps to Tasks / Reports view)
              _buildNavItem(
                index: 1,
                icon: Icons.task_outlined,
                activeIcon: Icons.task_alt_rounded,
                label: 'Mission Workspace',
                primaryColor: const Color(0xFF0284C7),
                currentIndex: currentIndex,
              ),
              // Profile Tab
              _buildNavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                primaryColor: const Color(0xFF0284C7),
                currentIndex: currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color primaryColor,
    required int currentIndex,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _onTabTapped(index),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? primaryColor : const Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? primaryColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
