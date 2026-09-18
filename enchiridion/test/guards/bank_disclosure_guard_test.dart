// Repo-wide guard: fails the suite if any `lib/` source line discloses a
// question-bank total or an ordinal question range to the user.
//
// This gate asserts one invariant only: no inventory figure reaches the
// user. It does not widen to sibling-owned phrasing (browse-feature
// wording, question-number labels).
//
// Scans `lib/` only — never `test/` — because the pattern literals used to
// detect a violation live in this very file, and scanning `test/` would
// make the gate permanently fail for the wrong reason.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _bankTotalInterpolation = RegExp(r'\$\{[^}]*uestions\.length');
final _ordinalRangeCopy = RegExp(r'[Qq]uestions?\s+\d+\s*[-–]');

class _Violation {
  final String path;
  final int lineNumber;
  final String match;

  _Violation(this.path, this.lineNumber, this.match);

  @override
  String toString() => '$path:$lineNumber — "$match"';
}

List<_Violation> _scanLib() {
  final violations = <_Violation>[];
  final libDir = Directory('lib');

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//')) continue;

      final bankTotalMatch = _bankTotalInterpolation.firstMatch(line);
      if (bankTotalMatch != null) {
        violations.add(_Violation(file.path, i + 1, bankTotalMatch.group(0)!));
      }

      final ordinalMatch = _ordinalRangeCopy.firstMatch(line);
      if (ordinalMatch != null) {
        violations.add(_Violation(file.path, i + 1, ordinalMatch.group(0)!));
      }
    }
  }

  return violations;
}

void main() {
  test('no lib/ source line discloses a bank total or ordinal range', () {
    final violations = _scanLib();

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Bank-size disclosure found:\n'
              '${violations.map((v) => v.toString()).join('\n')}',
    );
  });
}
