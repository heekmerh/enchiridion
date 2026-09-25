import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/exam_module.dart';
import 'models/question.dart';
import 'models/resource_topic.dart';
import 'models/user_settings.dart' show ThemeMode;
import 'providers/study_stats_provider.dart';
import 'services/diagnostics_log.dart';
import 'services/exam_prep_repository.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/exam_prep/quick_check_card.dart';

const MethodChannel _bubbleChannel = MethodChannel('enchiridion/bubbles');

/// Route prefix `BubblePlugin.bubbleActivityIntent` launches `BubbleActivity`
/// with. The question id, scope, and diagnostics directory ride along as query
/// parameters.
const String kBubbleRoutePrefix = '/bubble';

/// Whether [route] is a launch of the one-question bubble window rather than
/// an ordinary app start.
bool isBubbleRoute(String route) => route.startsWith(kBubbleRoutePrefix);

/// Closes this bubble window and clears its own notification.
///
/// [questionId] identifies which prompt to clear: prompts are posted under
/// per-question notification ids, so closing one window must not sweep away a
/// different prompt still waiting in the shade.
void dismissBubbleWindow(String? questionId) {
  _bubbleChannel.invokeMethod<void>('dismissBubble', {
    'questionId': questionId,
  });
}

/// Clears this window's prompt from the shade without closing the window.
///
/// Called once the answer is recorded, so backing out with the system back
/// button (which never reaches [dismissBubbleWindow]) cannot leave a prompt
/// behind for a question that has already been answered.
void clearBubbleNotification(String? questionId) {
  if (questionId == null) return;
  _bubbleChannel.invokeMethod<void>('cancelBubbleNotification', {
    'questionId': questionId,
  });
}

/// Boots the small "answer one question" window hosted inside
/// `BubbleActivity` (native Kotlin) — what opens when a user taps a "Quick
/// Check" bubble notification.
///
/// Reached from `main()`, not from a Dart entrypoint of its own. It used to be
/// a secondary entrypoint (`bubbleMain`, selected natively via
/// `FlutterActivity.getDartEntrypointFunctionName()`), but in release AOT
/// builds that entrypoint never actually started: the engine reported
/// `isExecutingDart=true` while not one statement of Dart ever ran, leaving
/// the window blank forever. `main` is the one entrypoint proven to run in
/// every build, so `BubbleActivity` now launches it and `main()` branches here
/// on [isBubbleRoute]. (The headless alarm callback keeps its own entrypoint —
/// it is invoked through a direct `DartExecutor` call, which does work.)
///
/// Deliberately does not boot the full `EnchiridionApp` shell — no splash
/// screen, no auth gate, no book/bookmark providers. This window only ever
/// needs to show one question and record one answer, so it wires up just
/// enough (`StorageService`, notification rebound scheduling) to do that.
void runBubbleWindow() {
  // Bootstrap the log before anything else, with no platform channel and no
  // await: the native side puts its log directory in the launch route, so
  // this window records its first instruction even if channels in this
  // engine never answer. Wrapped because nothing here may throw — an
  // exception before runApp would leave the window blank with no error
  // handler installed yet, which is indistinguishable from the bug above.
  try {
    DiagnosticsLog.initFromRoute(
        PlatformDispatcher.instance.defaultRouteName, 'bubble');
  } catch (_) {}
  DiagnosticsLog.event('bubble_main_entered');

  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    DiagnosticsLog.error(
        'bubble_flutter_error', details.exceptionAsString(), details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticsLog.error('bubble_uncaught_error', error, stack);
    return false;
  };

  // Separates "loading" from "frozen": this landing before boot_ready means
  // the user is watching a spinner that actually animates. If it never lands,
  // nothing was ever painted.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DiagnosticsLog.event('bubble_first_frame');
  });

  // Show the first frame immediately: every async dependency below has a
  // bounded timeout and a visible error state, so a stalled load can never
  // leave this window on a blank screen forever.
  runApp(const _BubbleLoader());
}

class _BubbleLoader extends StatefulWidget {
  const _BubbleLoader();

  @override
  State<_BubbleLoader> createState() => _BubbleLoaderState();
}

class _BubbleLoaderState extends State<_BubbleLoader> {
  StorageService? _storageService;
  Question? _question;
  String? _scope;
  bool _ready = false;
  String? _error;

  // Kept separately from [_question] so dismissing still cancels the right
  // notification when the question itself could not be resolved.
  String? _questionId;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Fallback only, for a launch whose route carried no log directory.
    // Deliberately never awaited: an earlier version awaited this here, which
    // put a platform-channel round trip in front of the question — the exact
    // kind of gate the rest of this method goes out of its way to avoid.
    // Anything logged before it lands is buffered, not lost.
    unawaited(DiagnosticsLog.init('bubble'));

    String? questionId;
    String? scope;
    try {
      final routeName =
          WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      final route = Uri.tryParse(routeName);
      questionId = route?.queryParameters['question'];
      final rawScope = route?.queryParameters['scope'];
      scope = rawScope != null && isExamPrepScope(rawScope) ? rawScope : null;
    } catch (_) {
      questionId = null;
    }
    _questionId = questionId;
    DiagnosticsLog.event('boot_route_parsed',
        {'questionId': questionId, 'scope': scope});

    // Notification rebound init must never gate the question — especially
    // with the main app engine also alive, its permission flow can stall.
    // Fire-and-forget: by the time the user answers, it is usually ready;
    // if not, scheduleFollowUp safely no-ops.
    unawaited(DiagnosticsLog.track('notification_service_init', () async {
      await NotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 5));
    }).catchError((_) {}));

    // Prefs (theme/storage) and the question bank are independent — load
    // them in parallel so two-engine contention costs max(), not sum().
    Future<StorageService?> storageFuture() {
      return DiagnosticsLog.track('storage_load', () async {
        final prefs = await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 5));
        return StorageService(prefs);
      });
    }

    Future<Question?> questionFuture() {
      return DiagnosticsLog.track('question_lookup', () async {
        if (questionId == null) return null;
        // Local asset only — no Supabase/network needed, so a stalled
        // network can never block this screen.
        final bank = await ExamPrepRepository()
            .loadQuestions()
            .timeout(const Duration(seconds: 8));
        for (final candidate in bank) {
          if (candidate.id == questionId) {
            return candidate;
          }
        }
        return null;
      }, {'questionId': questionId});
    }

    StorageService? storage;
    Question? question;
    String? loadError;
    // Held onto separately (rather than fired fresh in the timeout handler
    // below) so a slow-but-still-running prefs load isn't duplicated —
    // awaiting the same in-flight Future again is free.
    final pendingStorage = storageFuture();
    try {
      final results = await Future.wait([
        pendingStorage,
        questionFuture(),
      ], eagerError: false)
          .timeout(const Duration(seconds: 10));
      storage = results[0] as StorageService?;
      question = results[1] as Question?;
    } on TimeoutException {
      loadError = 'Loading timed out. Check your device and try again.';
      DiagnosticsLog.error('boot_future_wait', 'timeout after 10s');
      // Salvage whichever half finished: a question without prefs can
      // still render once storage arrives on retry; prefs without a
      // question still unlocks the unavailable screen.
      try {
        storage = await pendingStorage.timeout(const Duration(seconds: 2));
        DiagnosticsLog.event('boot_salvage_storage_recovered');
      } catch (e) {
        DiagnosticsLog.event('boot_salvage_storage_failed', {'error': '$e'});
      }
    } catch (e) {
      DiagnosticsLog.error('boot_future_wait', e);
      if (storage == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not load local data. Check storage and try again.';
          _ready = true;
        });
        DiagnosticsLog.event('boot_ready',
            {'hasStorage': false, 'hasQuestion': false, 'error': _error});
        return;
      }
      // Falls through to the unavailable screen below.
    }

    if (!mounted) return;
    setState(() {
      _storageService = storage;
      _question = question;
      _scope = scope ?? kStandaloneExamPrepScope;
      _error = loadError;
      _ready = true;
    });
    DiagnosticsLog.event('boot_ready', {
      'hasStorage': storage != null,
      'hasQuestion': question != null,
      'error': loadError,
    });
  }

  void _dismiss() {
    dismissBubbleWindow(_questionId);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(
            _storageService?.getSettings().theme ?? ThemeMode.light),
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading question…'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final storage = _storageService;
    if (storage == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _BubbleErrorScreen(
          message: _error ?? 'Could not load local data.',
          onRetry: () {
            setState(() {
              _ready = false;
              _error = null;
            });
            _boot();
          },
          onClose: _dismiss,
        ),
      );
    }
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(storage.getSettings().theme),
        home: _BubbleErrorScreen(
          message: _error!,
          onRetry: () {
            setState(() {
              _ready = false;
              _error = null;
            });
            _boot();
          },
          onClose: _dismiss,
        ),
      );
    }
    return _BubbleApp(
      storageService: storage,
      question: _question,
      questionId: _questionId,
      scope: _scope ?? kStandaloneExamPrepScope,
    );
  }
}

class _BubbleApp extends StatelessWidget {
  final StorageService storageService;
  final Question? question;

  /// The question this window was launched for, which survives [question]
  /// failing to resolve — the notification is cancelled by this id.
  final String? questionId;
  final String scope;

  const _BubbleApp(
      {required this.storageService,
      required this.question,
      required this.questionId,
      this.scope = kStandaloneExamPrepScope});

  void _dismiss() {
    dismissBubbleWindow(questionId);
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
                  onAnswerRecorded: () => clearBubbleNotification(questionId),
                ),
        ),
      ),
    );
  }
}

/// Shown when loading itself failed (timeout / storage error): retryable,
/// unlike the "question gone" case below.
class _BubbleErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _BubbleErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

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
                message,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ],
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
