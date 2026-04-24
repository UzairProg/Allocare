class NgoInventoryItem {
  const NgoInventoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.units,
    required this.progress,
  });

  final String id;
  final String title;
  final String subtitle;
  final String units;
  final double progress;

  factory NgoInventoryItem.fromMap(String id, Map<String, dynamic> map) {
    return NgoInventoryItem(
      id: id,
      title: (map['title'] as String?)?.trim().isNotEmpty ?? false ? (map['title'] as String).trim() : 'Inventory item',
      subtitle: (map['subtitle'] as String?)?.trim() ?? '',
      units: (map['units'] as String?)?.trim().isNotEmpty ?? false ? (map['units'] as String).trim() : '0 units',
      progress: _toProgress(map['progress']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'units': units,
      'progress': progress,
    };
  }

  NgoInventoryItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? units,
    double? progress,
  }) {
    return NgoInventoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      units: units ?? this.units,
      progress: progress ?? this.progress,
    );
  }

  static double _toProgress(Object? value) {
    if (value is double) {
      return value.clamp(0.0, 1.0);
    }
    if (value is num) {
      return value.toDouble().clamp(0.0, 1.0);
    }
    return 0.6;
  }
}