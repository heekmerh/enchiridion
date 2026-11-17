enum NotebookEntryKind { text, image }

class NotebookEntry {
  final String id;
  final NotebookEntryKind kind;
  final String content;
  final double position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotebookEntry({
    required this.id,
    required this.kind,
    required this.content,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  static NotebookEntryKind kindFromName(String? name) =>
      name == 'image' ? NotebookEntryKind.image : NotebookEntryKind.text;

  factory NotebookEntry.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return NotebookEntry(
      id: json['id']?.toString() ?? '',
      kind: kindFromName(json['kind']?.toString()),
      content: json['content']?.toString() ?? '',
      position: (json['position'] as num?)?.toDouble() ?? 0,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'content': content,
        'position': position,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  NotebookEntry copyWith({
    String? content,
    double? position,
    DateTime? updatedAt,
  }) {
    return NotebookEntry(
      id: id,
      kind: kind,
      content: content ?? this.content,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
