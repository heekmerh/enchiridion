import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/resource_topic.dart';
import 'access_service.dart';
import 'auth_service.dart';
import 'exam_prep_repository.dart';
import 'next_question_selector.dart';
import 'notification_service.dart';
import 'storage_service.dart';

const MethodChannel _bubbleChannel = MethodChannel('enchiridion/bubbles');

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
  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (_) {
    // Already initialized in this isolate — the native side is allowed to
    // keep a headless engine warm across consecutive runs.
  }

  try {
    if (AuthService.currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final hasAccess = await AccessService.instance.hasExamPrepAccess();
      final bank = await ExamPrepRepository().loadQuestions();
      final question = await NextQuestionSelector(storage).next(
        bank: bank,
        hasAccess: hasAccess,
      );

      if (question != null) {
        try {
          await _bubbleChannel.invokeMethod<void>('showBubble', {
            'scope': kStandaloneExamPrepScope,
            'questionId': question.id,
            'title': 'Quick Check',
            'teaser': notificationTeaser(question.questionText),
          });
        } catch (_) {
          // Best-effort, matching the rest of this app's "local state is
          // the source of truth, remote delivery is best-effort" pattern.
        }
      }
    }
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
