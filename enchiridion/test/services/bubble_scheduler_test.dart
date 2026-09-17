import 'package:enchiridion/services/bubble_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('enchiridion/bubbles');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('every startup reaches the native scheduler', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });

    final scheduler = BubbleScheduler(channel: channel);
    expect(await scheduler.armOnStartup(), isTrue);
    expect(await scheduler.armOnStartup(), isTrue);
    expect(calls, ['armBubbleSchedule', 'armBubbleSchedule']);
  });

  test('platform errors do not prevent startup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });

    expect(await BubbleScheduler(channel: channel).armOnStartup(), isFalse);
  });

  test('missing native plugin does not prevent startup', () async {
    messenger.setMockMethodCallHandler(channel, null);

    expect(await BubbleScheduler(channel: channel).armOnStartup(), isFalse);
  });
}
