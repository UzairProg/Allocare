import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeMetric {
  const HomeMetric({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });

  final String title;
  final String value;
  final String description;
  final IconData icon;
}

final homeMetricsProvider = Provider<List<HomeMetric>>((ref) {
  return const [
    HomeMetric(
      title: 'Open cases',
      value: '18',
      description: 'Needs currently awaiting review',
      icon: Icons.assignment_outlined,
    ),
    HomeMetric(
      title: 'Priority alerts',
      value: '6',
      description: 'High-urgency items flagged for action',
      icon: Icons.priority_high_outlined,
    ),
    HomeMetric(
      title: 'Active zones',
      value: '9',
      description: 'Locations with live reporting activity',
      icon: Icons.map_outlined,
    ),
    HomeMetric(
      title: 'Volunteer matches',
      value: '24',
      description: 'Profiles ready for deployment',
      icon: Icons.groups_outlined,
    ),
  ];
});

class HomeModuleAction {
  const HomeModuleAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

final homeModuleActionsProvider = Provider<List<HomeModuleAction>>((ref) {
  return const [
    HomeModuleAction(
      title: 'Case intake',
      description: 'Capture incoming reports and normalize the data.',
      icon: Icons.inbox_outlined,
      color: Color(0xFF2563EB),
    ),
    HomeModuleAction(
      title: 'Allocation engine',
      description: 'Rank urgency, vulnerability, and impact in one queue.',
      icon: Icons.track_changes_outlined,
      color: Color(0xFF16A34A),
    ),
    HomeModuleAction(
      title: 'Insight layer',
      description: 'Spot recurring patterns and intervention opportunities.',
      icon: Icons.auto_graph_outlined,
      color: Color(0xFFDC2626),
    ),
  ];
});
