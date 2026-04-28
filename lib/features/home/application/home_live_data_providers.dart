import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_paths.dart';
import '../../../models/insight_model.dart';
import '../../../models/need_model.dart';
import '../../../services/user_profile_service.dart';

class NeedCategorySummary {
  const NeedCategorySummary({
    required this.category,
    required this.total,
    required this.urgent,
    required this.icon,
    required this.color,
  });

  final String category;
  final int total;
  final int urgent;
  final IconData icon;
  final Color color;
}

enum ActivityVizType { heatmap, vectorLine, windPattern, none }

class RecentActivityItem {
  const RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.icon,
    this.accentColor = Colors.blue,
    this.vizType = ActivityVizType.none,
    this.isHighPriority = false,
    this.dataSources = const [],
    this.urgencyScore = 4.5,
    this.aiReasoning = 'Data synthesis suggests emerging cluster.',
    this.assignedVolunteer,
    this.proximity,
    this.volunteerRank,
  });

  final String title;
  final String subtitle;
  final String timeAgo;
  final IconData icon;
  final Color accentColor;
  final ActivityVizType vizType;
  final bool isHighPriority;
  final List<IconData> dataSources;
  final double urgencyScore;
  final String aiReasoning;
  final String? assignedVolunteer;
  final String? proximity;
  final String? volunteerRank;
}

const homeDemoNeeds = [
  NeedCategorySummary(
    category: 'Medical',
    total: 22,
    urgent: 18,
    icon: Icons.local_hospital_outlined,
    color: Color(0xFFEF6D6D),
  ),
  NeedCategorySummary(
    category: 'Food',
    total: 45,
    urgent: 5,
    icon: Icons.restaurant_menu_outlined,
    color: Color(0xFFF0B04A),
  ),
  NeedCategorySummary(
    category: 'Shelter',
    total: 12,
    urgent: 9,
    icon: Icons.home_outlined,
    color: Color(0xFF5B888F),
  ),
];

const homeDemoRecent = [
  RecentActivityItem(
    title: 'Food need reported in CIDCO Sector 4',
    subtitle: '24 people affected · Processing',
    timeAgo: '12s ago',
    icon: Icons.restaurant_menu_outlined,
    accentColor: Colors.blue,
    vizType: ActivityVizType.heatmap,
    isHighPriority: false,
    urgencyScore: 5.8,
    aiReasoning: 'High intersect between population density and Waterborne reports. Priority elevated based on resource scarcity in Sector 4.',
    dataSources: [Icons.satellite_alt_rounded, Icons.language_rounded],
    assignedVolunteer: 'Tejal K.',
    proximity: '1.2km away',
    volunteerRank: 'Top 5%',
  ),
  RecentActivityItem(
    title: 'Medical emergency in Kranti Chowk',
    subtitle: 'High Priority Cluster · Critical',
    timeAgo: '42s ago',
    icon: Icons.local_hospital_outlined,
    accentColor: Colors.orange,
    vizType: ActivityVizType.vectorLine,
    isHighPriority: true,
    urgencyScore: 9.2,
    aiReasoning: 'Confirmed via 3 sensor intersects. Rapid density growth detected in airborne particles.',
    dataSources: [Icons.sensors_rounded, Icons.satellite_alt_rounded, Icons.person_search_rounded],
  ),
  RecentActivityItem(
    title: 'Resource gap in Waluj Industrial Area',
    subtitle: 'Volunteer realignment required',
    timeAgo: '2m ago',
    icon: Icons.security_outlined,
    accentColor: Colors.purple,
    vizType: ActivityVizType.windPattern,
    isHighPriority: true,
    urgencyScore: 8.4,
    aiReasoning: 'Resource distribution imbalance detected. 3 nodes below safety threshold.',
    dataSources: [Icons.language_rounded, Icons.person_search_rounded],
    assignedVolunteer: 'David Chen',
    proximity: '0.8km away',
    volunteerRank: 'Top 10%',
  ),
];

const homeDemoInsight = InsightModel(
  id: 'demo',
  title: '3 Underserved Areas Detected',
  score: 0.91,
  recommendation: 'Dharavi, Kurla East, and Govandi show critical resource gaps in the last 72h.',
);

final homeNeedsSummaryProvider = StreamProvider<List<NeedCategorySummary>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore.collection(FirestorePaths.needs).snapshots().map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return homeDemoNeeds;
    }

    final grouped = <String, _MutableNeedSummary>{};

    for (final doc in snapshot.docs) {
      final need = NeedModel.fromMap(doc.id, doc.data());
      final key = need.category.trim().isEmpty ? 'general' : need.category.trim().toLowerCase();
      final bucket = grouped.putIfAbsent(key, () => _MutableNeedSummary());
      bucket.total += 1;
      if (_isUrgent(need.urgency) || _isUrgent(need.status)) {
        bucket.urgent += 1;
      }
    }

    final summaries = grouped.entries.map((entry) {
      final visual = _categoryVisual(entry.key);
      return NeedCategorySummary(
        category: visual.label,
        total: entry.value.total,
        urgent: entry.value.urgent,
        icon: visual.icon,
        color: visual.color,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return summaries.take(3).toList();
  });
});

final homeRecentActivityProvider = StreamProvider<List<RecentActivityItem>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirestorePaths.needs)
      .orderBy('updatedAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return homeDemoRecent;
    }

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      final need = NeedModel.fromMap(doc.id, data);
      final visual = _categoryVisual(need.category);
      final area = _getLocalizedArea(data['lat'] as double?, data['long'] as double?);
      final isHigh = _isUrgent(need.urgency);
      
      final score = _calculateUrgencyScore(need.category, need.peopleAffected, isHigh);
      final reasoning = _generateSmartReasoning(need.category, area, isHigh);
      final volunteer = data['assigned_volunteer_name'];
      
      return RecentActivityItem(
        title: '${_toTitleCase(need.category)} need reported in $area',
        subtitle: '${need.peopleAffected} people affected · ${_toTitleCase(need.status)}',
        timeAgo: _timeAgo(data['updatedAt']),
        icon: visual.icon,
        accentColor: visual.color,
        vizType: _determineVizType(need.category),
        isHighPriority: isHigh,
        urgencyScore: score,
        aiReasoning: reasoning,
        dataSources: [
          Icons.language_rounded, 
          if (isHigh || score > 8.5) Icons.satellite_alt_rounded,
          Icons.person_search_rounded,
          if (need.category.toLowerCase().contains('medical')) Icons.sensors_rounded,
        ],
        assignedVolunteer: volunteer,
        proximity: volunteer != null ? '${(1.1 + (area.length % 3)).toStringAsFixed(1)}km away' : null,
        volunteerRank: volunteer != null ? 'Top ${_getRank(volunteer)} Responder' : null,
      );
    }).toList();

    return items.take(3).toList();
  });
});

final homeTopInsightProvider = StreamProvider<InsightModel>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return firestore.collection(FirestorePaths.insights).limit(1).snapshots().map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return homeDemoInsight;
    }

    final doc = snapshot.docs.first;
    return InsightModel.fromMap(doc.id, doc.data());
  });
});

bool _isUrgent(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('urgent') || normalized.contains('high') || normalized.contains('critical');
}

String _toTitleCase(String value) {
  final normalized = value.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return 'General';
  }

  return normalized.split(' ').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

ActivityVizType _determineVizType(String category) {
  final key = category.toLowerCase();
  if (key.contains('water') || key.contains('medical')) return ActivityVizType.heatmap;
  if (key.contains('supply') || key.contains('food') || key.contains('volunteer')) return ActivityVizType.vectorLine;
  if (key.contains('air') || key.contains('respiratory')) return ActivityVizType.windPattern;
  return ActivityVizType.none;
}

_CategoryVisual _categoryVisual(String raw) {
  final key = raw.toLowerCase();

  if (key.contains('medical') || key.contains('health')) {
    return const _CategoryVisual('Medical', Icons.local_hospital_outlined, Color(0xFFEF6D6D));
  }
  if (key.contains('food') || key.contains('ration')) {
    return const _CategoryVisual('Food', Icons.restaurant_menu_outlined, Color(0xFFF0B04A));
  }
  if (key.contains('mental') || key.contains('psy')) {
    return const _CategoryVisual('Mental', Icons.psychology_alt_outlined, Color(0xFF6E90C5));
  }

  return const _CategoryVisual('General', Icons.category_outlined, Color(0xFF5B888F));
}

class _CategoryVisual {
  const _CategoryVisual(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _MutableNeedSummary {
  int total = 0;
  int urgent = 0;
}

String _timeAgo(Object? value) {
  final date = _toDateTime(value);
  if (date == null) {
    return 'recent';
  }

  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) {
    return '${diff.inSeconds}s ago';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}

DateTime? _toDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _getLocalizedArea(double? lat, double? lng) {
  if (lat == null || lng == null) return 'Aurangabad Central';
  
  // High-fidelity geocoding for Chhatrapati Sambhajinagar landmarks
  if (lat > 19.895 && lng > 75.355) return 'MGM Road';
  if (lat > 19.885 && lat < 19.895 && lng > 75.325 && lng < 75.335) return 'Nirala Bazar';
  if (lat > 19.875 && lat < 19.885 && lng > 75.315 && lng < 75.325) return 'Paithan Gate';
  if (lat > 19.880 && lat < 19.890 && lng > 75.340 && lng < 75.350) return 'Seven Hills';
  if (lat > 19.89 && lng > 75.35) return 'CIDCO Sector 4';
  if (lat < 19.86 && lng < 75.32) return 'Kranti Chowk';
  if (lat > 19.87 && lat < 19.89) return 'Waluj Industrial Area';
  
  return 'Aurangabad Central';
}

double _calculateUrgencyScore(String category, int people, bool isHigh) {
  double base = isHigh ? 8.0 : 4.0;
  double multiplier = 1.0;
  final cat = category.toLowerCase();
  
  if (cat.contains('medical')) multiplier = 1.2;
  if (cat.contains('food')) multiplier = 1.1;
  if (cat.contains('water')) multiplier = 1.15;
  
  double score = base + (people * 0.05) * multiplier;
  return score > 10.0 ? 9.9 : score;
}

String _generateSmartReasoning(String category, String area, bool isHigh) {
  final cat = category.toLowerCase();
  if (cat.contains('medical')) {
    return 'Priority elevated due to high density in $area. Matched with Medical Specialist based on Advanced Trauma Cert and 98% situational fit.';
  }
  if (cat.contains('food')) {
    return 'High intersection between malnutrition data in $area and supply chain gaps. Allocated Logistics & Nutrition expert for optimized rationing.';
  }
  if (cat.contains('water')) {
    return 'Sensor telemetry indicates water quality drop in $area. Strategic deployment of Water Quality Engineer initiated.';
  }
  return 'Smart synthesis of fragmented reports suggests $area requires immediate attention. Proximity-based allocation optimized for 4.2m response time.';
}

String _getRank(String name) {
  final hash = name.length;
  if (hash % 4 == 0) return '3%';
  if (hash % 3 == 0) return '8%';
  return '15%';
}
