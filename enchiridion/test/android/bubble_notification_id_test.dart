import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the native notification identity, which Dart cannot exercise
/// directly. Every Study Buddy prompt used to be posted under one constant id,
/// so a newly posted prompt silently replaced the one the user was still
/// answering; the PendingIntent request code was a 32-bit string hash, which
/// can collide across question ids and (with FLAG_UPDATE_CURRENT) deliver the
/// wrong question's extras.
void main() {
  const plugin =
      'android/app/src/main/kotlin/com/example/enchiridion/BubblePlugin.kt';

  String source() =>
      File('${Directory.current.path}/$plugin').readAsStringSync();

  test('prompts are posted under a per-question notification id', () {
    final native = source();

    expect(native, contains('fun quickCheckNotificationId('));
    expect(native, contains('notificationManager.notify(notificationId'));
    // A single shared constant is what made prompts overwrite each other.
    expect(native, isNot(contains('NOTIFICATION_ID')));
  });

  test('the PendingIntent request code is the same stable per-question id', () {
    // It must be the derived id, not a raw string hash: hash collisions
    // cross-wire two questions' extras under FLAG_UPDATE_CURRENT. (The
    // derivation itself keeps a hash fallback for ids outside the bank's
    // `exam-NNNN` shape, which is why this checks the call site, not the file.)
    expect(
      source(),
      matches(RegExp(
        r'PendingIntent\.getActivity\(\s*context,\s*notificationId,',
      )),
    );
  });

  test('dismissing a window cancels only its own prompt', () {
    final native = source();

    expect(
      native,
      matches(RegExp(
        r'"dismissBubble"\s*->\s*\{[\s\S]*?call\.argument<String>\("questionId"\)',
      )),
    );
    expect(
      native,
      matches(RegExp(
        r'cancel\(quickCheckNotificationId\(questionId\)\)',
      )),
    );

    // The Dart side must actually send the id, or every dismissal becomes a
    // no-op and prompts pile up in the shade.
    final dart =
        File('${Directory.current.path}/lib/bubble_main.dart').readAsStringSync();
    expect(
      dart,
      matches(RegExp(
        r"invokeMethod<void>\('dismissBubble',\s*\{\s*'questionId': questionId,",
      )),
    );
  });
}
