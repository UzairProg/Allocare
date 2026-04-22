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

class RecentActivityItem {
  const RecentActivityItem({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String timeAgo;
  final IconData icon;
}

const homeDemoNeeds = [
  NeedCategorySummary(
    category: 'Medical',
    total: 47,
    urgent: 12,
    icon: Icons.local_hospital_outlined,
    color: Color(0xFFEF6D6D),
  ),
  NeedCategorySummary(
    category: 'Food',
    total: 83,
    urgent: 5,
    icon: Icons.restaurant_menu_outlined,
    color: Color(0xFFF0B04A),
  ),
  NeedCategorySummary(
    category: 'Mental',
    total: 31,
    urgent: 8,
    icon: Icons.psychology_alt_outlined,
    color: Color(0xFF6E90C5),
  ),
];

const homeDemoRecent = [
  RecentActivityItem(
    title: 'Medical team dispatched to Dharavi',
    subtitle: '12 people assisted · Confirmed',
    timeAgo: '2m ago',
    icon: Icons.local_hospital_outlined,
  ),
  RecentActivityItem(
    title: 'Food supply allocated in Govandi',
    subtitle: '85 ration kits distributed',
    timeAgo: '18m ago',
    icon: Icons.inventory_2_outlined,
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

  return firestore.collection(FirestorePaths.needs).limit(20).snapshots().map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return homeDemoRecent;
    }

    final items = snapshot.docs.map((doc) {
      final need = NeedModel.fromMap(doc.id, doc.data());
      final icon = _categoryVisual(need.category).icon;
      return RecentActivityItem(
        title: '${_toTitleCase(need.category)} need reported in ${need.location}',
        subtitle: '${need.peopleAffected} people affected · ${_toTitleCase(need.status)}',
        timeAgo: _timeAgo(doc.data()['updatedAt']),
        icon: icon,
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
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'General';
  }

  final first = normalized.substring(0, 1).toUpperCase();
  final rest = normalized.substring(1).toLowerCase();
  return '$first$rest';
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
  if (diff.inMinutes < 1) {
    return 'now';
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
