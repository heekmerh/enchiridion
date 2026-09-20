import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/exam_module.dart';
import '../../models/question.dart';
import '../../navigation/app_navigator.dart';
import '../../services/exam_prep_repository.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../screens/question_screen.dart';

/// Listens for taps on background "Quick Check" notifications and opens the
/// tapped question.
///
/// Ambient prompting itself (picking a question and surfacing it roughly
/// every 18-35 minutes) now happens entirely outside the running Flutter
/// app, via a periodic Android alarm that posts a bubble/notification
/// directly (see `lib/services/bubble_alarm_callback.dart`) — nothing here
/// runs a timer or shows anything unprompted while the app is open. This
/// widget only exists to catch the case where Bubbles aren't
/// available/allowed on a device and `BubbleNotifier.showBubble` falls back
/// to a plain notification instead: tapping that still needs somewhere to
/// land.
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
    super.dispose();
  }

  Future<void> _ensureBankLoaded() async {
    if (_loadedBank) return;
    _questions = await _repository.loadQuestions();
    _loadedBank = true;
  }

  /// Opens the question a background notification was tapped for.
  ///
  /// Pushed on [rootNavigatorKey] rather than this widget's own context:
  /// this State sits in [MaterialApp.builder], a position *above* the
  /// Navigator that `builder` constructs (its `child` parameter), so
  /// `Navigator.of(context)` from here throws "no Navigator found". Reading
  /// providers is unaffected by that — [MultiProvider] is still an ancestor
  /// either way — so `context.read` below is fine.
  Future<void> _openTappedQuestion(NotificationTapPayload payload) async {
    if (!isExamPrepScope(payload.scope)) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    // Captured before any await: `navigator.context` must not be reached
    // across the bank load below.
    final messenger = ScaffoldMessenger.of(navigator.context);

    // Push a loading screen synchronously so the tap gives instant feedback.
    // Previously the question bank loaded first with nothing on screen,
    // which read as a hung app when the load was slow.
    navigator.push(
      MaterialPageRoute(builder: (_) => const _QuestionLoadingScreen()),
    );

    try {
      await _ensureBankLoaded();
    } catch (error) {
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
