class ClipNote {
  final String id;
  final String content;
  final DateTime createdAt;

  const ClipNote({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory ClipNote.fromJson(Map<String, dynamic> json) {
    return ClipNote(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  ClipNote copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
  }) {
    return ClipNote(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
