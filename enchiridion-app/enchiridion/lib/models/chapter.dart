import 'content_block.dart';

class Chapter {
  final String id;
  final String title;
  final String? icon;
  final String? description;
  final int order;
  final List<ChapterSection> sections;
  final List<String> tags;
  final String? chapterColor;

  const Chapter({
    required this.id,
    required this.title,
    this.icon,
    this.description,
    required this.order,
    required this.sections,
    this.tags = const [],
    this.chapterColor,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    // Handle wrapping from book_complete.json which might have 'data' field
    Map<String, dynamic> data = json;
    if (json.containsKey('data')) {
      data = json['data'] as Map<String, dynamic>;
    }

    // Access chapter_metadata
    final metadata = data['chapter_metadata'] ?? {};

    return Chapter(
      id: metadata['chapter_id'] ?? '',
      title: metadata['chapter_title'] ?? '',
      icon: metadata['chapter_icon'],
      description: metadata['description'],
      order: metadata['position_in_book'] ?? 0,
      sections: (data['sections'] as List?)
              ?.map((e) => ChapterSection.fromJson(e))
              .toList() ??
          [],
      tags: (metadata['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      chapterColor: metadata['chapter_color'],
    );
  }

  Map<String, dynamic> toJson() => {
        'chapter_metadata': {
          'chapter_id': id,
          'chapter_title': title,
          'chapter_icon': icon,
          'description': description,
          'position_in_book': order,
          'chapter_color': chapterColor,
          'tags': tags,
        },
        'sections': sections.map((e) => e.toJson()).toList(),
      };
}

class ChapterSection {
  final String id;
  final String title;
  final int order;
  final String? sectionColor;
  final List<ChapterSubsection> subsections;

  const ChapterSection({
    required this.id,
    required this.title,
    required this.order,
    this.sectionColor,
    required this.subsections,
  });

  factory ChapterSection.fromJson(Map<String, dynamic> json) {
    return ChapterSection(
      id: json['section_id'] ?? '',
      title: json['section_title'] ?? '',
      order: json['section_order'] ?? 0,
      sectionColor: json['section_color'],
      subsections: (json['subsections'] as List?)
              ?.map((e) => ChapterSubsection.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'section_id': id,
        'section_title': title,
        'section_order': order,
        'section_color': sectionColor,
        'subsections': subsections.map((e) => e.toJson()).toList(),
      };
}

class ChapterSubsection {
  final String id;
  final String title;
  final String? icon;
  final String? subsectionColor;
  final List<ContentGroup> contentGroups;

  const ChapterSubsection({
    required this.id,
    required this.title,
    this.icon,
    this.subsectionColor,
    required this.contentGroups,
  });

  factory ChapterSubsection.fromJson(Map<String, dynamic> json) {
    return ChapterSubsection(
      id: json['subsection_id'] ?? '',
      title: json['subsection_title'] ?? '',
      icon: json['subsection_icon'],
      subsectionColor: json['subsection_color'],
      contentGroups: (json['content_groups'] as List?)
              ?.map((e) => ContentGroup.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'subsection_id': id,
        'subsection_title': title,
        'subsection_icon': icon,
        'subsection_color': subsectionColor,
        'content_groups': contentGroups.map((e) => e.toJson()).toList(),
      };
}

class ContentGroup {
  final String id;
  final String title;
  final String? subtitle;
  final String? icon;
  final List<ContentBlock> blocks;

  const ContentGroup({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    required this.blocks,
  });

  factory ContentGroup.fromJson(Map<String, dynamic> json) {
    return ContentGroup(
      id: json['group_id'] ?? '',
      title: json['group_title'] ?? '',
      subtitle: json['group_subtitle'],
      icon: json['group_icon'],
      blocks: (json['blocks'] as List?)
              ?.map((e) => ContentBlock.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'group_id': id,
        'group_title': title,
        'group_subtitle': subtitle,
        'group_icon': icon,
        'blocks': blocks.map((e) => e.toJson()).toList(),
      };
}
