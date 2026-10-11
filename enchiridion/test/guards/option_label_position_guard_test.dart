// Guard: in a surface that shuffles option order, the displayed letter must
// be a function of rendered position only. Checks exactly the two surfaces
// that shuffle (question_screen.dart, quick_check_card.dart) —
// exam_prep_home_screen.dart is deliberately absent, it renders sorted keys
// and never shuffles. Scans `lib/` only, never `test/`, since the detection
// literal lives in this file and scanning `test/` would fail for the wrong
// reason.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _subjects = [
  'lib/screens/question_screen.dart',
  'lib/widgets/exam_prep/quick_check_card.dart',
];

class _Violation {
  final String path;
  final int lineNumber;
  final String match;

  _Violation(this.path, this.lineNumber, this.match);

  @override
  String toString() => '$path:$lineNumber — "$match"';
}

List<_Violation> _scanSubjects() {
  final violations = <_Violation>[];
  for (final path in _subjects) {
    final lines = File(path).readAsLinesSync();
    var usesDisplayLabel = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//')) continue;
      if (line.contains('Question.displayLabel(')) usesDisplayLabel = true;
      if (line.contains('toUpperCase')) {
        violations.add(_Violation(path, i + 1, 'toUpperCase'));
      }
    }
    if (!usesDisplayLabel) {
      violations.add(_Violation(path, 0, 'missing Question.displayLabel('));
    }
  }
  return violations;
}

void main() {
  test('shuffling surfaces label options by position, never by key', () {
    final violations = _scanSubjects();

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Option letter derived from key found:\n'
              '${violations.map((v) => v.toString()).join('\n')}',
    );
  });
}
