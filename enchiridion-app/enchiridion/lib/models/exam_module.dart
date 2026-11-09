import 'resource_topic.dart';

/// One exam-prep module. Only PLAB ships a question bank today; every other
/// module renders as coming-soon until its bank lands.
class ExamModule {
  final String id;
  final String label;
  final bool isAvailable;

  const ExamModule({
    required this.id,
    required this.label,
    required this.isAvailable,
  });
}

const String kPlabModuleId = 'plab';

const List<ExamModule> kExamModules = [
  ExamModule(id: 'plab', label: 'PLAB', isAvailable: true),
  ExamModule(id: 'usmle', label: 'USMLE', isAvailable: false),
  ExamModule(id: 'primaries', label: 'PRIMARIES', isAvailable: false),
  ExamModule(id: 'mccqe', label: 'MCCQE', isAvailable: false),
  ExamModule(id: 'amc', label: 'AMC', isAvailable: false),
  ExamModule(id: 'nzrex', label: 'NZREX', isAvailable: false),
  ExamModule(id: 'pres', label: 'PRES', isAvailable: false),
  ExamModule(id: 'smle', label: 'SMLE', isAvailable: false),
  ExamModule(id: 'mdcn', label: 'MDCN', isAvailable: false),
];

ExamModule examModuleForId(String moduleId) {
  for (final module in kExamModules) {
    if (module.id == moduleId) return module;
  }
  return kExamModules.first;
}

/// Prefix shared by every exam module scope (`exam_prep_plab`,
/// `exam_prep_usmle`, …).
const String kExamPrepScopePrefix = 'exam_prep';

/// Storage scope backing a module's answers, reviews, serve log, and daily
/// stats. Uniform scheme: `exam_prep_<id>` for every module, PLAB included
/// (it kept the legacy bare `exam_prep` scope only until the pre-launch
/// reset — see `StorageService.migrateLegacyExamPrepScope`).
/// Invariant: `examScopeForModule(kPlabModuleId)` must equal
/// [kStandaloneExamPrepScope] (`exam_prep_plab`) — both derive from
/// [kExamPrepScopePrefix] plus the module id, so they agree by construction.
String examScopeForModule(String moduleId) {
  return '${kExamPrepScopePrefix}_$moduleId';
}

/// Every module storage scope, PLAB first. Used to fold cross-module totals.
List<String> get allExamScopes =>
    [for (final module in kExamModules) examScopeForModule(module.id)];

/// True for every `exam_prep_<id>` module scope. Also accepts the retired
/// bare `exam_prep` scope so payloads scheduled before the pre-launch scope
/// reset still open instead of being dropped.
bool isExamPrepScope(String scope) {
  if (scope == kStandaloneExamPrepScope) return true;
  if (scope == 'exam_prep') return true;
  return scope.startsWith('${kExamPrepScopePrefix}_');
}

/// Display label for an exam-prep storage scope (`PLAB`, `USMLE`, …), or
/// null when the scope is not an exam module scope. Used by surfaces that
/// only receive a scope string (e.g. the unlock sheet).
String? examModuleLabelForScope(String scope) {
  for (final module in kExamModules) {
    if (examScopeForModule(module.id) == scope) return module.label;
  }
  return null;
}
