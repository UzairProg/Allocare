import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService.fromEnvironment();
});

class GeminiService {
  GeminiService({required String apiKey, String modelName = 'gemini-2.0-flash'})
    : _apiKey = apiKey.trim(),
      _modelName = modelName {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Missing Gemini API key. Provide GEMINI_API_KEY (or GOOGLE_API_KEY) via --dart-define or --dart-define-from-file=.env.json',
      );
    }
  }

  static String resolveApiKey({String? fallbackApiKey}) {
    const geminiKey = String.fromEnvironment('GEMINI_API_KEY');
    const googleKey = String.fromEnvironment('GOOGLE_API_KEY');
    const genericKey = String.fromEnvironment('API_KEY');

    final candidates = [geminiKey, googleKey, genericKey, fallbackApiKey ?? ''];
    for (final candidate in candidates) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return '';
  }

  static bool get hasApiKey => resolveApiKey().isNotEmpty;

  static String resolveModelName({String? fallbackModelName}) {
    const modelFromDefine = String.fromEnvironment('GEMINI_MODEL');
    if (modelFromDefine.trim().isNotEmpty) {
      return modelFromDefine.trim();
    }

    final fallback = (fallbackModelName ?? '').trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }

    return 'gemini-2.0-flash';
  }

  factory GeminiService.fromEnvironment({
    String? fallbackApiKey,
    String modelName = 'gemini-2.0-flash',
  }) {
    final resolvedKey = resolveApiKey(fallbackApiKey: fallbackApiKey);
    final resolvedModel = resolveModelName(fallbackModelName: modelName);

    return GeminiService(apiKey: resolvedKey, modelName: resolvedModel);
  }

  final String _apiKey;
  final String _modelName;

  String get modelName => _modelName;

  List<String> _candidateModels() {
    final candidates = [
      _modelName,
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash-latest',
      'gemini-1.5-flash',
    ];

    final seen = <String>{};
    final ordered = <String>[];
    for (final candidate in candidates) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      ordered.add(trimmed);
    }
    return ordered;
  }

  Future<String> generateStructuredReport(String input) async {
    final source = input.trim();
    if (source.isEmpty) {
      throw ArgumentError('Input cannot be empty.');
    }

    final prompt =
        '''
You are an emergency-intel parser.
Convert the raw field input into a clean structured report.

Return strict JSON with these keys:
- title
- category (Must be strictly one of: medical, fire, police, accident, infrastructure, natural_disaster, other. Do NOT append "emergency")
- subcategory (e.g. "Other Medical care", "Traffic Collision", etc)
- urgency (low, medium, high)
- urgency_score (1 to 5)
- location (city/address name)
- latitude (double, you MUST provide an estimated latitude for the location)
- longitude (double, you MUST provide an estimated longitude for the location)
- description
- peopleAffected (integer)
- contactName
- contactPhone
- summary

  Return ONLY a single valid JSON object.
  Do not add markdown code fences.
  Do not add explanations before or after the JSON.

Raw input:
$source
''';

    final response = await _generateWithModelFallback(
      (model) => model.generateContent([Content.text(prompt)]),
    );

    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }

    return _normalizeJsonObject(text, sourceLabel: 'text parse');
  }

  Future<String> generateStructuredReportFromBinary({
    required Uint8List fileBytes,
    required String mimeType,
    required String fileName,
    String? contextText,
  }) async {
    if (fileBytes.isEmpty) {
      throw ArgumentError('File bytes cannot be empty.');
    }

    final context = (contextText ?? '').trim();
    final prompt =
        '''
You are an emergency-intel parser.
Analyze the attached file and extract incident details.

The file may be a scanned PDF or an image. Perform OCR if needed.

Return strict JSON with these keys:
- title
- category (Must be strictly one of: medical, fire, police, accident, infrastructure, natural_disaster, other. Do NOT append "emergency")
- subcategory (e.g. "Other Medical care", "Traffic Collision", etc)
- urgency (low, medium, high)
- urgency_score (1 to 5)
- location (city/address name)
- latitude (double, you MUST provide an estimated latitude for the location)
- longitude (double, you MUST provide an estimated longitude for the location)
- description
- peopleAffected (integer)
- contactName
- contactPhone
- summary

Return ONLY a single valid JSON object.
Do not add markdown code fences.
Do not add explanations before or after the JSON.

File name: $fileName
MIME type: $mimeType
${context.isEmpty ? '' : 'Context metadata:\n$context'}
''';

    final response = await _generateWithModelFallback(
      (model) => model.generateContent([
        Content.multi([TextPart(prompt), DataPart(mimeType, fileBytes)]),
      ]),
    );

    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError(
        'Gemini returned an empty response for binary file input.',
      );
    }

    return _normalizeJsonObject(text, sourceLabel: 'binary parse');
  }

  Future<GenerateContentResponse> _generateWithModelFallback(
    Future<GenerateContentResponse> Function(GenerativeModel model) request,
  ) async {
    Object? lastError;

    for (final candidateModel in _candidateModels()) {
      final model = GenerativeModel(
        model: candidateModel,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );

      try {
        return await request(model);
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError(
      'Gemini request failed for all candidate models (${_candidateModels().join(', ')}): $lastError',
    );
  }

  String _normalizeJsonObject(String raw, {required String sourceLabel}) {
    final cleaned = _stripCodeFence(raw).trim();
    final candidates = <String>[];

    if (cleaned.isNotEmpty) {
      candidates.add(cleaned);
    }

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      candidates.add(cleaned.substring(firstBrace, lastBrace + 1));
    }

    candidates.addAll(_extractBalancedJsonObjects(cleaned));

    for (final candidate in candidates) {
      final normalized = _removeTrailingCommas(candidate).trim();
      try {
        final decoded = jsonDecode(normalized);
        if (decoded is Map<String, dynamic>) {
          return jsonEncode(decoded);
        }
      } catch (_) {
        // Keep trying other extracted candidates.
      }
    }

    final preview = cleaned.length > 220
        ? '${cleaned.substring(0, 220)}...'
        : cleaned;
    throw FormatException(
      'Gemini returned non-JSON output ($sourceLabel). Preview: $preview',
    );
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

  List<String> _extractBalancedJsonObjects(String input) {
    final objects = <String>[];
    var depth = 0;
    var start = -1;
    var inString = false;
    var escaped = false;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];

      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == r'\\') {
          escaped = true;
          continue;
        }
        if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }

      if (ch == '{') {
        if (depth == 0) {
          start = i;
        }
        depth++;
        continue;
      }

      if (ch == '}') {
        if (depth == 0) {
          continue;
        }

        depth--;
        if (depth == 0 && start >= 0) {
          objects.add(input.substring(start, i + 1));
          start = -1;
        }
      }
    }

    return objects;
  }

  String _removeTrailingCommas(String input) {
    return input.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
  }

  String _extractLikelyJson(String raw) {
    final trimmed = raw.trim();
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return trimmed.substring(firstBrace, lastBrace + 1);
    }
    return trimmed;
  }
}
