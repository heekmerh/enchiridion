import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exam_module.dart';
import '../models/question.dart';
import 'diagnostics_log.dart';

class ExamPrepRepository {
  static const String assetPath = 'assets/data/exam_prep_questions.json';

  // The bundled bank is ~1.1MB / 493 questions: loading + jsonDecode-ing it
  // was previously repeated on every call (every bubble tap, every home
  // screen open), which read as a UI freeze while the spinner couldn't even
  // animate. Parsed once per process and reused — safe because the asset is
  // immutable for the lifetime of the app.
  static Future<List<Question>>? _cachedBank;

  /// Loads the question bank, filtered to [module]. The bundled bank predates
  /// modules so every question defaults to PLAB; filtering keeps each
  /// module's serve log, reviews, and stats cleanly separated once more
  /// banks ship.
  Future<List<Question>> loadQuestions({String module = kPlabModuleId}) async {
    final cacheHit = _cachedBank != null;
    final bank = await (_cachedBank ??= _loadBank());
    if (cacheHit) {
      DiagnosticsLog.event('bank_cache_hit', {'module': module});
    }
    return bank.where((question) => question.module == module).toList();
  }

  Future<List<Question>> _loadBank() async {
    final stopwatch = Stopwatch()..start();
    DiagnosticsLog.start('bank_parse');
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((item) => Question.fromJson(item as Map<String, dynamic>))
          .toList();
      DiagnosticsLog.end('bank_parse', {
        'ms': stopwatch.elapsedMilliseconds,
        'count': parsed.length,
      });
      return parsed;
    } catch (e) {
      DiagnosticsLog.error('bank_parse', e);
      // Don't cache a failed load — a transient asset-bundle hiccup
      // shouldn't permanently break every future call in this process.
      _cachedBank = null;
      rethrow;
    }
  }

  static List<Question> parseNormalizedJson(String raw,
      {String module = kPlabModuleId}) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .where((question) => question.module == module)
        .toList();
  }

  static List<Question> normalizeLegacySource(String raw) {
    final trimmed = raw.trim();
    final normalizedList = _splitJsonObjects(trimmed.substring(1))
        .map((item) =>
            jsonDecode(_repairJsonObjectText(item)) as Map<String, dynamic>)
        .toList();
    return [
      for (int i = 0; i < normalizedList.length; i++)
        Question(
          id: 'exam-${(i + 1).toString().padLeft(4, '0')}',
          questionText: normalizedList[i]['question'].toString(),
          options: {
            for (final entry
                in (normalizedList[i]['options'] as Map<String, dynamic>)
                    .entries)
              entry.key.toLowerCase(): entry.value.toString(),
          },
          correctOption: (normalizedList[i]['answer'] as String).toLowerCase(),
          explanation: normalizedList[i]['explanation'].toString(),
          osceTip: normalizedList[i]['osce_tip'] as String?,
          questionNumber: i + 1,
          topic: normalizedList[i]['topic'] as String?,
          module: normalizedList[i]['module'] as String? ?? kPlabModuleId,
        ),
    ];
  }

  static List<String> _splitJsonObjects(String raw) {
    final objects = <String>[];
    var depth = 0;
    var inString = false;
    var escaped = false;
    int? startIndex;

    for (var index = 0; index < raw.length; index++) {
      final char = raw[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        if (depth == 0) startIndex = index;
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0 && startIndex != null) {
          objects.add(raw.substring(startIndex, index + 1));
          startIndex = null;
        }
      }
    }

    return objects;
  }

  static String _repairJsonObjectText(String raw) {
    return raw
        .replaceAllMapped(
          RegExp(
            r'(\}|\]|"(?:[^"\\]|\\.)*"|\d+|true|false|null)(\s*\n\s*)"([A-Za-z_]+)"\s*:',
            multiLine: true,
          ),
          (match) => '${match.group(1)},${match.group(2)}"${match.group(3)}":',
        )
        .replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
  }
}
