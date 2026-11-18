import '../data/resource_catalog.dart';
import '../utils/content_availability.dart';

export '../data/resource_catalog.dart';

class ResourceTopic {
  final String id;
  final String title;
  final String categoryTitle;
  final String heroAssetPath;

  /// Asset path to this topic's full content JSON, or null if it hasn't
  /// been written yet — see [outline] for a placeholder in that case.
  final String? dataAssetPath;
  final String? description;

  /// A checklist of what this topic will eventually cover, sourced from
  /// scripts/content/OSCE.md. Shown in place of full content when
  /// [dataAssetPath] is null — the structure exists before the prose does.
  final List<String>? outline;

  /// The category heading this topic sits under in its authoring source
  /// (e.g. "Cardiovascular Instrumentation"). Null renders in a flat,
  /// header-less list (every Surgical Instrumentation and OSCE topic today).
  final String? group;

  const ResourceTopic({
    required this.id,
    required this.title,
    required this.categoryTitle,
    required this.heroAssetPath,
    this.dataAssetPath,
    this.description,
    this.outline,
    this.group,
  });

  /// Whether this topic has real written content available to open, as
  /// opposed to only an [outline] placeholder. Mirrors
  /// `CatalogBook.hasContent` so both models answer the same question the
  /// same way.
  bool get hasContent => dataAssetPath != null;

  /// Whether this topic should render with the shared coming-soon
  /// treatment — see `ComingSoonStyle` in `widgets/common/coming_soon.dart`.
  bool get isComingSoon => !hasContent;

  /// Stable storage scope anchoring pinned notes to this topic. `topic_<id>`
  /// keeps them separate from book notes while reusing the same
  /// `BlockRenderer` pin/clip machinery (keyed on a non-empty `bookId`).
  String get notesScope => 'topic_$id';
}

/// Resolves a pinned-note storage scope back to a display title: real book
/// ids resolve via the caller, `topic_<id>` scopes resolve against the
/// resource catalogs, and anything else falls back to the raw scope.
String topicTitleForNotesScope(String scope) {
  const prefix = 'topic_';
  if (!scope.startsWith(prefix)) return scope;
  final id = scope.substring(prefix.length);
  const catalogs = [
    kSurgicalInstrumentationTopics,
    kMedicalInstrumentationTopics,
    kOsceTopics,
    kObstetricsOsceTopics,
    kPediatricsOsceTopics,
    kQuickRevisionTopics,
    kPrescriptionTopics,
  ];
  for (final catalog in catalogs) {
    for (final topic in catalog) {
      if (topic.id == id) return topic.title;
    }
  }
  return scope;
}

/// Groups [topics] by [ResourceTopic.group], applying [availableFirst] at
/// both the group and topic level so a group with any content outranks one
/// without (why Medical Instrumentation opens on its one written topic's
/// group, not authored order). An all-null-group list degenerates to
/// `availableFirst(topics, (t) => t.hasContent)`.
Map<String?, List<ResourceTopic>> groupTopicsForDisplay(
    List<ResourceTopic> topics) {
  final byGroup = <String?, List<ResourceTopic>>{};
  for (final topic in topics) {
    byGroup.putIfAbsent(topic.group, () => []).add(topic);
  }
  final orderedEntries =
      availableFirst<MapEntry<String?, List<ResourceTopic>>>(
    byGroup.entries,
    (entry) => entry.value.any((t) => t.hasContent),
  );
  final result = <String?, List<ResourceTopic>>{};
  for (final entry in orderedEntries) {
    result[entry.key] = availableFirst(entry.value, (t) => t.hasContent);
  }
  return result;
}

/// Storage scope for PLAB exam prep — the uniform `exam_prep_<module>`
/// scheme (`exam_prep_plab`, `exam_prep_usmle`, …; see `exam_module.dart`).
const String kStandaloneExamPrepScope = 'exam_prep_plab';
