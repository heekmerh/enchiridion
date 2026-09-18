import 'package:flutter/services.dart';

/// Requests the native ambient prompt chain whenever Android starts the app.
class BubbleScheduler {
  final MethodChannel _channel;

  BubbleScheduler({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('enchiridion/bubbles');

  Future<bool> armOnStartup() async {
    try {
      await _channel.invokeMethod<void>('armBubbleSchedule');
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
