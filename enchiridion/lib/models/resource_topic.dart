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

  const ResourceTopic({
    required this.id,
    required this.title,
    required this.categoryTitle,
    required this.heroAssetPath,
    this.dataAssetPath,
    this.description,
    this.outline,
  });

  /// Whether this topic has real written content available to open, as
  /// opposed to only an [outline] placeholder. Mirrors
  /// `CatalogBook.hasContent` so both models answer the same question the
  /// same way.
  bool get hasContent => dataAssetPath != null;

  /// Whether this topic should render with the shared coming-soon
  /// treatment — see `ComingSoonStyle` in `widgets/common/coming_soon.dart`.
  bool get isComingSoon => !hasContent;
}

const String kStandaloneExamPrepScope = 'exam_prep';

// Sourced from `scripts/content/surgical instrumentation.md` — 86 authored
// bullet lines, 85 unique (`Foley catheter` is listed twice; deduped to its
// first occurrence). The list below preserves that source order except the
// suture entry, which is hoisted to position one because it is the only
// entry with real written content (availableFirst would also put it there,
// but hoisting it here keeps authored order and display order visibly the
// same). The `Suture material` bullet maps to this pre-existing entry rather
// than getting a second row — see `sims-speculum` for the other apostrophe
// normalization in this list.
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

const List<ResourceTopic> kMedicalInstrumentationTopics = [
  ResourceTopic(
    id: 'iv-cannula',
    title: 'IV Cannula',
    categoryTitle: 'Medical Instrumentation',
    heroAssetPath: 'assets/resources/clinical instrumentation.jpeg',
    dataAssetPath: 'assets/data/resources/iv_cannula.json',
    description:
        'Peripheral venous cannula parts, insertion, uses, and precautions.',
  ),
];

// Sourced from scripts/content/OSCE.md, which the author put together as
// the OSCE section's structure — one tab per numbered section there. Only
// "Abdomen" has full written content today (abdominal_examination.json);
// every other tab shows its [ResourceTopic.outline] as a checklist until
// its own content JSON exists.
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
