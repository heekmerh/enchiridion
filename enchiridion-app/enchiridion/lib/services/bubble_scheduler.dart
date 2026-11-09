import 'package:flutter/services.dart';

import '../models/user_settings.dart';

/// Requests the native ambient prompt chain whenever Android starts the app.
class BubbleScheduler {
  /// Default gap between ambient "Study Buddy" prompts (minutes).
  static const int defaultIntervalMinutes =
      UserSettings.defaultStudyBuddyIntervalMinutes;

  final MethodChannel _channel;

  BubbleScheduler({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('enchiridion/bubbles');

  /// Backwards-compatible startup arm (existing tests call this).
  /// Uses the default 45-minute interval.
  Future<bool> armOnStartup({int? intervalMinutes}) async {
    try {
      await _channel.invokeMethod<void>('armBubbleSchedule', {
        'intervalMinutes': intervalMinutes ?? defaultIntervalMinutes,
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Applies the user's Study Buddy preference: cancels the WorkManager
  /// chain when disabled, otherwise (re-)arms it with the chosen interval.
  /// Uses REPLACE natively (unlike the startup arm's KEEP) so a changed
  /// interval takes effect right away instead of waiting out the previously
  /// enqueued run. Best-effort — never throws.
  Future<bool> applySettings({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    try {
      if (!enabled) {
        await _channel.invokeMethod<void>('cancelBubbleSchedule');
      } else {
        await _channel.invokeMethod<void>('rearmBubbleSchedule', {
          'intervalMinutes': intervalMinutes,
        });
      }
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> cancelSchedule() async {
    try {
      await _channel.invokeMethod<void>('cancelBubbleSchedule');
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
