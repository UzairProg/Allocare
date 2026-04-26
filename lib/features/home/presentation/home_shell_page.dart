import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/auth_service.dart';
import '../../allocation/presentation/allocation_placeholder_page.dart';
import '../../insights/presentation/smart_allocation_center_page.dart';
import '../../map/presentation/map_placeholder_page.dart';
import '../../profile/presentation/profile_screen.dart';
import 'home_dashboard_page.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  int _currentTab = 0;

  static const _titles = ['Home', 'Map', 'Allocation', 'Insights', 'Profile'];

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomeDashboardPage(),
      MapPlaceholderPage(),
      AllocationPlaceholderPage(),
      SmartAllocationCenterPage(),
      ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Allocare - ${_titles[_currentTab]}'),
        actions: [
          if (_currentTab != 4)
            TextButton(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: IndexedStack(index: _currentTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Allocation',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
