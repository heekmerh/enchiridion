import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Play's Payments policy forbids steering Play users to other checkouts, including indirectly through help or account flows.
const _forbiddenPatterns = [
  'flutterwave_standard',
  'FLWPUBK',
  'payments/flutterwave',
  'enchiridion.site/app/subscribe',
  'enchiridion.site/premium',
  'enchiridion.site/account',
  'checkout.flutterwave',
];
const _policyFile = 'lib/config/purchasing_policy.dart';

void main() {
  test('the app contains no external checkout or website purchase route', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path == _policyFile) continue;
      final source = file.readAsStringSync().toLowerCase();
      for (final pattern in _forbiddenPatterns) {
        if (source.contains(pattern.toLowerCase())) {
          offenders.add('${file.path}: $pattern');
        }
      }
    }

    expect(offenders, isEmpty);
  });

  test('the Flutterwave in-app checkout package is no longer a dependency', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        isNot(contains('flutterwave')));
  });
}
