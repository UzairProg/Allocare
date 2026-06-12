import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ground_report_model.dart';
import '../../needs/application/need_submission_service.dart';
import '../data/repositories/ground_report_repository.dart';
import '../../../services/gemini_service.dart';

final groundIntelligenceServiceProvider = Provider<GroundIntelligenceService>((ref) {
  return GroundIntelligenceService(
    repository: ref.watch(groundReportRepositoryProvider),
    uploadService: ref.watch(needSubmissionServiceProvider),
    geminiService: ref.watch(geminiServiceProvider),
  );
});

class GroundIntelligenceService {
  final GroundReportRepository repository;
  final NeedSubmissionService uploadService;
  final GeminiService geminiService;

  GroundIntelligenceService({
    required this.repository,
    required this.uploadService,
    required this.geminiService,
  });

  /// The complete backend pipeline for Voice Report
  Future<String> submitVoiceReport({
    required File audioFile,
    required String missionId,
    required String ngoId,
    required String volunteerId,
    required String volunteerName,
    required String missionStatusAtReportTime,
    required String urgencyAtReportTime,
    List<File>? supportingImages,
  }) async {
    // 1. Upload audio to Cloudinary
    final audioUrl = await uploadService.uploadAudioToCloudinary(audioFile);

    // 2. Upload any supporting images to Cloudinary
    final List<Map<String, dynamic>> uploadedImages = [];
    if (supportingImages != null) {
      for (final image in supportingImages) {
        final imageUrl = await uploadService.uploadImageToCloudinary(image);
        uploadedImages.add({
          'url': imageUrl,
          'uploadedAt': DateTime.now().toIso8601String(),
        });
      }
    }

    // 3. Create ground_reports document with status = "processing"
    final initialReport = GroundReportModel(
      reportId: '', // Will be assigned by repository
      missionId: missionId,
      ngoId: ngoId,
      volunteerId: volunteerId,
      volunteerName: volunteerName,
      reportType: 'voice',
      audioUrl: audioUrl,
      transcript: '',
      supportingImages: uploadedImages,
      location: {},
      aiAnalysis: {},
      status: 'processing',
      missionStatusAtReportTime: missionStatusAtReportTime,
      urgencyAtReportTime: urgencyAtReportTime,
    );

    final reportId = await repository.createReport(initialReport);

    // 4. Send to Gemini for Analysis
    // Read the file bytes to send to Gemini
    final fileBytes = await audioFile.readAsBytes();
    final fileName = audioFile.path.split('/').last;
    
    // Determine mime type loosely based on extension
    String mimeType = 'audio/mp4';
    if (fileName.toLowerCase().endsWith('.m4a')) mimeType = 'audio/m4a';
    if (fileName.toLowerCase().endsWith('.mp3')) mimeType = 'audio/mp3';
    if (fileName.toLowerCase().endsWith('.wav')) mimeType = 'audio/wav';

    try {
      final geminiResponseJson = await geminiService.generateStructuredReportFromBinary(
        fileBytes: fileBytes,
        mimeType: mimeType,
        fileName: fileName,
        contextText: 'This is an emergency intelligence voice report. You MUST include two additional JSON keys in your response: "transcript" (containing the exact transcribed spoken words) and "suggestedResources" (an array of string resources needed based on the report).',
      );

      final Map<String, dynamic> aiData = jsonDecode(geminiResponseJson);

      // Extract specific fields
      final summary = aiData['summary'] ?? '';
      final description = aiData['description'] ?? summary;
      final urgency = aiData['urgency'] ?? 'medium';
      final crisisType = aiData['category'] ?? 'other';
      final estimatedImpact = aiData['peopleAffected'] ?? 0;
      
      double lat = 0.0;
      double lng = 0.0;
      if (aiData['latitude'] != null) lat = double.tryParse(aiData['latitude'].toString()) ?? 0.0;
      if (aiData['longitude'] != null) lng = double.tryParse(aiData['longitude'].toString()) ?? 0.0;
      
      final locationMap = {
        'latitude': lat,
        'longitude': lng,
        'address': aiData['location'] ?? '',
      };

      final aiAnalysisMap = {
        'summary': description,
        'urgency': urgency,
        'estimatedImpact': estimatedImpact,
        'suggestedResources': aiData['suggestedResources'] ?? [],
        'crisisType': crisisType,
        'confidenceScore': 0.95, // Default/placeholder
      };

      // 5. Save Gemini analysis back into ground_reports and update status to submitted
      await repository.updateReport(reportId, {
        'transcript': aiData['transcript'] ?? description, // Gemini might return transcript in description
        'location': locationMap,
        'aiAnalysis': aiAnalysisMap,
        'status': 'submitted',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      // Handle processing failure
      await repository.updateReport(reportId, {
        'status': 'draft', // or failed
        'updatedAt': DateTime.now().toIso8601String(),
        'aiAnalysis': {
          'error': e.toString(),
        }
      });
      throw Exception('Failed to process ground report with AI: $e');
    }

    return reportId;
  }

  /// Analyze evidence before submitting report
  Future<Map<String, dynamic>> analyzeEvidence({
    File? audioFile,
    List<File>? supportingImages,
    required Map<String, dynamic> contextData,
  }) async {
    String audioUrl = '';
    List<Map<String, dynamic>> uploadedImages = [];
    List<Map<String, dynamic>> mediaFiles = [];

    // 1. Cloudinary Uploads & File Bytes for Gemini
    if (audioFile != null) {
      audioUrl = await uploadService.uploadAudioToCloudinary(audioFile);
      final bytes = await audioFile.readAsBytes();
      final fileName = audioFile.path.split('/').last.toLowerCase();
      String mimeType = 'audio/mp4';
      if (fileName.endsWith('.m4a')) mimeType = 'audio/aac';
      if (fileName.endsWith('.mp3')) mimeType = 'audio/mp3';
      if (fileName.endsWith('.wav')) mimeType = 'audio/wav';
      mediaFiles.add({'bytes': bytes, 'mimeType': mimeType});
    }

    if (supportingImages != null) {
      for (final image in supportingImages) {
        final url = await uploadService.uploadImageToCloudinary(image);
        uploadedImages.add({
          'url': url,
          'uploadedAt': DateTime.now().toIso8601String(),
        });
        
        final bytes = await image.readAsBytes();
        final fileName = image.path.split('/').last.toLowerCase();
        String mimeType = 'image/jpeg';
        if (fileName.endsWith('.png')) mimeType = 'image/png';
        if (fileName.endsWith('.webp')) mimeType = 'image/webp';
        mediaFiles.add({'bytes': bytes, 'mimeType': mimeType});
      }
    }

    // 2. Gemini Multimodal Analysis
    final contextText = contextData.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    String aiResponseJson = '{}';
    if (mediaFiles.isNotEmpty) {
      aiResponseJson = await geminiService.analyzeMultimodalEvidence(
        mediaFiles: mediaFiles,
        contextText: contextText,
      );
    }

    final Map<String, dynamic> aiData = jsonDecode(aiResponseJson);

    return {
      'audioUrl': audioUrl,
      'uploadedImages': uploadedImages,
      'aiData': aiData,
    };
  }
}
