enum ThemeMode { light, dark, sepia }

enum FontFamily { sans, serif, mono }

class UserSettings {
  final ThemeMode theme;
  final int fontSize; // Percentage: 75-200
  final double lineHeight; // 1.0 - 2.5
  final FontFamily fontFamily;

  /// Ambient "Study Buddy" Quick Check prompts (Android bubble/notification).
  static const bool defaultStudyBuddyEnabled = true;

  /// Minutes between ambient prompts. Default 45.
  static const int defaultStudyBuddyIntervalMinutes = 45;

  final bool studyBuddyEnabled;
  final int studyBuddyIntervalMinutes;

  const UserSettings({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    this.studyBuddyEnabled = defaultStudyBuddyEnabled,
    this.studyBuddyIntervalMinutes = defaultStudyBuddyIntervalMinutes,
  });

  static const defaultSettings = UserSettings(
    theme: ThemeMode.light,
    fontSize: 100,
    lineHeight: 1.6,
    fontFamily: FontFamily.sans,
  );

  UserSettings copyWith({
    ThemeMode? theme,
    int? fontSize,
    double? lineHeight,
    FontFamily? fontFamily,
    bool? studyBuddyEnabled,
    int? studyBuddyIntervalMinutes,
  }) {
    return UserSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      studyBuddyEnabled: studyBuddyEnabled ?? this.studyBuddyEnabled,
      studyBuddyIntervalMinutes:
          studyBuddyIntervalMinutes ?? this.studyBuddyIntervalMinutes,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      theme: ThemeMode.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => ThemeMode.light,
      ),
      fontSize: json['fontSize'] as int? ?? 100,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      fontFamily: FontFamily.values.firstWhere(
        (e) => e.name == json['fontFamily'],
        orElse: () => FontFamily.sans,
      ),
      studyBuddyEnabled:
          json['studyBuddyEnabled'] as bool? ?? defaultStudyBuddyEnabled,
      studyBuddyIntervalMinutes:
          (json['studyBuddyIntervalMinutes'] as num?)?.toInt() ??
              defaultStudyBuddyIntervalMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme.name,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily.name,
      'studyBuddyEnabled': studyBuddyEnabled,
      'studyBuddyIntervalMinutes': studyBuddyIntervalMinutes,
    };
  }
}
