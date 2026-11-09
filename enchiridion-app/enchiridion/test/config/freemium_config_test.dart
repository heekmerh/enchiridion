import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/config/freemium_config.dart';

void main() {
  group('freemium_config', () {
    test('kFreeChapterCount equals 1', () {
      expect(kFreeChapterCount, 1);
    });

    test('gate boundary: index 0 is free, index 1 is locked', () {
      // Chapter at index 0 (Chapter 1) is free — satisfies the gate.
      expect(0 < kFreeChapterCount, isTrue);
      // Chapter at index 1 (Chapter 2) is locked — does NOT satisfy the gate.
      expect(1 < kFreeChapterCount, isFalse);
    });
  });
}
