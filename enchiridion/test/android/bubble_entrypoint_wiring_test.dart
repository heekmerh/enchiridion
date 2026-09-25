import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\r\n]*'), '');

void main() {
  const nativeDirectory = 'android/app/src/main/kotlin/com/example/enchiridion';

  String read(String path) => _withoutComments(
        File('${Directory.current.path}/$path').readAsStringSync(),
      );

  test('bubbleAlarmCallback names its declaring Dart library', () {
    final native = read('$nativeDirectory/BubbleAlarmWorker.kt');
    final match = RegExp(
      r'DartEntrypoint\(\s*appBundlePath,\s*"(package:enchiridion/[^"\s]+\.dart)",\s*"bubbleAlarmCallback"',
    ).firstMatch(native);
    expect(match, isNotNull);

    final uri = match!.group(1)!;
    final dartPath = uri.replaceFirst('package:enchiridion/', 'lib/');
    final dartFile = File('${Directory.current.path}/$dartPath');
    expect(dartFile.existsSync(), isTrue, reason: '$uri must exist');

    final dart = _withoutComments(dartFile.readAsStringSync());
    expect(
      dart,
      matches(RegExp(
        "@pragma\\('vm:entry-point'\\)\\s+void\\s+bubbleAlarmCallback\\s*\\(",
      )),
    );
    expect(native, contains('"bubbleAlarmCallback"'));
  });

  // Regression guard. Hosting the bubble window on its own secondary Dart
  // entrypoint silently failed in release AOT builds: the engine reported
  // isExecutingDart=true while not one Dart statement ran, so a tapped
  // notification opened a window that stayed blank forever. The default
  // `main` entrypoint is the one proven to run, with main() branching on the
  // launch route instead.
  test('the bubble window rides the default main entrypoint', () {
    final activity = read('$nativeDirectory/BubbleActivity.kt');
    expect(activity, isNot(contains('getDartEntrypointFunctionName')));
    expect(activity, isNot(contains('getDartEntrypointLibraryUri')));

    final main = read('lib/main.dart');
    expect(main, contains('isBubbleRoute'));
    expect(main, contains('runBubbleWindow()'));

    final bubble = read('lib/bubble_main.dart');
    expect(bubble, contains('void runBubbleWindow()'));
    expect(bubble, contains("kBubbleRoutePrefix = '/bubble'"));

    // Both sides must agree on the prefix main() branches on.
    expect(read('$nativeDirectory/BubblePlugin.kt'), contains('"/bubble?'));
  });

  test('startup keeps pending work and worker replaces completed work', () {
    final worker = _withoutComments(
      File('${Directory.current.path}/$nativeDirectory/BubbleAlarmWorker.kt')
          .readAsStringSync(),
    );
    expect(worker, contains('ExistingWorkPolicy.KEEP'));
    expect(worker, contains('ExistingWorkPolicy.REPLACE'));

    final main = _withoutComments(
      File('${Directory.current.path}/lib/main.dart').readAsStringSync(),
    );
    expect(main, isNot(contains('bubble_alarm_armed')));
    expect(main, contains("import 'bubble_main.dart';"));
    expect(main, contains("import 'services/bubble_alarm_callback.dart';"));
  });
}
