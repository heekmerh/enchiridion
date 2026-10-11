import '../utils/content_availability.dart';

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

// Sourced from `scripts/content/surgical instrumentation.md` (86 bullets,
// 85 unique — `Foley catheter` is deduped). Preserves that source order
// except sutures, hoisted to position one as the only entry with real
// content; its `Suture material` bullet maps here rather than a second row.
const List<ResourceTopic> kSurgicalInstrumentationTopics = [
  ResourceTopic(
    id: 'sutures',
    title: 'Suture Material',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
    dataAssetPath: 'assets/data/resources/sutures.json',
    description:
        'Core suture types, handling, indications, and image-rich references.',
  ),
  ResourceTopic(
    id: 'scalpel',
    title: 'Scalpel',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'scalpel-blade',
    title: 'Scalpel blade',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'mayo-scissors',
    title: 'Mayo scissors',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'metzenbaum-scissors',
    title: 'Metzenbaum scissors',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'dissecting-forceps',
    title: 'Dissecting forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'toothed-forceps',
    title: 'Toothed forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'artery-forceps',
    title: 'Artery forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'mosquito-forceps',
    title: 'Mosquito forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'kocher-forceps',
    title: 'Kocher forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'allis-tissue-forceps',
    title: 'Allis tissue forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'babcock-forceps',
    title: 'Babcock forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'sponge-holding-forceps',
    title: 'Sponge-holding forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'towel-clip',
    title: 'Towel clip',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'needle-holder',
    title: 'Needle holder',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'sinus-forceps',
    title: 'Sinus forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'dressing-forceps',
    title: 'Dressing forceps',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'skin-hook',
    title: 'Skin hook',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'retractor',
    title: 'Retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'langenbeck-retractor',
    title: 'Langenbeck retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'volkmann-retractor',
    title: 'Volkmann retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'deaver-retractor',
    title: 'Deaver retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'self-retaining-retractor',
    title: 'Self-retaining retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'balfour-retractor',
    title: 'Balfour retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'abdominal-retractor',
    title: 'Abdominal retractor',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'speculum',
    title: 'Speculum',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'vaginal-speculum',
    title: 'Vaginal speculum',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'cusco-speculum',
    title: 'Cusco speculum',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'sims-speculum',
    title: 'Sims\' speculum',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'proctoscope',
    title: 'Proctoscope',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'sigmoidoscope',
    title: 'Sigmoidoscope',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'anoscope',
    title: 'Anoscope',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'laryngoscope',
    title: 'Laryngoscope',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'endotracheal-tube',
    title: 'Endotracheal tube',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'tracheostomy-tube',
    title: 'Tracheostomy tube',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'chest-tube',
    title: 'Chest tube',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'chest-drain-bottle',
    title: 'Chest drain bottle',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'trocar-and-cannula',
    title: 'Trocar and cannula',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'drainage-catheter',
    title: 'Drainage catheter',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'foley-catheter',
    title: 'Foley catheter',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'suction-catheter',
    title: 'Suction catheter',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'feeding-tube',
    title: 'Feeding tube',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'ryles-tube',
    title: 'Ryle\'s tube',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'surgical-suction-tip',
    title: 'Surgical suction tip',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'diathermy-electrocautery',
    title: 'Diathermy/electrocautery',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'surgical-stapler',
    title: 'Surgical stapler',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'skin-stapler',
    title: 'Skin stapler',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'surgical-needle',
    title: 'Surgical needle',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'drain',
    title: 'Drain',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 't-tube',
    title: 'T-tube',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'malecot-catheter',
    title: 'Malecot catheter',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'pezzer-catheter',
    title: 'Pezzer catheter',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'colostomy-bag',
    title: 'Colostomy bag',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'ileostomy-bag',
    title: 'Ileostomy bag',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'plaster-of-paris',
    title: 'Plaster of Paris',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'pop-bandage',
    title: 'POP bandage',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'crepe-bandage',
    title: 'Crepe bandage',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'elastic-bandage',
    title: 'Elastic bandage',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'splint',
    title: 'Splint',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'cervical-collar',
    title: 'Cervical collar',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'thomas-splint',
    title: 'Thomas splint',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'external-fixator',
    title: 'External fixator',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'orthopaedic-cast',
    title: 'Orthopaedic cast',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'tourniquet',
    title: 'Tourniquet',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'bone-saw',
    title: 'Bone saw',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'gigli-saw',
    title: 'Gigli saw',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'osteotome',
    title: 'Osteotome',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'bone-rongeur',
    title: 'Bone rongeur',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'periosteal-elevator',
    title: 'Periosteal elevator',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'mallet',
    title: 'Mallet',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'bone-lever',
    title: 'Bone lever',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'curette',
    title: 'Curette',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'amputation-knife',
    title: 'Amputation knife',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'doyen-intestinal-clamp',
    title: 'Doyen intestinal clamp',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'non-crushing-bowel-clamp',
    title: 'Non-crushing bowel clamp',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'intestinal-scissors',
    title: 'Intestinal scissors',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'hernia-mesh',
    title: 'Hernia mesh',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'breast-biopsy-needle',
    title: 'Breast biopsy needle',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'core-biopsy-device',
    title: 'Core biopsy device',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'fine-needle-aspiration-needle',
    title: 'Fine-needle aspiration needle',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'lumbar-puncture-set',
    title: 'Lumbar puncture set',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'central-venous-catheter',
    title: 'Central venous catheter',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'arterial-cannula',
    title: 'Arterial cannula',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'surgical-drain',
    title: 'Surgical drain',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
  ResourceTopic(
    id: 'wound-dressing-set',
    title: 'Wound dressing set',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
  ),
];

// Sourced from `scripts/content/medical_instrumentation.md` (9 headings, 48
// bullets); group order follows the source's heading order, display order
// comes from `groupTopicsForDisplay`. The "IV cannulation" bullet maps to
// the pre-existing `iv-cannula` entry (this catalog's only real content,
// hence its group leading). "Laryngoscope" is prefixed `medical-` to
// disambiguate from the Surgical Instrumentation catalog's own entry.
const List<ResourceTopic> kMedicalInstrumentationTopics = [
  // -- Cardiovascular Instrumentation
  ResourceTopic(
    id: 'electrocardiograph-ecg-machine',
    title: 'Electrocardiograph (ECG) machine',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'holter-monitor',
    title: 'Holter monitor',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'cardiac-monitor',
    title: 'Cardiac monitor',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'defibrillator',
    title: 'Defibrillator',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'automated-external-defibrillator-aed',
    title: 'Automated External Defibrillator (AED)',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'pacemaker',
    title: 'Pacemaker',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'sphygmomanometer',
    title: 'Sphygmomanometer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),
  ResourceTopic(
    id: 'stethoscope',
    title: 'Stethoscope',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Cardiovascular Instrumentation',
  ),

  // -- Respiratory Instrumentation
  ResourceTopic(
    id: 'pulse-oximeter',
    title: 'Pulse oximeter',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'spirometer',
    title: 'Spirometer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'peak-flow-meter',
    title: 'Peak flow meter',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'nebulizer',
    title: 'Nebulizer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'oxygen-cylinder',
    title: 'Oxygen cylinder',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'oxygen-concentrator',
    title: 'Oxygen concentrator',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'ventilator',
    title: 'Ventilator',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),
  ResourceTopic(
    id: 'capnograph',
    title: 'Capnograph',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Respiratory Instrumentation',
  ),

  // -- Neurological Instrumentation
  ResourceTopic(
    id: 'electroencephalograph-eeg',
    title: 'Electroencephalograph (EEG)',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Neurological Instrumentation',
  ),
  ResourceTopic(
    id: 'electromyograph-emg',
    title: 'Electromyograph (EMG)',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Neurological Instrumentation',
  ),
  ResourceTopic(
    id: 'reflex-hammer',
    title: 'Reflex hammer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Neurological Instrumentation',
  ),
  ResourceTopic(
    id: 'tuning-fork',
    title: 'Tuning fork',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Neurological Instrumentation',
  ),

  // -- Diagnostic and Monitoring Equipment
  ResourceTopic(
    id: 'thermometer',
    title: 'Thermometer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'iv-cannula',
    title: 'IV Cannula',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    dataAssetPath: 'assets/data/resources/iv_cannula.json',
    description:
        'Peripheral venous cannula parts, insertion, uses, and precautions.',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'glucometer',
    title: 'Glucometer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'patient-monitor',
    title: 'Patient monitor',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'infusion-pump',
    title: 'Infusion pump',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'syringe-pump',
    title: 'Syringe pump',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'doppler-ultrasound-device',
    title: 'Doppler ultrasound device',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),
  ResourceTopic(
    id: 'fetal-monitor-ctg',
    title: 'Fetal monitor (CTG)',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Diagnostic and Monitoring Equipment',
  ),

  // -- Imaging Equipment
  ResourceTopic(
    id: 'x-ray-machine',
    title: 'X-ray machine',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Imaging Equipment',
  ),
  ResourceTopic(
    id: 'ultrasound-machine',
    title: 'Ultrasound machine',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Imaging Equipment',
  ),
  ResourceTopic(
    id: 'ct-scanner',
    title: 'CT scanner',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Imaging Equipment',
  ),
  ResourceTopic(
    id: 'mri-scanner',
    title: 'MRI scanner',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Imaging Equipment',
  ),
  ResourceTopic(
    id: 'mammography-unit',
    title: 'Mammography unit',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Imaging Equipment',
  ),

  // -- Ophthalmic Instruments
  ResourceTopic(
    id: 'ophthalmoscope',
    title: 'Ophthalmoscope',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Ophthalmic Instruments',
  ),
  ResourceTopic(
    id: 'retinoscope',
    title: 'Retinoscope',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Ophthalmic Instruments',
  ),
  ResourceTopic(
    id: 'snellen-chart',
    title: 'Snellen chart',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Ophthalmic Instruments',
  ),
  ResourceTopic(
    id: 'tonometer',
    title: 'Tonometer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Ophthalmic Instruments',
  ),

  // -- ENT Instruments
  ResourceTopic(
    id: 'otoscope',
    title: 'Otoscope',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'ENT Instruments',
  ),
  ResourceTopic(
    id: 'medical-laryngoscope',
    title: 'Laryngoscope',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'ENT Instruments',
  ),
  ResourceTopic(
    id: 'nasal-speculum',
    title: 'Nasal speculum',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'ENT Instruments',
  ),
  ResourceTopic(
    id: 'audiometer',
    title: 'Audiometer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'ENT Instruments',
  ),

  // -- Biomedical Sensors and Transducers
  ResourceTopic(
    id: 'temperature-transducer',
    title: 'Temperature transducer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Biomedical Sensors and Transducers',
  ),
  ResourceTopic(
    id: 'pressure-transducer',
    title: 'Pressure transducer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Biomedical Sensors and Transducers',
  ),
  ResourceTopic(
    id: 'flow-transducer',
    title: 'Flow transducer',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Biomedical Sensors and Transducers',
  ),
  ResourceTopic(
    id: 'biosensors',
    title: 'Biosensors',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Biomedical Sensors and Transducers',
  ),
  ResourceTopic(
    id: 'ecg-electrodes',
    title: 'ECG electrodes',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Biomedical Sensors and Transducers',
  ),

  // -- Therapeutic Equipment
  ResourceTopic(
    id: 'dialysis-machine',
    title: 'Dialysis machine',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Therapeutic Equipment',
  ),
  ResourceTopic(
    id: 'laser-therapy-devices',
    title: 'Laser therapy devices',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    group: 'Therapeutic Equipment',
  ),
];

/// [kMedicalInstrumentationTopics] reordered so the group holding real
/// content leads (contiguously, nothing interleaved), other groups following
/// authored order. The source list stays in authored order as the source of
/// truth; a future topic gaining a `dataAssetPath` promotes its group
/// automatically, with no edit needed here.
final List<ResourceTopic> kMedicalInstrumentationTopicsInDisplayOrder =
    availableFirstByGroup(
  kMedicalInstrumentationTopics,
  groupOf: (t) => t.group,
  isAvailable: (t) => t.hasContent,
);

// Sourced from scripts/content/OSCE.md, one tab per numbered section. Only
// "Abdominal Examination" has full content today; every other tab shows its
// [ResourceTopic.outline] as a checklist until its own JSON exists.
const List<ResourceTopic> kOsceTopics = [
  ResourceTopic(
    id: 'cardiovascular-system',
    title: 'Cardiovascular System',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Pulse',
      'Blood pressure',
      'JVP',
      'Precordium',
      'Peripheral pulses',
      'Carotid pulse/bruit',
      'Peripheral edema',
    ],
  ),
  ResourceTopic(
    id: 'respiratory-system',
    title: 'Respiratory System',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Hands/fingers — clubbing, cyanosis',
      'Respiratory rate',
      'Trachea',
      'Chest expansion',
      'Percussion',
      'Breath sounds',
      'Vocal resonance',
      'Cervical/supraclavicular lymph nodes',
    ],
  ),
  ResourceTopic(
    id: 'abdominal-examination',
    title: 'Abdominal Examination',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    dataAssetPath: 'assets/data/resources/abdominal_examination.json',
    description:
        'A structured OSCE abdominal examination walkthrough with inline visuals.',
    outline: [
      'Inspection',
      'Palpation of liver, spleen and kidneys',
      'Abdominal masses',
      'Ascites',
      'Hernial orifices',
      'Inguinal lymph nodes',
    ],
  ),
  ResourceTopic(
    id: 'neurological-examination',
    title: 'Neurological Examination',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Cranial nerves',
      'Upper limbs',
      'Lower limbs',
      'Gait',
      'Coordination',
      'Reflexes',
      'Sensory examination',
      'Cerebellar signs',
      'Higher mental functions',
    ],
  ),
  ResourceTopic(
    id: 'musculoskeletal-examination',
    title: 'Musculoskeletal Examination',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Spine',
      'Shoulder',
      'Elbow',
      'Wrist/hand',
      'Hip',
      'Knee',
      'Ankle/foot',
      'Temporomandibular joint',
    ],
  ),
  ResourceTopic(
    id: 'eye',
    title: 'Eye',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Visual acuity',
      'Visual fields',
      'Pupils',
      'Extraocular movements',
      'Fundoscopy',
      'Colour vision',
      'Red reflex',
    ],
  ),
  ResourceTopic(
    id: 'ear',
    title: 'Ear',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'External ear',
      'Otoscopy',
      'Hearing tests — Rinne and Weber',
    ],
  ),
  ResourceTopic(
    id: 'nose',
    title: 'Nose',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'External nose',
      'Nasal cavity',
      'Septum',
      'Turbinates',
      'Sinuses',
    ],
  ),
  ResourceTopic(
    id: 'throat-oral-cavity',
    title: 'Throat & Oral Cavity',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Lips',
      'Teeth',
      'Tongue',
      'Tonsils',
      'Pharynx',
      'Soft palate',
      'Uvula',
    ],
  ),
  ResourceTopic(
    id: 'neck',
    title: 'Neck',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Thyroid',
      'Cervical lymph nodes',
      'Carotids',
      'JVP',
      'Trachea',
    ],
  ),
  ResourceTopic(
    id: 'other-stations',
    title: 'Other Stations',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Thyroid',
      'Lymph nodes',
      'Breast',
      'Scrotum/testes',
      'Hernial orifices',
      'Peripheral vascular system',
      'Diabetic foot',
      'Varicose veins',
      'Joints',
      'Spine',
      'Cranial nerves',
      'Fundus',
      'Chest',
      'Precordium',
      'Neurological system',
    ],
  ),
  ResourceTopic(
    id: 'surgical-instruments-devices',
    title: 'Surgical Instruments & Devices',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    outline: [
      'Scalpel',
      'Scalpel blade',
      'Mayo scissors',
      'Metzenbaum scissors',
      'Dissecting forceps',
      'Toothed forceps',
      'Artery forceps',
      'Mosquito forceps',
      'Kocher forceps',
      'Allis tissue forceps',
      'Babcock forceps',
      'Sponge-holding forceps',
      'Towel clip',
      'Needle holder',
      'Sinus forceps',
      'Dressing forceps',
      'Skin hook',
      'Retractor',
      'Langenbeck retractor',
      'Volkmann retractor',
      'Deaver retractor',
      'Self-retaining retractor',
      'Balfour retractor',
      'Abdominal retractor',
      'Speculum',
      'Vaginal speculum',
      'Cusco speculum',
      "Sims' speculum",
      'Proctoscope',
      'Sigmoidoscope',
      'Anoscope',
      'Laryngoscope',
      'Endotracheal tube',
      'Tracheostomy tube',
      'Chest tube',
      'Chest drain bottle',
      'Trocar and cannula',
      'Drainage catheter',
      'Foley catheter',
      'Suction catheter',
      'Feeding tube',
      "Ryle's tube",
      'Surgical suction tip',
      'Diathermy/electrocautery',
      'Surgical stapler',
      'Skin stapler',
      'Suture material',
      'Surgical needle',
      'Drain',
      'T-tube',
      'Malecot catheter',
      'Pezzer catheter',
      'Colostomy bag',
      'Ileostomy bag',
      'Plaster of Paris',
      'POP bandage',
      'Crepe bandage',
      'Elastic bandage',
      'Splint',
      'Cervical collar',
      'Thomas splint',
      'External fixator',
      'Orthopaedic cast',
      'Tourniquet',
      'Bone saw',
      'Gigli saw',
      'Osteotome',
      'Bone rongeur',
      'Periosteal elevator',
      'Mallet',
      'Bone lever',
      'Curette',
      'Amputation knife',
      'Doyen intestinal clamp',
      'Non-crushing bowel clamp',
      'Intestinal scissors',
      'Hernia mesh',
      'Breast biopsy needle',
      'Core biopsy device',
      'Fine-needle aspiration needle',
      'Lumbar puncture set',
      'Central venous catheter',
      'Arterial cannula',
      'Surgical drain',
      'Wound dressing set',
    ],
  ),
];

/// [kOsceTopics] reordered so stations with real content lead stations that
/// only have an [ResourceTopic.outline] placeholder. `kOsceTopics` itself
/// stays in its authored order — it remains the authoring source of truth;
/// this derived list is what UI surfaces render.
final List<ResourceTopic> kOsceTopicsInDisplayOrder =
    availableFirst(kOsceTopics, (t) => t.hasContent);
