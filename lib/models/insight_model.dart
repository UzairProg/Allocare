import 'package:cloud_firestore/cloud_firestore.dart';

class InsightModel {
  const InsightModel({
    required this.id,
    required this.title,
    required this.score,
    required this.recommendation,
    this.ngoId,
  });

  final String id;
  final String title;
  final double score;
  final String recommendation;
  final String? ngoId;

  factory InsightModel.fromMap(String id, Map<String, dynamic> map) {
    return InsightModel(
      id: id,
      title: (map['title'] as String?) ?? 'Underserved Areas Detected',
      score: _toDouble(map['score']),
      recommendation:
          (map['recommendation'] as String?) ??
          'Focus interventions in high-need localities.',
      ngoId:
          _readOptionalString(map, 'ngoId') ??
          _readOptionalString(map, 'ngo_id'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'score': score,
      'recommendation': recommendation,
      if (ngoId != null && ngoId!.trim().isNotEmpty) 'ngoId': ngoId,
      'updatedAt': Timestamp.now(),
    };
  }

  static double _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static String? _readOptionalString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}
