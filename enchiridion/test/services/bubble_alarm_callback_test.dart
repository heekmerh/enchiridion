import 'dart:async';

import 'package:enchiridion/services/bubble_alarm_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns a successful access probe', () async {
    expect(await probeAccessWithTimeout(() async => true), isTrue);
  });

  test('returns false when the access probe throws', () async {
    expect(
      await probeAccessWithTimeout(() async => throw StateError('offline')),
      isFalse,
    );
  });

  test('returns false after timeout when the access probe never completes',
      () async {
    final never = Completer<bool>();
    final result = await probeAccessWithTimeout(
      () => never.future,
      timeout: const Duration(milliseconds: 20),
    );
    expect(result, isFalse);
  });
}
