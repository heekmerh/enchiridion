import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/models/user_settings.dart';

@GenerateNiceMocks([MockSpec<SharedPreferences>()])
import 'storage_service_test.mocks.dart';

void main() {
  late StorageService storageService;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    storageService = StorageService(mockPrefs);
  });

  group('StorageService', () {
    test('getSettings returns default when no settings saved', () {
      when(mockPrefs.getString(any)).thenReturn(null);
      
      final settings = storageService.getSettings();
      
      expect(settings.fontSize, UserSettings.defaultSettings.fontSize);
    });

    test('saveSettings saves json string', () async {
      final settings = UserSettings.defaultSettings.copyWith(fontSize: 20);
      
      await storageService.saveSettings(settings);
      
      verify(mockPrefs.setString('enchiridion_settings', any)).called(1);
    });

    test('getLastReadChapter returns null when not set', () {
      when(mockPrefs.getString(any)).thenReturn(null);
      
      final chapterId = storageService.getLastReadChapter();
      
      expect(chapterId, null);
    });

    test('setLastReadChapter saves chapter id', () async {
      await storageService.setLastReadChapter('chapter-1');
      
      verify(mockPrefs.setString('enchiridion_last_read_chapter', 'chapter-1')).called(1);
    });
  });
}
