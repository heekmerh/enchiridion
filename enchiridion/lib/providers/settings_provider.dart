import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/user_settings.dart';
import '../services/bubble_scheduler.dart';
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

  /// Re-reads from storage and notifies — called after cross-device sync
  /// pulls remote settings into storage.
  void refresh() {
    _loadSettings();
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    final studyBuddyChanged =
        newSettings.studyBuddyEnabled != _settings.studyBuddyEnabled ||
            newSettings.studyBuddyIntervalMinutes !=
                _settings.studyBuddyIntervalMinutes;
    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    notifyListeners();
    if (studyBuddyChanged && !kIsWeb) {
      try {
        if (Platform.isAndroid) {
          unawaited(BubbleScheduler().applySettings(
            enabled: newSettings.studyBuddyEnabled,
            intervalMinutes: newSettings.studyBuddyIntervalMinutes,
          ));
        }
      } catch (_) {}
    }
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

  Future<void> updateStudyBuddyEnabled(bool enabled) async {
    await updateSettings(_settings.copyWith(studyBuddyEnabled: enabled));
  }

  Future<void> updateStudyBuddyInterval(int minutes) async {
    await updateSettings(_settings.copyWith(studyBuddyIntervalMinutes: minutes));
  }
}
