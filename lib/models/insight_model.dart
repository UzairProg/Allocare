import 'package:cloud_firestore/cloud_firestore.dart';

class InsightModel {
  const InsightModel({
    required this.id,
    required this.title,
    required this.score,
    required this.recommendation,
  });

  final String id;
  final String title;
  final double score;
  final String recommendation;

  factory InsightModel.fromMap(String id, Map<String, dynamic> map) {
    return InsightModel(
      id: id,
      title: (map['title'] as String?) ?? 'Underserved Areas Detected',
      score: _toDouble(map['score']),
      recommendation:
          (map['recommendation'] as String?) ?? 'Focus interventions in high-need localities.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'score': score,
      'recommendation': recommendation,
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
}
