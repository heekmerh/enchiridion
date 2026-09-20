import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/exam_module.dart';
import 'models/question.dart';
import 'models/resource_topic.dart';
import 'providers/study_stats_provider.dart';
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
  final route = Uri.parse(routeName);
  final questionId = route.queryParameters['question'];
  final scope = route.queryParameters['scope'];

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // So that answering here still books the same spaced-repetition rebound
  // notification a foreground answer would.
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  // Show a loading window immediately and resolve the question off the
  // critical path: previously the whole question bank was loaded before the
  // first frame, leaving a blank screen long enough for Android to report
  // "Enchiridion isn't responding" on slow devices.
  runApp(_BubbleLoader(
    storageService: storageService,
    questionId: questionId,
    scope: scope != null && isExamPrepScope(scope) ? scope : null,
  ));
}

/// Resolves the tapped bubble's question asynchronously behind a loading
/// screen, then hands off to [_BubbleApp] once it is ready.
class _BubbleLoader extends StatefulWidget {
  final StorageService storageService;
  final String? questionId;

  /// Exam scope the question belongs to. Defaults to PLAB's scope for older
  /// notifications posted without one.
  final String? scope;

  const _BubbleLoader(
      {required this.storageService, this.questionId, this.scope});

  @override
  State<_BubbleLoader> createState() => _BubbleLoaderState();
}

class _BubbleLoaderState extends State<_BubbleLoader> {
  Question? _question;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    Question? question;
    final questionId = widget.questionId;
    if (questionId != null) {
      try {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      } catch (_) {
        // Already initialized in this isolate/engine, or unreachable —
        // the question bank itself is a local asset and doesn't need it.
      }
      try {
        final bank = await ExamPrepRepository().loadQuestions();
        for (final candidate in bank) {
          if (candidate.id == questionId) {
            question = candidate;
            break;
          }
        }
      } catch (_) {
        // Falls through to the unavailable screen below.
      }
    }
    if (!mounted) return;
    setState(() {
      _question = question;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(widget.storageService.getSettings().theme),
        home: const Scaffold(
          body: SafeArea(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    return _BubbleApp(
      storageService: widget.storageService,
      question: _question,
      scope: widget.scope ?? kStandaloneExamPrepScope,
    );
  }
}

class _BubbleApp extends StatelessWidget {
  final StorageService storageService;
  final Question? question;
  final String scope;

  const _BubbleApp(
      {required this.storageService,
      required this.question,
      this.scope = kStandaloneExamPrepScope});

  void _dismiss() {
    _bubbleChannel.invokeMethod<void>('dismissBubble');
  }

  @override
  Widget build(BuildContext context) {
    return Provider<StorageService>.value(
      value: storageService,
      child: ChangeNotifierProvider(
        // The card prefers the provider when present (it notifies
        // listeners as well as persisting); it falls back to recording
        // through StudyStatsService directly when it is absent, so an
        // answer here can never again be half-recorded.
        create: (_) => StudyStatsProvider(storageService),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(storageService.getSettings().theme),
          home: question == null
              ? _BubbleUnavailableScreen(onClose: _dismiss)
              : QuickCheckCard(
                  question: question!,
                  scope: scope,
                  onDismiss: _dismiss,
                ),
        ),
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
