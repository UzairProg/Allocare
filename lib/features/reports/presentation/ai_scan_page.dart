import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../services/auth_service.dart';
import '../../../services/gemini_service.dart';

class AIScanPage extends ConsumerStatefulWidget {
  const AIScanPage({super.key});

  @override
  ConsumerState<AIScanPage> createState() => _AIScanPageState();
}

class _AIScanPageState extends ConsumerState<AIScanPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  String? _selectedFileName;
  String? _selectedFilePath;
  int? _selectedFileBytes;
  Uint8List? _selectedFileData;
  String? _selectedFileMimeType;
  String? _selectedRawInput;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  Map<String, String>? _previewFields;
  Map<String, dynamic>? _rawDecodedData;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickSourceFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'csv',
        'txt',
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final parsedInput = await _buildRawInputFromFile(file);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFileName = file.name;
      _selectedFilePath = file.path;
      _selectedFileBytes = file.size;
      _selectedFileData = file.bytes;
      _selectedFileMimeType = _mimeTypeForExtension(file.extension);
      _selectedRawInput = parsedInput;
      _previewFields = null;
      _rawDecodedData = null;
    });
  }

  String _mimeTypeForExtension(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }

  bool _isImageMime(String? mimeType) {
    return mimeType != null && mimeType.startsWith('image/');
  }

  bool _shouldUseBinaryFallback(String rawInput, String? mimeType) {
    final lowered = rawInput.toLowerCase();
    final signalsNoText =
        lowered.contains('[binary/non-text file selected]') ||
        lowered.contains('[pdf text extraction returned empty text]') ||
        lowered.contains('[pdf parse failed:');
    final canUseBinary =
        mimeType != null &&
        (mimeType == 'application/pdf' || mimeType.startsWith('image/'));
    return signalsNoText && canUseBinary;
  }

  Future<String> _buildRawInputFromFile(PlatformFile file) async {
    final ext = (file.extension ?? '').toLowerCase();
    final header = [
      'file_name: ${file.name}',
      'file_size_bytes: ${file.size}',
      'file_extension: ${ext.isEmpty ? 'unknown' : ext}',
    ].join('\n');

    if ((ext == 'csv' || ext == 'txt') && file.bytes != null) {
      final text = utf8.decode(file.bytes!, allowMalformed: true).trim();
      if (text.isNotEmpty) {
        final capped = text.length > 12000 ? text.substring(0, 12000) : text;
        return '$header\n\nraw_text:\n$capped';
      }
    }

    if (ext == 'pdf' && file.bytes != null) {
      try {
        final document = PdfDocument(inputBytes: file.bytes!);
        final extractor = PdfTextExtractor(document);
        final extracted = extractor.extractText().trim();
        document.dispose();

        if (extracted.isNotEmpty) {
          final normalized = extracted.replaceAll(RegExp(r'\s+'), ' ').trim();
          final capped = normalized.length > 12000
              ? normalized.substring(0, 12000)
              : normalized;
          return '$header\n\nraw_text:\n$capped';
        }

        return '$header\n\nraw_text: [pdf text extraction returned empty text]';
      } catch (error) {
        return '$header\n\nraw_text: [pdf parse failed: $error]';
      }
    }

    return '$header\n\nraw_text: [binary/non-text file selected]';
  }

  String _stripCodeFence(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }

    final lines = trimmed.split('\n');
    if (lines.length <= 2) {
      return trimmed.replaceAll('```', '').trim();
    }

    final withoutFirst = lines.sublist(1);
    if (withoutFirst.isNotEmpty && withoutFirst.last.trim().startsWith('```')) {
      withoutFirst.removeLast();
    }
    return withoutFirst.join('\n').trim();
  }

  String _extractLikelyJson(String raw) {
    final cleaned = _stripCodeFence(raw).trim();
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return cleaned.substring(firstBrace, lastBrace + 1);
    }
    return cleaned;
  }

  Map<String, String> _toPreviewFields(String geminiOutput) {
    final cleaned = _extractLikelyJson(geminiOutput);

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        return {'Raw AI Output': geminiOutput};
      }
      _rawDecodedData = decoded;

      String read(String key, [String fallback = 'Not provided']) {
        final value = decoded[key];
        if (value == null) {
          return fallback;
        }
        if (value is String) {
          final text = value.trim();
          return text.isEmpty ? fallback : text;
        }
        return value.toString();
      }

      return {
        'Title': read('title'),
        'Category': read('category'),
        'Subcategory': read('subcategory'),
        'Urgency': read('urgency'),
        'Urgency Score': read('urgency_score'),
        'Location': read('location'),
        'People Affected': read('peopleAffected'),
        'Contact Name': read('contactName'),
        'Contact Phone': read('contactPhone'),
        'Summary': read('summary', read('description')),
      };
    } catch (_) {
      return {'Raw AI Output': geminiOutput};
    }
  }

  Future<void> _saveReport() async {
    if (_previewFields == null || _selectedFileName == null) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save reports.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final raw = _rawDecodedData ?? {};

      int peopleAffected = 0;
      try {
        peopleAffected = int.parse(raw['peopleAffected']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0');
      } catch (_) {}

      int urgencyScore = 0;
      try {
        urgencyScore = int.parse(raw['urgency_score']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0');
      } catch (_) {}

      double lat = 0.0;
      try {
        lat = double.parse(raw['latitude']?.toString() ?? '0');
      } catch (_) {}

      double lng = 0.0;
      try {
        lng = double.parse(raw['longitude']?.toString() ?? '0');
      } catch (_) {}

      String rawCategory = (raw['category']?.toString() ?? 'other').toLowerCase();
      String category = 'other';
      if (rawCategory.contains('medical')) category = 'medical';
      else if (rawCategory.contains('fire')) category = 'fire';
      else if (rawCategory.contains('police') || rawCategory.contains('crime')) category = 'police';
      else if (rawCategory.contains('accident')) category = 'accident';
      else if (rawCategory.contains('infrastructure')) category = 'infrastructure';
      else if (rawCategory.contains('natural')) category = 'natural_disaster';

      String subcat = raw['subcategory']?.toString() ?? 'Other';
      if (subcat.isEmpty) subcat = 'Other';

      String formattedLocation = raw['location']?.toString() ?? 'Unknown location';
      if (lat != 0.0 || lng != 0.0) {
        formattedLocation = 'Live location · ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'crisis_type': subcat,
        'description': raw['description']?.toString() ?? '',
        'image_url': '',
        'latitude': lat,
        'location': formattedLocation,
        'locationMode': 'ai_scan',
        'longitude': lng,
        'peopleAffected': peopleAffected,
        'reportedBy': user.uid,
        'status': 'open',
        'subcategory': subcat,
        'supportingDocsMetadata': [
          {
            'fileName': _selectedFileName ?? 'unknown',
            'fileSizeBytes': _selectedFileBytes ?? 0,
            'fileType': _selectedFileMimeType ?? 'unknown',
            'uploadedAt': DateTime.now().toIso8601String(),
          }
        ],
        'title': raw['title']?.toString() ?? 'AI Intel Scan Report',
        'updatedAt': FieldValue.serverTimestamp(),
        'urgency': raw['urgency']?.toString().toLowerCase() ?? 'low',
        'urgency_score': urgencyScore,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report saved to Firebase successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _runGeminiExtraction() async {
    if (_selectedFileName == null ||
        _selectedRawInput == null ||
        _isAnalyzing) {
      return;
    }

    if (!GeminiService.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gemini API key missing. Add GEMINI_API_KEY in .env.json and re-run with --dart-define-from-file=.env.json.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final service = ref.read(geminiServiceProvider);
      final input = _selectedRawInput!;
      final canUseBinaryFallback =
          _shouldUseBinaryFallback(input, _selectedFileMimeType) &&
          _selectedFileData != null;

      final rawResult = canUseBinaryFallback
          ? await service.generateStructuredReportFromBinary(
              fileBytes: _selectedFileData!,
              mimeType: _selectedFileMimeType!,
              fileName: _selectedFileName!,
              contextText: input,
            )
          : await service.generateStructuredReport(input);

      if (!mounted) {
        return;
      }

      setState(() {
        _previewFields = _toPreviewFields(rawResult);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString();
      final lowered = message.toLowerCase();
      final friendlyMessage = lowered.contains('missing gemini_api_key')
          ? 'Gemini API key is not loaded. Run with --dart-define-from-file=.env.json'
          : lowered.contains('model') &&
                (lowered.contains('not found') ||
                    lowered.contains('not supported'))
          ? 'Selected Gemini model is unavailable for this API version. The app will retry supported models; please try again.'
          : lowered.contains('api key') ||
                lowered.contains('api_key') ||
                lowered.contains('unauth') ||
                lowered.contains('forbidden') ||
                lowered.contains('permission') ||
                lowered.contains('401') ||
                lowered.contains('403')
          ? 'Gemini authentication failed. Check your GEMINI_API_KEY value.'
          : lowered.contains('quota') ||
                lowered.contains('rate limit') ||
                lowered.contains('429')
          ? 'Gemini quota/rate limit reached. Please try again later.'
          : 'Gemini parsing failed: $message';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'AI Intel Scan',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _PreviewCard(
                selectedFileName: _selectedFileName,
                selectedFilePath: _selectedFilePath,
                selectedFileBytes: _selectedFileBytes,
                selectedFileData: _selectedFileData,
                selectedFileMimeType: _selectedFileMimeType,
                isAnalyzing: _isAnalyzing,
                pulseController: _pulseController,
              ),
              const SizedBox(height: 24),
              _ActionPanel(
                isAnalyzing: _isAnalyzing,
                hasSelection: _selectedFileName != null,
                onPickFile: _pickSourceFile,
                onRunParse: _runGeminiExtraction,
              ),
              if (_previewFields != null) ...[
                const SizedBox(height: 32),
                _StructuredPreviewCard(
                  fields: _previewFields!,
                  isSaving: _isSaving,
                  onSave: _saveReport,
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.selectedFileName,
    required this.selectedFilePath,
    required this.selectedFileBytes,
    required this.selectedFileData,
    required this.selectedFileMimeType,
    required this.isAnalyzing,
    required this.pulseController,
  });

  final String? selectedFileName;
  final String? selectedFilePath;
  final int? selectedFileBytes;
  final Uint8List? selectedFileData;
  final String? selectedFileMimeType;
  final bool isAnalyzing;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = selectedFileData != null &&
        selectedFileMimeType != null &&
        selectedFileMimeType!.startsWith('image/');
    final hasFile = selectedFileName != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Asset Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (isAnalyzing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final path = selectedFilePath;
                if (path != null) {
                  await OpenFilex.open(path);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: hasFile ? 260 : 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  border: hasFile
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 2,
                        ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImage)
                      Image.memory(selectedFileData!, fit: BoxFit.cover)
                    else if (hasFile)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.8),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              selectedFileName!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (selectedFileBytes != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${(selectedFileBytes! / 1024).toStringAsFixed(1)} KB',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No asset selected',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    
                    if (isAnalyzing) ...[
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                          child: Container(
                            color: Colors.black.withOpacity(0.25),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: pulseController,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment(0, -1.0 + (pulseController.value * 2.0)),
                            child: Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4285F4),
                                    Color(0xFF9B72CB),
                                    Color(0xFFD96570),
                                    Color(0xFFF4B400),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9B72CB).withOpacity(0.8),
                                    blurRadius: 24,
                                    spreadRadius: 6,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF4285F4).withOpacity(0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: _ScanningOverlay(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ),
            if (hasFile && isImage) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.image_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedFileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selectedFileBytes != null)
                    Text(
                      '${(selectedFileBytes! / 1024).toStringAsFixed(1)} KB',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.isAnalyzing,
    required this.hasSelection,
    required this.onPickFile,
    required this.onRunParse,
  });

  final bool isAnalyzing;
  final bool hasSelection;
  final VoidCallback onPickFile;
  final VoidCallback onRunParse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isAnalyzing ? null : onPickFile,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Select Asset'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: (!hasSelection || isAnalyzing) ? null : onRunParse,
            icon: isAnalyzing 
                ? const SizedBox(
                    width: 20, height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : SvgPicture.asset(
                    'assets/gemini.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
            label: Text(
              isAnalyzing ? 'Analyzing...' : 'Analyze',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: hasSelection && !isAnalyzing ? 4 : 0,
              shadowColor: theme.colorScheme.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StructuredPreviewCard extends StatelessWidget {
  const _StructuredPreviewCard({
    required this.fields,
    required this.isSaving,
    required this.onSave,
  });

  final Map<String, String> fields;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF4285F4), Color(0xFF9B72CB)],
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF4285F4), Color(0xFF9B72CB)],
                            ).createShader(bounds),
                            child: Text(
                              'Intelligence Report',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          for (var i = 0; i < fields.entries.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 24,
                                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                              ),
                            _buildFieldRow(theme, fields.entries.elementAt(i).key, fields.entries.elementAt(i).value),
                          ],
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isSaving ? null : onSave,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 20, height: 20, 
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                    )
                                  : const Icon(Icons.cloud_upload_rounded),
                              label: Text(
                                isSaving ? 'Saving...' : 'Save to Firebase',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanningOverlay extends StatefulWidget {
  const _ScanningOverlay();

  @override
  State<_ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<_ScanningOverlay> {
  int _step = 0;
  final List<String> _steps = [
    'Reading raw unstructured data...',
    'Identifying key entities...',
    'Applying AI Intelligence...',
    'Structuring insights...',
  ];

  @override
  void initState() {
    super.initState();
    _cycleSteps();
  }

  Future<void> _cycleSteps() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) break;
      setState(() {
        _step = (_step + 1) % _steps.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B72CB).withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Row(
            key: ValueKey(_step),
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _steps[_step],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
