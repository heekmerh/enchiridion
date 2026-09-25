import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/resource_topic.dart';
import 'access_service.dart';
import 'auth_service.dart';
import 'diagnostics_log.dart';
import 'exam_prep_repository.dart';
import 'next_question_selector.dart';
import 'notification_service.dart';
import 'storage_service.dart';

const MethodChannel _bubbleChannel = MethodChannel('enchiridion/bubbles');
const _logName = 'BubbleAlarm';

@visibleForTesting
Future<bool> probeAccessWithTimeout(
  Future<bool> Function() probe, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    return await Future<bool>.microtask(probe)
        .timeout(timeout, onTimeout: () => false);
  } catch (_) {
    return false;
  }
}

/// Headless entrypoint: run by `BubbleAlarmWorker` (native Kotlin, backed by
/// `WorkManager`) roughly every 18-35 minutes, whether or not the app is
/// running, to post the next ambient "Quick Check" question as an Android
/// bubble/notification (falling back to a plain notification on the native
/// side when Bubbles aren't available).
///
/// Runs in its own Flutter engine and isolate — no [BuildContext], no widget
/// tree, no access to anything the main app engine set up in memory.
/// Everything it needs ([Supabase], [SharedPreferences]) is re-initialized
/// fresh here, the same way `main()` does for the foreground engine.
///
/// Scheduling itself (when this next runs) is entirely the native side's
/// responsibility — this function only needs to signal "done" via
/// `workFinished` when it's finished, not compute or pass along a delay; see
/// `BubbleAlarmWorker.kt`.
@pragma('vm:entry-point')
void bubbleAlarmCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget: BubbleAlarmWorker does not await this callback beyond
  // waiting for the "workFinished" signal sent from within _run().
  _run();
}

Future<void> _run() async {
  await DiagnosticsLog.init('alarm');
  DiagnosticsLog.event('alarm_run_start');
  try {
    var wasInitialized = false;
    try {
      wasInitialized = Supabase.instance.isInitialized;
    } catch (_) {
      // The getter asserts until Supabase has been initialized in debug mode.
    }
    await DiagnosticsLog.track('alarm_supabase_init',
        () => Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey));
    if (wasInitialized) {
      developer.log('outcome=supabase_initialization_reused', name: _logName);
    }

    if (AuthService.currentUser == null) {
      developer.log('outcome=no_signed_in_user', name: _logName);
      DiagnosticsLog.event('alarm_run_end', {'outcome': 'no_signed_in_user'});
      return;
    }

    final prefs = await DiagnosticsLog.track(
        'alarm_storage_load', SharedPreferences.getInstance);
    final storage = StorageService(prefs);
    if (!storage.getSettings().studyBuddyEnabled) {
      developer.log('outcome=study_buddy_disabled', name: _logName);
      DiagnosticsLog.event(
          'alarm_run_end', {'outcome': 'study_buddy_disabled'});
      return;
    }
    AccessService.instance.bindStorage(storage);
    final hasAccess = await DiagnosticsLog.track(
        'alarm_access_probe',
        () => probeAccessWithTimeout(AccessService.instance.hasExamPrepAccess));
    final bank = await DiagnosticsLog.track(
        'alarm_bank_load', () => ExamPrepRepository().loadQuestions());
    final question = await DiagnosticsLog.track(
        'alarm_next_question_selection',
        () => NextQuestionSelector(storage).next(
              bank: bank,
              hasAccess: hasAccess,
            ));

    if (question == null) {
      developer.log('outcome=no_servable_question', name: _logName);
      DiagnosticsLog.event(
          'alarm_run_end', {'outcome': 'no_servable_question'});
      return;
    }

    await DiagnosticsLog.track(
        'alarm_show_bubble',
        () => _bubbleChannel.invokeMethod<void>('showBubble', {
              'scope': kStandaloneExamPrepScope,
              'questionId': question.id,
              'title': 'Practice Question',
              'teaser': notificationTeaser(question.questionText),
              // Collapsed row shows the teaser; the expanded notification
              // shows the full question (see BubblePlugin.showBubble).
              'fullText': notificationFullText(question.questionText),
            }),
        {'questionId': question.id});
    developer.log(
      'outcome=question_handed_to_notification question_id=${question.id}',
      name: _logName,
    );
    DiagnosticsLog.event('alarm_run_end',
        {'outcome': 'question_handed_to_notification', 'ok': true});
  } catch (e, stack) {
    developer.log('outcome=error', name: _logName);
    DiagnosticsLog.error('alarm_run', e, stack);
  } finally {
    try {
      await _bubbleChannel.invokeMethod<void>('workFinished');
    } catch (_) {
      // BubbleAlarmWorker has a bounded timeout and re-arms the next run
      // regardless, so a lost signal here just means this run's engine
      // teardown is delayed, not that the chain stops.
    }
  }
}
