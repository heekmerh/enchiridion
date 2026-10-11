import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/exam_module.dart';
import '../../models/question.dart';
import '../../navigation/app_navigator.dart';
import '../../services/diagnostics_log.dart';
import '../../services/exam_prep_repository.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../screens/question_screen.dart';

/// Listens for taps on background "Quick Check" notifications and opens the
/// tapped question. Ambient prompting itself runs entirely outside the app
/// via a periodic Android alarm (see `bubble_alarm_callback.dart`); this
/// widget only catches the fallback case where Bubbles aren't
/// available/allowed and a plain notification was posted instead, which
/// still needs somewhere to land on tap.
class InAppStudyPromptHost extends StatefulWidget {
  final Widget child;

  const InAppStudyPromptHost({
    super.key,
    required this.child,
  });

  @override
  State<InAppStudyPromptHost> createState() => _InAppStudyPromptHostState();
}

class _InAppStudyPromptHostState extends State<InAppStudyPromptHost> {
  final ExamPrepRepository _repository = ExamPrepRepository();
  StreamSubscription<NotificationTapPayload>? _tapSubscription;
  List<Question> _questions = const [];
  bool _loadedBank = false;

  // Guards against a rapid double-tap stacking two loading routes / two
  // QuestionScreens while the first tap is still resolving.
  bool _isOpeningQuestion = false;

  // A tap that arrives before the root navigator exists yet (e.g. still on
  // a splash/auth screen) used to be silently dropped. Stashed here and
  // retried until the navigator is up, instead.
  NotificationTapPayload? _pendingPayload;
  Timer? _pendingRetryTimer;
  int _pendingRetryCount = 0;
  static const _maxPendingRetries = 50; // ~15s at 300ms apiece

  @override
  void initState() {
    super.initState();
    // A tap can arrive at any time, including from a terminated-app launch
    // (replayed once at NotificationService.initialize time) before this
    // widget has even loaded the question bank — _openTappedQuestion loads
    // it lazily if needed.
    _tapSubscription = NotificationService.instance.onQuestionTapped
        .listen(_openTappedQuestion);
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    _pendingRetryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = Timer(const Duration(milliseconds: 300), () {
      final payload = _pendingPayload;
      if (payload == null || !mounted) return;
      if (rootNavigatorKey.currentState == null) {
        _pendingRetryCount += 1;
        if (_pendingRetryCount >= _maxPendingRetries) {
          _pendingPayload = null;
          return;
        }
        _scheduleRetry();
        return;
      }
      _pendingPayload = null;
      _pendingRetryCount = 0;
      _openTappedQuestion(payload);
    });
  }

  Future<void> _ensureBankLoaded() async {
    if (_loadedBank) return;
    _questions = await DiagnosticsLog.track(
      'in_app_bank_load',
      () => _repository.loadQuestions().timeout(const Duration(seconds: 8)),
    );
    _loadedBank = true;
  }

  /// Opens the question a background notification was tapped for. Pushed on
  /// [rootNavigatorKey] rather than this widget's own context, which sits
  /// above the Navigator in [MaterialApp.builder] and would throw "no
  /// Navigator found"; `context.read` below is unaffected since
  /// [MultiProvider] is still an ancestor either way.
  Future<void> _openTappedQuestion(NotificationTapPayload payload) async {
    if (!isExamPrepScope(payload.scope)) return;
    if (_isOpeningQuestion) {
      DiagnosticsLog.event(
          'in_app_tap_ignored_double_tap', {'question_id': payload.questionId});
      return;
    }
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      // Splash/auth gate is still up — there's nowhere to push a route yet.
      // Stash the tap and retry shortly rather than dropping it.
      DiagnosticsLog.event(
          'in_app_tap_stashed_no_navigator', {'question_id': payload.questionId});
      _pendingPayload = payload;
      _pendingRetryCount = 0;
      _scheduleRetry();
      return;
    }
    DiagnosticsLog.event(
        'in_app_tap_received', {'question_id': payload.questionId});
    // Captured before any await: `navigator.context` must not be reached
    // across the bank load below.
    final messenger = ScaffoldMessenger.of(navigator.context);

    _isOpeningQuestion = true;
    try {
      // Push a loading screen synchronously so the tap gives instant
      // feedback. Previously the question bank loaded first with nothing on
      // screen, which read as a hung app when the load was slow.
      navigator.push(
        MaterialPageRoute(builder: (_) => const _QuestionLoadingScreen()),
      );

      try {
        await _ensureBankLoaded();
      } catch (error) {
        DiagnosticsLog.error('in_app_bank_load', error);
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not open the question.\n\n$error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!mounted) {
        navigator.pop();
        return;
      }

      Question? question;
      for (final candidate in _questions) {
        if (candidate.id == payload.questionId) {
          question = candidate;
          break;
        }
      }
      if (question == null) {
        DiagnosticsLog.event('in_app_tap_question_not_found',
            {'question_id': payload.questionId});
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('This question is no longer available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final storage = navigator.context.read<StorageService>();
      final review = storage.getQuestionReviews(payload.scope)[question.id];
      final optionSeed = Object.hash(question.id, review?.attempts ?? 0);

      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => QuestionScreen(
            question: question!,
            bookId: payload.scope,
            trackDailyStudyStats: true,
            optionSeed: optionSeed,
            onAnswered: (_) {},
          ),
        ),
      );
      DiagnosticsLog.event(
          'in_app_tap_question_opened', {'question_id': question.id});
    } finally {
      _isOpeningQuestion = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Instant placeholder pushed the moment a notification is tapped, while the
/// question bank loads off the critical path.
class _QuestionLoadingScreen extends StatelessWidget {
  const _QuestionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
