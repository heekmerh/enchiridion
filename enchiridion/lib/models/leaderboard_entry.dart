/// One row from the `get_leaderboard` RPC (see
/// scripts/sql/999_MASTER_init.sql). `rank` is the row's true position even
/// when the row was only included because [isYou] — a row past the
/// requested limit is still a real rank, not a placeholder.
class LeaderboardEntry {
  final int rank;
  final String displayName;
  final int totalPoints;
  final bool isYou;

  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.totalPoints,
    required this.isYou,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      displayName: json['display_name'] as String,
      totalPoints: (json['total_points'] as num).toInt(),
      isYou: json['is_you'] as bool? ?? false,
    );
  }
}
