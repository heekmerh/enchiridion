import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/exam_module.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/services/storage_service.dart';

void main() {
  group('exam module scopes', () {
    test('PLAB scope matches the legacy standalone scope constant', () {
      expect(examScopeForModule(kPlabModuleId), kStandaloneExamPrepScope);
      expect(kStandaloneExamPrepScope, 'exam_prep_plab');
    });

    test('every module has a distinct exam_prep_<id> scope', () {
      final scopes = allExamScopes;
      expect(scopes, hasLength(kExamModules.length));
      expect(scopes.toSet(), hasLength(kExamModules.length));
      for (final module in kExamModules) {
        expect(
          examScopeForModule(module.id),
          '${kExamPrepScopePrefix}_${module.id}',
        );
        expect(isExamPrepScope(examScopeForModule(module.id)), isTrue);
      }
    });

    test('module labels resolve both ways', () {
      expect(examModuleForId('usmle').label, 'USMLE');
      expect(examModuleLabelForScope('exam_prep_usmle'), 'USMLE');
      expect(examModuleLabelForScope('paediatrics'), isNull);
    });
  });

  group('legacy scope migration', () {
    test('copies dev data from exam_prep to exam_prep_plab once', () async {
      SharedPreferences.setMockInitialValues({
        'answers_exam_prep': '{"q1":{"question_id":"q1"}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await storage.migrateLegacyExamPrepScope();
      expect(
        prefs.getString('answers_exam_prep_plab'),
        '{"q1":{"question_id":"q1"}}',
      );

      // Never overwrites newer data with the legacy copy.
      await prefs.setString('answers_exam_prep_plab', '{"q9":{}}');
      await prefs.setString('answers_exam_prep', '{"q1":{}}');
      await storage.migrateLegacyExamPrepScope();
      expect(prefs.getString('answers_exam_prep_plab'), '{"q9":{}}');
    });
  });
}
