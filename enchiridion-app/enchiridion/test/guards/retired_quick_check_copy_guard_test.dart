// Guard: fails if the retired exam-prep label reappears in a non-comment
// `lib/` line. The `QuickCheckCard` class/file identifiers are retained
// internal names and are exempt. Scans `lib/` only, never `test/`, since the
// detection literal lives in this file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _retiredLabel = RegExp(r'quick[\s\-_]?check', caseSensitive: false);

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
      if (line.contains('QuickCheckCard')) continue;
      if (line.contains('quick_check_card')) continue;

      final match = _retiredLabel.firstMatch(line);
      if (match != null) {
        violations.add(_Violation(file.path, i + 1, match.group(0)!));
      }
    }
  }

  return violations;
}

void main() {
  test('no lib/ source line carries the retired exam-prep label', () {
    final violations = _scanLib();

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Retired label found:\n'
              '${violations.map((v) => v.toString()).join('\n')}',
    );
  });
}
