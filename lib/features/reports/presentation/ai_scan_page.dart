import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
  int? _selectedFileBytes;
  Uint8List? _selectedFileData;
  String? _selectedFileMimeType;
  String? _selectedRawInput;
  bool _isAnalyzing = false;
  Map<String, String>? _previewFields;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
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
      _selectedFileBytes = file.size;
      _selectedFileData = file.bytes;
      _selectedFileMimeType = _mimeTypeForExtension(file.extension);
      _selectedRawInput = parsedInput;
      _previewFields = null;
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
    final borderColor = Colors.grey.shade200;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
        title: const Text(
          'AI Intel Scan',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            _PreviewCard(
              borderColor: borderColor,
              selectedFileName: _selectedFileName,
              selectedFileBytes: _selectedFileBytes,
              selectedFileData: _selectedFileData,
              selectedFileMimeType: _selectedFileMimeType,
              isAnalyzing: _isAnalyzing,
              pulseController: _pulseController,
            ),
            const SizedBox(height: 12),
            _ActionPanel(
              borderColor: borderColor,
              isAnalyzing: _isAnalyzing,
              hasSelection: _selectedFileName != null,
              onPickFile: _pickSourceFile,
              onRunParse: _runGeminiExtraction,
            ),
            if (_previewFields != null) ...[
              const SizedBox(height: 12),
              _StructuredPreviewCard(
                borderColor: borderColor,
                fields: _previewFields!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.borderColor,
    required this.selectedFileName,
    required this.selectedFileBytes,
    required this.selectedFileData,
    required this.selectedFileMimeType,
    required this.isAnalyzing,
    required this.pulseController,
  });

  final Color borderColor;
  final String? selectedFileName;
  final int? selectedFileBytes;
  final Uint8List? selectedFileData;
  final String? selectedFileMimeType;
  final bool isAnalyzing;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final isImage =
        selectedFileData != null &&
        selectedFileMimeType != null &&
        selectedFileMimeType!.startsWith('image/');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: Container(
        key: ValueKey<String>(selectedFileName ?? 'empty-preview'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Asset Preview',
                style: TextStyle(
                  color: Color(0xFF202124),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isImage)
                        Image.memory(selectedFileData!, fit: BoxFit.cover)
                      else
                        Container(
                          color: const Color(0xFFF8F9FA),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 48,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                      if (selectedFileName == null)
                        const Center(
                          child: Text(
                            'No file selected',
                            style: TextStyle(
                              color: Color(0xFF5F6368),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (isImage && isAnalyzing)
                        Center(
                          child: AnimatedBuilder(
                            animation: pulseController,
                            builder: (context, child) {
                              final value = pulseController.value;
                              final scale = 0.4 + (value * 1.5);
                              final opacity = (1 - value) * 0.32;
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(
                                      0xFF1A73E8,
                                    ).withValues(alpha: opacity),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (isAnalyzing)
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(minHeight: 5),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                selectedFileName ?? 'Pick a file to begin AI processing.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF202124),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (selectedFileBytes != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$selectedFileBytes bytes',
                  style: const TextStyle(
                    color: Color(0xFF5F6368),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.borderColor,
    required this.isAnalyzing,
    required this.hasSelection,
    required this.onPickFile,
    required this.onRunParse,
  });

  final Color borderColor;
  final bool isAnalyzing;
  final bool hasSelection;
  final VoidCallback onPickFile;
  final VoidCallback onRunParse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              onPressed: isAnalyzing ? null : onPickFile,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Pick File'),
            ),
            FilledButton.tonalIcon(
              onPressed: (!hasSelection || isAnalyzing) ? null : onRunParse,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(isAnalyzing ? 'Processing...' : 'Run AI Parse'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StructuredPreviewCard extends StatelessWidget {
  const _StructuredPreviewCard({
    required this.borderColor,
    required this.fields,
  });

  final Color borderColor;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Structured Preview',
              style: TextStyle(
                color: Color(0xFF202124),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in fields.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(
                  color: Color(0xFF5F6368),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.value,
                style: const TextStyle(
                  color: Color(0xFF202124),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
