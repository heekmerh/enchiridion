import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exam_module.dart';
import '../models/question.dart';

class ExamPrepRepository {
  static const String assetPath = 'assets/data/exam_prep_questions.json';

  /// Loads the question bank, filtered to [module]. The bundled bank predates
  /// modules so every question defaults to PLAB; filtering keeps each
  /// module's serve log, reviews, and stats cleanly separated once more
  /// banks ship.
  Future<List<Question>> loadQuestions(
      {String module = kPlabModuleId}) async {
    final raw = await rootBundle.loadString(assetPath);
    return parseNormalizedJson(raw, module: module);
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
          questionText: (normalizedList[i] as Map<String, dynamic>)['question']
              .toString(),
          options: {
            for (final entry in ((normalizedList[i]
                    as Map<String, dynamic>)['options'] as Map<String, dynamic>)
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
