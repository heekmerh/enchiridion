import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/question.dart';
import '../models/question_review.dart';

/// Which question a tapped notification wants opened.
class NotificationTapPayload {
  final String scope;
  final String questionId;

  const NotificationTapPayload({
    required this.scope,
    required this.questionId,
  });
}

/// Schedules the background half of spaced repetition.
///
/// A wrong answer's next-day rebound (see [QuestionReview.relearnInterval])
/// needs to reach the user whether or not the app is open, so every time a
/// review is updated, [scheduleFollowUp] books (or re-books) exactly one
/// local notification for that question's new due time. Tapping it is
/// handled by whoever calls [initialize] and listens on [onQuestionTapped].
///
/// The separate ambient "ask something every 18-35 minutes" prompt is not
/// scheduled here — see `lib/services/bubble_alarm_callback.dart`, which
/// posts those directly as Android bubbles/notifications from a headless
/// alarm rather than through this plugin.
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  static const _channelId = 'exam_prep_review';
  static const _channelName = 'Exam prep reviews';
  static const _channelDescription =
      'Spaced-repetition follow-up questions from Exam Prep.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationTapPayload> _tapped =
      StreamController<NotificationTapPayload>.broadcast();

  bool _initialized = false;

  /// Fires when the user taps a scheduled review notification, including one
  /// that launched the app from a terminated state (see [initialize]).
  Stream<NotificationTapPayload> get onQuestionTapped => _tapped.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (e) {
      // Falls back to whatever default the timezone package ships with
      // (UTC). Scheduled times will be computed correctly relative to now
      // either way; only display-formatted local times would be off, and
      // this service never shows one.
      developer.log('Could not resolve local timezone: $e',
          name: 'NotificationService');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response != null) _handleResponse(response);
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  void _handleResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _tapped.add(NotificationTapPayload(
        scope: data['scope'] as String,
        questionId: data['question_id'] as String,
      ));
    } catch (e) {
      developer.log('Malformed notification payload: $e',
          name: 'NotificationService');
    }
  }

  /// Deterministic per-question id so re-scheduling the same question
  /// replaces its previous pending notification instead of stacking a new
  /// one alongside it.
  int _notificationId(String scope, String questionId) =>
      Object.hash(scope, questionId) & 0x7fffffff;

  /// Books the next background rebound for [question], or clears it once the
  /// question has graduated off the ladder.
  ///
  /// Safe to call after every answer regardless of whether notifications are
  /// available: silently no-ops if [initialize] hasn't succeeded, matching
  /// the rest of this app's "local state is the source of truth, remote
  /// delivery is best-effort" pattern (see `StudyStatsService._sync`).
  Future<void> scheduleFollowUp({
    required String scope,
    required Question question,
    required QuestionReview review,
  }) async {
    if (!_initialized) return;
    final id = _notificationId(scope, question.id);

    if (review.retired) {
      await _plugin.cancel(id: id);
      return;
    }

    final due = tz.TZDateTime.from(review.dueAt, tz.local);
    if (!due.isAfter(tz.TZDateTime.now(tz.local))) return;

    final teaser = notificationTeaser(question.questionText);
    final fullText = notificationFullText(question.questionText);
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: due,
        title: 'Practice Question',
        body: teaser,
        payload: jsonEncode({'scope': scope, 'question_id': question.id}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            // Collapsed view shows the short [teaser]; expanding the
            // notification reveals the full question text. Previously both
            // showed the truncated teaser, so the full question was never
            // visible in the shade.
            styleInformation: BigTextStyleInformation(fullText),
          ),
        ),
        // Avoids requiring the separate SCHEDULE_EXACT_ALARM permission —
        // a study reminder landing a few minutes off schedule is an
        // acceptable trade against a permission prompt most users would
        // decline anyway. The relearn/interval jitter already assumes this
        // much slack.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      developer.log('Could not schedule follow-up: $e',
          name: 'NotificationService');
    }
  }

  Future<void> cancelFollowUp(String scope, String questionId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationId(scope, questionId));
  }
}

/// Truncates a question's text to a length suitable for a notification body.
///
/// Shared by [NotificationService.scheduleFollowUp] and
/// `bubbleAlarmCallback`, which builds the same style of teaser natively for
/// the ambient bubble/notification without going through this plugin.
String notificationTeaser(String questionText) {
  const maxLength = 160;
  final flatText = questionText.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flatText.length > maxLength
      ? '${flatText.substring(0, maxLength)}…'
      : flatText;
}

/// The full, untruncated question text flattened for notification display.
///
/// Used as the *expanded* content (big text / message style) so expanding a
/// notification in the shade reveals the whole question, while the collapsed
/// row keeps showing the short [notificationTeaser].
String notificationFullText(String questionText) {
  return questionText.replaceAll(RegExp(r'\s+'), ' ').trim();
}
