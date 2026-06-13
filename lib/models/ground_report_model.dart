import 'package:cloud_firestore/cloud_firestore.dart';

class GroundReportModel {
  final String reportId;
  final String missionId;
  final String ngoId;
  final String volunteerId;
  final String volunteerName;
  final String reportType;
  final String audioUrl;
  final String transcript;
  final List<Map<String, dynamic>> supportingImages;
  final Map<String, dynamic> location;
  final Map<String, dynamic> aiAnalysis;
  final String status;
  final String missionStatusAtReportTime;
  final String urgencyAtReportTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroundReportModel({
    required this.reportId,
    required this.missionId,
    required this.ngoId,
    required this.volunteerId,
    required this.volunteerName,
    required this.reportType,
    required this.audioUrl,
    required this.transcript,
    required this.supportingImages,
    required this.location,
    required this.aiAnalysis,
    required this.status,
    required this.missionStatusAtReportTime,
    required this.urgencyAtReportTime,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'missionId': missionId,
      'ngoId': ngoId,
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'reportType': reportType,
      'audioUrl': audioUrl,
      'transcript': transcript,
      'supportingImages': supportingImages,
      'location': location,
      'aiAnalysis': aiAnalysis,
      'status': status,
      'missionStatusAtReportTime': missionStatusAtReportTime,
      'urgencyAtReportTime': urgencyAtReportTime,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory GroundReportModel.fromMap(Map<String, dynamic> map, String id) {
    return GroundReportModel(
      reportId: id,
      missionId: map['missionId'] ?? '',
      ngoId: map['ngoId'] ?? '',
      volunteerId: map['volunteerId'] ?? '',
      volunteerName: map['volunteerName'] ?? '',
      reportType: map['reportType'] ?? 'voice',
      audioUrl: map['audioUrl'] ?? '',
      transcript: map['transcript'] ?? '',
      supportingImages: List<Map<String, dynamic>>.from(map['supportingImages'] ?? []),
      location: Map<String, dynamic>.from(map['location'] ?? {}),
      aiAnalysis: Map<String, dynamic>.from(map['aiAnalysis'] ?? {}),
      status: map['status'] ?? 'draft',
      missionStatusAtReportTime: map['missionStatusAtReportTime'] ?? '',
      urgencyAtReportTime: map['urgencyAtReportTime'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  GroundReportModel copyWith({
    String? reportId,
    String? missionId,
    String? ngoId,
    String? volunteerId,
    String? volunteerName,
    String? reportType,
    String? audioUrl,
    String? transcript,
    List<Map<String, dynamic>>? supportingImages,
    Map<String, dynamic>? location,
    Map<String, dynamic>? aiAnalysis,
    String? status,
    String? missionStatusAtReportTime,
    String? urgencyAtReportTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroundReportModel(
      reportId: reportId ?? this.reportId,
      missionId: missionId ?? this.missionId,
      ngoId: ngoId ?? this.ngoId,
      volunteerId: volunteerId ?? this.volunteerId,
      volunteerName: volunteerName ?? this.volunteerName,
      reportType: reportType ?? this.reportType,
      audioUrl: audioUrl ?? this.audioUrl,
      transcript: transcript ?? this.transcript,
      supportingImages: supportingImages ?? this.supportingImages,
      location: location ?? this.location,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      status: status ?? this.status,
      missionStatusAtReportTime: missionStatusAtReportTime ?? this.missionStatusAtReportTime,
      urgencyAtReportTime: urgencyAtReportTime ?? this.urgencyAtReportTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
