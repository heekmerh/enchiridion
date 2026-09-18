import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\r\n]*'), '');

void main() {
  const nativeDirectory = 'android/app/src/main/kotlin/com/example/enchiridion';
  final cases = <({String nativeFile, String function, RegExp libraryCall})>[
    (
      nativeFile: '$nativeDirectory/BubbleAlarmWorker.kt',
      function: 'bubbleAlarmCallback',
      libraryCall: RegExp(
        r'DartEntrypoint\(\s*appBundlePath,\s*"(package:enchiridion/[^"\s]+\.dart)",\s*"bubbleAlarmCallback"',
      ),
    ),
    (
      nativeFile: '$nativeDirectory/BubbleActivity.kt',
      function: 'bubbleMain',
      libraryCall: RegExp(
        r'getDartEntrypointLibraryUri\(\):\s*String\s*=\s*"(package:enchiridion/[^"\s]+\.dart)"',
      ),
    ),
  ];

  for (final entry in cases) {
    test('${entry.function} names its declaring Dart library', () {
      final native = _withoutComments(
        File('${Directory.current.path}/${entry.nativeFile}')
            .readAsStringSync(),
      );
      final match = entry.libraryCall.firstMatch(native);
      expect(match, isNotNull);

      final uri = match!.group(1)!;
      final dartPath = uri.replaceFirst('package:enchiridion/', 'lib/');
      final dartFile = File('${Directory.current.path}/$dartPath');
      expect(dartFile.existsSync(), isTrue, reason: '$uri must exist');

      final dart = _withoutComments(dartFile.readAsStringSync());
      expect(
        dart,
        matches(RegExp(
          "@pragma\\('vm:entry-point'\\)\\s+void\\s+${entry.function}\\s*\\(",
        )),
      );
      expect(native, contains('"${entry.function}"'));
    });
  }

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
