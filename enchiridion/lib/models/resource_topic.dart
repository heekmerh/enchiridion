class ResourceTopic {
  final String id;
  final String title;
  final String categoryTitle;
  final String heroAssetPath;
  final String dataAssetPath;
  final String? description;

  const ResourceTopic({
    required this.id,
    required this.title,
    required this.categoryTitle,
    required this.heroAssetPath,
    required this.dataAssetPath,
    this.description,
  });
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

const List<ResourceTopic> kOsceTopics = [
  ResourceTopic(
    id: 'abdominal-examination',
    title: 'Abdominal Examination',
    categoryTitle: 'OSCE',
    heroAssetPath: 'assets/resources/osce.jpeg',
    dataAssetPath: 'assets/data/resources/abdominal_examination.json',
    description:
        'A structured OSCE abdominal examination walkthrough with inline visuals.',
  ),
];
