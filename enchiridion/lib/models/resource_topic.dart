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
}

const String kStandaloneExamPrepScope = 'exam_prep';

const List<ResourceTopic> kSurgicalInstrumentationTopics = [
  ResourceTopic(
    id: 'sutures',
    title: 'Sutures',
    categoryTitle: 'Surgical Instrumentation',
    heroAssetPath: 'assets/resources/surgical instrumentation.jpeg',
    dataAssetPath: 'assets/data/resources/sutures.json',
    description:
        'Core suture types, handling, indications, and image-rich references.',
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
