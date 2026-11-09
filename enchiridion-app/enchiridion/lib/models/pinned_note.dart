/// Which edge of the reading column a margin note's marker docks to,
/// mirroring which half of the screen the user long-pressed in.
enum NoteSide { left, right }

/// A margin note anchored to a specific content block while reading,
/// unlike the free-standing notes this replaced. [anchorId] identifies the
/// block within its chapter as `sectionId/subsectionId/groupId/blockIndex`
/// (see `BlockRenderer._buildKeys`).
class PinnedNote {
  final String id;
  final String bookId;
  final String chapterId;
  final String anchorId;
  final NoteSide side;
  final String content;

  /// Optional study collection. The note's book and reading anchor stay intact.
  final String? collectionId;
  final DateTime createdAt;

  /// Last content/collection edit. Defaults to [createdAt] for notes written
  /// before this field existed; drives last-write-wins cross-device sync.
  final DateTime updatedAt;

  const PinnedNote({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.anchorId,
    required this.side,
    required this.content,
    this.collectionId,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  factory PinnedNote.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    return PinnedNote(
      id: json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      anchorId: json['anchorId']?.toString() ?? '',
      side: json['side'] == 'right' ? NoteSide.right : NoteSide.left,
      content: json['content']?.toString() ?? '',
      collectionId: json['collectionId']?.toString(),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterId': chapterId,
        'anchorId': anchorId,
        'side': side == NoteSide.right ? 'right' : 'left',
        'content': content,
        'collectionId': collectionId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  PinnedNote copyWith({
    String? content,
    String? collectionId,
    bool clearCollection = false,
    DateTime? updatedAt,
  }) {
    return PinnedNote(
      id: id,
      bookId: bookId,
      chapterId: chapterId,
      anchorId: anchorId,
      side: side,
      content: content ?? this.content,
      collectionId: clearCollection ? null : collectionId ?? this.collectionId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteCollection {
  final String id;
  final String name;
  final DateTime createdAt;

  /// Last rename. Defaults to [createdAt]; drives last-write-wins sync.
  final DateTime updatedAt;

  const NoteCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  factory NoteCollection.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    return NoteCollection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  NoteCollection copyWith({String? name, DateTime? updatedAt}) =>
      NoteCollection(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
