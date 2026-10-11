/// Cross-surface record of which questions were served most recently.
/// Before this existed, the exam-prep home card, the ambient Quick Check
/// prompt and the question list each rolled their own `Random`, so two
/// surfaces could serve the same question minutes apart. `NextQuestionSelector`
/// reads and writes one shared log instead.
class ServeLog {
  /// Ids most recently served, newest first, capped at [maxRecent].
  final List<String> recent;

  /// Monotonic count of serves. Its parity alternates the selector between
  /// due-review and unseen questions so neither bucket starves the other.
  final int counter;

  static const int maxRecent = 12;

  const ServeLog({required this.recent, required this.counter});

  static const ServeLog empty = ServeLog(recent: <String>[], counter: 0);

  ServeLog record(String questionId) {
    final next = <String>[questionId, ...recent.where((id) => id != questionId)];
    return ServeLog(
      recent: next.length > maxRecent ? next.sublist(0, maxRecent) : next,
      counter: counter + 1,
    );
  }

  factory ServeLog.fromJson(Map<String, dynamic> json) {
    final raw = json['recent'];
    return ServeLog(
      recent: raw is List
          ? raw.map((item) => item.toString()).toList()
          : const <String>[],
      counter: (json['counter'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'recent': recent,
        'counter': counter,
      };
}
