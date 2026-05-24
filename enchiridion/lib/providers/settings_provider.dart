import 'package:flutter/foundation.dart';
import '../models/user_settings.dart';
import '../services/storage_service.dart';

class SettingsProvider with ChangeNotifier {
  final StorageService _storageService;
  UserSettings _settings = UserSettings.defaultSettings;

  UserSettings get settings => _settings;

  SettingsProvider(this._storageService) {
    _loadSettings();
  }

  void _loadSettings() {
    _settings = _storageService.getSettings();
    notifyListeners();
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    notifyListeners();
  }

  Future<void> updateTheme(ThemeMode theme) async {
    await updateSettings(_settings.copyWith(theme: theme));
  }

  Future<void> updateFontSize(int fontSize) async {
    await updateSettings(_settings.copyWith(fontSize: fontSize));
  }

  Future<void> updateLineHeight(double lineHeight) async {
    await updateSettings(_settings.copyWith(lineHeight: lineHeight));
  }

  Future<void> updateFontFamily(FontFamily fontFamily) async {
    await updateSettings(_settings.copyWith(fontFamily: fontFamily));
  }
}
