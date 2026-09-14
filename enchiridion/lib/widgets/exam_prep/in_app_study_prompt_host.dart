import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/question.dart';
import '../../models/resource_topic.dart';
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
    if (payload.scope != kStandaloneExamPrepScope) return;
    await _ensureBankLoaded();
    if (!mounted) return;

    Question? question;
    for (final candidate in _questions) {
      if (candidate.id == payload.questionId) {
        question = candidate;
        break;
      }
    }
    if (question == null) return;

    final storage = context.read<StorageService>();
    final review = storage.getQuestionReviews(payload.scope)[question.id];
    final optionSeed = Object.hash(question.id, review?.attempts ?? 0);

    rootNavigatorKey.currentState?.push(
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
