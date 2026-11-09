class Bookmark {
  final String id;
  final String chapterId;
  final int createdAt;
  final String name;
  final double scrollProgress; // 0.0 to 1.0

  const Bookmark({
    required this.id,
    required this.chapterId,
    required this.createdAt,
    required this.name,
    required this.scrollProgress,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      createdAt: json['createdAt'] as int,
      name: json['name'] as String,
      scrollProgress: (json['scrollProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterId': chapterId,
      'createdAt': createdAt,
      'name': name,
      'scrollProgress': scrollProgress,
    };
  }
}
