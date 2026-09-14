import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/question.dart';
import 'services/exam_prep_repository.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/exam_prep/quick_check_card.dart';

const MethodChannel _bubbleChannel = MethodChannel('enchiridion/bubbles');

/// Entrypoint for the small Flutter engine hosted inside `BubbleActivity`
/// (native Kotlin) — the window that opens when a user taps a "Quick Check"
/// bubble notification. Set as the Dart entrypoint via
/// `FlutterActivity.getDartEntrypointFunctionName()` on the native side, with
/// the target question encoded in the launch route (see `getInitialRoute()`
/// in `BubbleActivity.kt`).
///
/// Deliberately does not boot the full `EnchiridionApp` shell — no splash
/// screen, no auth gate, no book/bookmark providers. This window only ever
/// needs to show one question and record one answer, so it wires up just
/// enough (`StorageService`, notification rebound scheduling) to do that.
@pragma('vm:entry-point')
void bubbleMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _run();
}

Future<void> _run() async {
  final routeName = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final questionId = Uri.parse(routeName).queryParameters['question'];

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (_) {
    // Already initialized in this isolate/engine.
  }

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // So that answering here still books the same spaced-repetition rebound
  // notification a foreground answer would.
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  Question? question;
  if (questionId != null) {
    final bank = await ExamPrepRepository().loadQuestions();
    for (final candidate in bank) {
      if (candidate.id == questionId) {
        question = candidate;
        break;
      }
    }
  }

  runApp(_BubbleApp(storageService: storageService, question: question));
}

class _BubbleApp extends StatelessWidget {
  final StorageService storageService;
  final Question? question;

  const _BubbleApp({required this.storageService, required this.question});

  void _dismiss() {
    _bubbleChannel.invokeMethod<void>('dismissBubble');
  }

  @override
  Widget build(BuildContext context) {
    return Provider<StorageService>.value(
      value: storageService,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(storageService.getSettings().theme),
        home: question == null
            ? _BubbleUnavailableScreen(onClose: _dismiss)
            : QuickCheckCard(question: question!, onDismiss: _dismiss),
      ),
    );
  }
}

/// Shown when the bubble's target question can no longer be found (e.g. the
/// question bank changed between when the notification was posted and when
/// it was tapped).
class _BubbleUnavailableScreen extends StatelessWidget {
  final VoidCallback onClose;

  const _BubbleUnavailableScreen({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This question is no longer available.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onClose,
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
