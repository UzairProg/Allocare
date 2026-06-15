import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/smart_allocation_service.dart';
import 'ai_intel_report_screen.dart';

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
    debugPrint('AI Scan Page: Starting file picker...');
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.any, // Use FileType.any for better compatibility on Web
      );
    } catch (e) {
      debugPrint('AI Scan Page: FilePicker error: $e');
    }

    if (!mounted || result == null || result.files.isEmpty) {
      debugPrint('AI Scan Page: Picker cancelled or result empty.');
      return;
    }

    final file = result.files.first;
    debugPrint('AI Scan Page: File selected: ${file.name}, Size: ${file.size}');
    Uint8List? fileBytes = file.bytes;

    // Explicitly check and fallback for bytes on Web using FileReader
    if (kIsWeb && fileBytes == null) {
      debugPrint('AI Scan Page: file.bytes is null on Web. Attempting FileReader fallback...');
      try {
        // file_picker on web usually populates bytes, but some environments/browsers might fail
        // This is a safety fallback for Web environments.
        if (file.bytes == null) {
           // If still null, we might need to rely on the underlying web file object if available
           // but PlatformFile usually handles this. If it's null, it's likely a browser restriction.
           debugPrint('AI Scan Page: Warning - Bytes are still null after picker.');
        }
      } catch (e) {
        debugPrint('AI Scan Page: Fallback error: $e');
      }
    }

    // 1. Update UI immediately with basic file info to show progress/selection
    setState(() {
      _selectedFileName = file.name;
      _selectedFilePath = kIsWeb ? null : file.path;
      _selectedFileBytes = file.size;
      _selectedFileData = fileBytes;
      _selectedFileMimeType = _mimeTypeForExtension(file.extension);
      _rawDecodedData = null;
      _selectedRawInput = 'Initializing analysis...';
    });

    // 2. Perform long-running parse operation in the background
    try {
      final parsedInput = await _buildRawInputFromFile(file);
      if (mounted) {
        setState(() {
          _selectedRawInput = parsedInput;
        });
      }
    } catch (error) {
      debugPrint('AI Scan Page: Error parsing file: $error');
      if (mounted) {
        setState(() {
          _selectedRawInput =
              'File metadata: ${file.name}\nSize: ${file.size} bytes\n\n[Warning: Content extraction failed. AI analysis may be limited to metadata only.]';
        });
      }
    }
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

  // _saveReport was removed as it's now handled by AIIntelReportScreen.

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
            'Gemini API key missing. Please provide it using --dart-define=GEMINI_API_KEY=your_key when building or running the application.',
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

      Map<String, dynamic> decodedResult = {};
      try {
        decodedResult = jsonDecode(rawResult) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Failed to parse Gemini output: $rawResult');
      }

      final locationStr = decodedResult['location']?.toString() ?? 'Unknown location';
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AIIntelReportScreen(
              appLocation: locationStr,
              aiAnalysisResult: {
                'aiData': decodedResult,
                'fileMetadata': {
                  'fileName': _selectedFileName ?? 'unknown',
                  'fileSizeBytes': _selectedFileBytes ?? 0,
                  'fileType': _selectedFileMimeType ?? 'unknown',
                  'uploadedAt': DateTime.now().toIso8601String(),
                },
              },
            ),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _selectedFileName = null;
              _selectedRawInput = null;
              _selectedFileData = null;
              _selectedFileMimeType = null;
              _rawDecodedData = null;
            });
          }
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString();
      final lowered = message.toLowerCase();
      final friendlyMessage = lowered.contains('missing gemini_api_key')
          ? 'Gemini API key is not loaded. Ensure GEMINI_API_KEY is provided via --dart-define.'
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
        child: SingleChildScrollView(
          key: ValueKey('scan_scroll_${_selectedFileName ?? 'empty'}'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              _PreviewCard(
                key: ValueKey('preview_${_selectedFileName ?? 'none'}'),
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
              // Removed _StructuredPreviewCard
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
    super.key,
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
    final isImage =
        selectedFileData != null &&
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
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
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No asset selected',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.7),
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
                              alignment: Alignment(
                                0,
                                -1.0 + (pulseController.value * 2.0),
                              ),
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
                                      color: const Color(
                                        0xFF9B72CB,
                                      ).withOpacity(0.8),
                                      blurRadius: 24,
                                      spreadRadius: 6,
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF4285F4,
                                      ).withOpacity(0.6),
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
                  Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/gemini.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
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

// Removed _StructuredPreviewCard

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
