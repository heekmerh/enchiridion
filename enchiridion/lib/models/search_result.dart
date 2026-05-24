class SearchResult {
  final String chapterId;
  final String chapterTitle;
  final String snippet;
  final int matchIndex;

  const SearchResult({
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
    required this.matchIndex,
  });
}
