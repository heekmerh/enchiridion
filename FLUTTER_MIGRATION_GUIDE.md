# Flutter Migration Guide - Enchiridion Reader App

## Table of Contents
1. [Overview](#overview)
2. [Project Setup](#project-setup)
3. [Dependencies](#dependencies)
4. [Architecture & Folder Structure](#architecture--folder-structure)
5. [Data Models](#data-models)
6. [Theme & Design System](#theme--design-system)
7. [Storage Service](#storage-service)
8. [Component Implementation Guide](#component-implementation-guide)
9. [Feature Implementation](#feature-implementation)
10. [Platform-Specific Considerations](#platform-specific-considerations)
11. [Testing Strategy](#testing-strategy)

---

## Overview

**Enchiridion** is a futuristic, offline-first reader application with intelligent typography and focus-driven design. This guide provides a complete roadmap for building an exact Flutter replica compatible with iOS and Android.

### Key Features to Implement
- ✅ Multi-chapter book reader with HTML content rendering
- ✅ Three theme modes: Light, Dark, and Sepia
- ✅ Customizable typography (font family, size, line height)
- ✅ Full-text search across all chapters
- ✅ Bookmark management
- ✅ Reading progress tracking
- ✅ Auto-hiding controls for distraction-free reading
- ✅ Persistent user settings
- ✅ Chapter navigation with Previous/Next buttons
- ✅ Slide-out drawers for TOC and Settings

---

## Project Setup

### 1. Create Flutter Project

```bash
flutter create enchiridion_reader
cd enchiridion_reader
```

### 2. Update SDK Constraints

Edit `pubspec.yaml`:
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
```

### 3. Configure Platform Support

Ensure iOS and Android are enabled:
```bash
flutter config --enable-ios
flutter config --enable-android
```

---

## Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  provider: ^6.1.1

  # Local Storage
  shared_preferences: ^2.2.2

  # HTML Rendering
  flutter_html: ^3.0.0-beta.2

  # Platform Detection
  flutter_platform_widgets: ^6.0.2

  # Safe Area & Responsiveness
  flutter_screenutil: ^5.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

Run:
```bash
flutter pub get
```

---

## Architecture & Folder Structure

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models
│   ├── book.dart
│   ├── chapter.dart
│   ├── user_settings.dart
│   ├── bookmark.dart
│   └── search_result.dart
├── services/                          # Business logic
│   └── storage_service.dart
├── providers/                         # State management
│   ├── book_provider.dart
│   ├── settings_provider.dart
│   └── bookmark_provider.dart
├── widgets/                           # Reusable UI components
│   ├── drawer/
│   │   ├── custom_drawer.dart
│   │   ├── toc_drawer.dart
│   │   └── settings_drawer.dart
│   ├── icons/
│   │   └── custom_icons.dart
│   └── common/
│       └── custom_app_bar.dart
├── screens/                           # Main screens
│   └── reader_screen.dart
├── theme/                             # Design system
│   ├── app_colors.dart
│   ├── app_theme.dart
│   └── text_styles.dart
└── constants/                         # Constants
    └── mock_data.dart
```

---

## Data Models

### 1. Chapter Model (`models/chapter.dart`)

```dart
class Chapter {
  final String id;
  final String title;
  final String content; // HTML string
  final int order;

  const Chapter({
    required this.id,
    required this.title,
    required this.content,
    required this.order,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'order': order,
    };
  }
}
```

### 2. Book Model (`models/book.dart`)

```dart
import 'chapter.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.chapters,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String,
      chapters: (json['chapters'] as List)
          .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'chapters': chapters.map((c) => c.toJson()).toList(),
    };
  }
}
```

### 3. User Settings Model (`models/user_settings.dart`)

```dart
enum ThemeMode { light, dark, sepia }

enum FontFamily { sans, serif, mono }

class UserSettings {
  final ThemeMode theme;
  final int fontSize; // Percentage: 75-200
  final double lineHeight; // 1.0 - 2.5
  final FontFamily fontFamily;

  const UserSettings({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
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
  }) {
    return UserSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme.name,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily.name,
    };
  }
}
```

### 4. Bookmark Model (`models/bookmark.dart`)

```dart
class Bookmark {
  final String id;
  final String chapterId;
  final int createdAt;
  final String name;
  final double scrollProgress; // 0.0 to 1.0

  const Bookmark({
    required this.id,
    required this.chapterId,
    required this.createdAt,
    required this.name,
    required this.scrollProgress,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      createdAt: json['createdAt'] as int,
      name: json['name'] as String,
      scrollProgress: (json['scrollProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterId': chapterId,
      'createdAt': createdAt,
      'name': name,
      'scrollProgress': scrollProgress,
    };
  }
}
```

### 5. Search Result Model (`models/search_result.dart`)

```dart
class SearchResult {
  final String chapterId;
  final String chapterTitle;
  final String snippet;
  final int matchIndex;

  const SearchResult({
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
    required this.matchIndex,
  });
}
```

---

## Theme & Design System

### 1. App Colors (`theme/app_colors.dart`)

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Dark colors
  static const deepSpace = Color(0xFF071028);
  static const inkCharcoal = Color(0xFF1F2A37);
  static const obsidian = Color(0xFF0B1220);

  // Light colors
  static const frost = Color(0xFFE9F3F8);
  static const paper = Color(0xFFFFFFFF);

  // Accent colors
  static const brandPink = Color(0xFFFF66A3);
  static const neonTeal = Color(0xFF00D2FF);
  static const gold = Color(0xFFFFD166);

  // Sepia colors
  static const sepiaBackground = Color(0xFFF4ECD8);
  static const sepiaText = Color(0xFF433422);
  static const sepiaBorder = Color(0xFFE3DABB);
  static const sepiaScrollbar = Color(0xFFD6CBB3);
}
```

### 2. App Theme (`theme/app_theme.dart`)

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../models/user_settings.dart' as models;

class AppTheme {
  static ThemeData getTheme(models.ThemeMode themeMode) {
    switch (themeMode) {
      case models.ThemeMode.dark:
        return _darkTheme();
      case models.ThemeMode.sepia:
        return _sepiaTheme();
      case models.ThemeMode.light:
      default:
        return _lightTheme();
    }
  }

  static ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      primaryColor: AppColors.brandPink,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandPink,
        secondary: AppColors.neonTeal,
        surface: AppColors.paper,
        background: AppColors.paper,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.inkCharcoal,
        onBackground: AppColors.inkCharcoal,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.inkCharcoal,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.brandPink),
      ),
      iconTheme: const IconThemeData(color: AppColors.brandPink),
      dividerColor: AppColors.frost,
    );
  }

  static ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deepSpace,
      primaryColor: AppColors.neonTeal,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonTeal,
        secondary: AppColors.brandPink,
        surface: AppColors.obsidian,
        background: AppColors.deepSpace,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.frost,
        onBackground: AppColors.frost,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepSpace,
        foregroundColor: AppColors.frost,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.brandPink),
      ),
      iconTheme: const IconThemeData(color: AppColors.neonTeal),
      dividerColor: AppColors.inkCharcoal,
    );
  }

  static ThemeData _sepiaTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.sepiaBackground,
      primaryColor: AppColors.brandPink,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandPink,
        secondary: AppColors.neonTeal,
        surface: AppColors.sepiaBackground,
        background: AppColors.sepiaBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.sepiaText,
        onBackground: AppColors.sepiaText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sepiaBackground,
        foregroundColor: AppColors.sepiaText,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.brandPink),
      ),
      iconTheme: const IconThemeData(color: AppColors.brandPink),
      dividerColor: AppColors.sepiaBorder,
    );
  }
}
```

---

## Storage Service

### Implementation (`services/storage_service.dart`)

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../models/bookmark.dart';

class StorageService {
  static const _settingsKey = 'lumina_settings';
  static const _bookmarksKey = 'lumina_bookmarks';
  static const _lastReadKey = 'lumina_last_read_chapter';

  // Settings
  static Future<UserSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      if (jsonString == null) return UserSettings.defaultSettings;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserSettings.fromJson(json);
    } catch (e) {
      return UserSettings.defaultSettings;
    }
  }

  static Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }

  // Bookmarks
  static Future<List<Bookmark>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_bookmarksKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveBookmark(Bookmark bookmark) async {
    final bookmarks = await getBookmarks();
    bookmarks.insert(0, bookmark);
    await _saveAllBookmarks(bookmarks);
  }

  static Future<void> removeBookmark(String id) async {
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.id == id);
    await _saveAllBookmarks(bookmarks);
  }

  static Future<void> _saveAllBookmarks(List<Bookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = bookmarks.map((b) => b.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_bookmarksKey, jsonString);
  }

  // Last Read Chapter
  static Future<String?> getLastReadChapter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastReadKey);
  }

  static Future<void> setLastReadChapter(String chapterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReadKey, chapterId);
  }
}
```

---

## Component Implementation Guide

### 1. Custom Icons (`widgets/icons/custom_icons.dart`)

```dart
import 'package:flutter/material.dart';

class CustomIcons {
  static Widget menu({double size = 24, Color? color}) {
    return Icon(Icons.menu, size: size, color: color);
  }

  static Widget close({double size = 24, Color? color}) {
    return Icon(Icons.close, size: size, color: color);
  }

  static Widget settings({double size = 24, Color? color}) {
    return Icon(Icons.settings, size: size, color: color);
  }

  static Widget bookmark({double size = 24, Color? color, bool filled = false}) {
    return Icon(
      filled ? Icons.bookmark : Icons.bookmark_border,
      size: size,
      color: color,
    );
  }

  static Widget search({double size = 24, Color? color}) {
    return Icon(Icons.search, size: size, color: color);
  }

  static Widget chevronLeft({double size = 24, Color? color}) {
    return Icon(Icons.chevron_left, size: size, color: color);
  }

  static Widget chevronRight({double size = 24, Color? color}) {
    return Icon(Icons.chevron_right, size: size, color: color);
  }
}
```

### 2. Custom Drawer (`widgets/drawer/custom_drawer.dart`)

```dart
import 'package:flutter/material.dart';
import '../icons/custom_icons.dart';

enum DrawerPosition { left, right }

class CustomDrawer extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String title;
  final Widget child;
  final DrawerPosition position;

  const CustomDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.title,
    required this.child,
    this.position = DrawerPosition.left,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Backdrop
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isOpen ? 1.0 : 0.0,
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),

        // Drawer Panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          left: position == DrawerPosition.left
              ? (isOpen ? 0 : -320)
              : null,
          right: position == DrawerPosition.right
              ? (isOpen ? 0 : -320)
              : null,
          child: Material(
            elevation: 16,
            color: theme.colorScheme.surface,
            child: SizedBox(
              width: 320,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: CustomIcons.close(
                            color: theme.iconTheme.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

### 3. Settings Panel (`widgets/drawer/settings_drawer.dart`)

```dart
import 'package:flutter/material.dart';
import '../../models/user_settings.dart' as models;
import '../../theme/app_colors.dart';

class SettingsPanel extends StatelessWidget {
  final models.UserSettings settings;
  final Function(models.UserSettings) onUpdate;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onUpdate,
  });

  void _update({
    models.ThemeMode? theme,
    int? fontSize,
    double? lineHeight,
    models.FontFamily? fontFamily,
  }) {
    onUpdate(settings.copyWith(
      theme: theme,
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Theme Selection
        _buildSectionTitle('THEME', theme),
        const SizedBox(height: 12),
        Row(
          children: models.ThemeMode.values.map((mode) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ThemeButton(
                  mode: mode,
                  isSelected: settings.theme == mode,
                  onTap: () => _update(theme: mode),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // Font Family Selection
        _buildSectionTitle('TYPEFACE', theme),
        const SizedBox(height: 12),
        Row(
          children: models.FontFamily.values.map((font) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _FontButton(
                  fontFamily: font,
                  isSelected: settings.fontFamily == font,
                  onTap: () => _update(fontFamily: font),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // Font Size Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('SIZE', theme),
            Text(
              '${settings.fontSize}%',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.neonTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: settings.fontSize.toDouble(),
          min: 75,
          max: 200,
          divisions: 25,
          activeColor: AppColors.brandPink,
          onChanged: (value) => _update(fontSize: value.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('A', style: theme.textTheme.bodySmall),
            Text('A', style: theme.textTheme.titleLarge),
          ],
        ),

        const SizedBox(height: 32),

        // Line Height Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('SPACING', theme),
            Text(
              settings.lineHeight.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.neonTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: settings.lineHeight,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          activeColor: AppColors.brandPink,
          onChanged: (value) => _update(lineHeight: value),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final models.ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (mode) {
      case models.ThemeMode.light:
        backgroundColor = AppColors.paper;
        textColor = AppColors.inkCharcoal;
        borderColor = Colors.grey.shade300;
        break;
      case models.ThemeMode.sepia:
        backgroundColor = AppColors.sepiaBackground;
        textColor = AppColors.sepiaText;
        borderColor = AppColors.sepiaBorder;
        break;
      case models.ThemeMode.dark:
        backgroundColor = AppColors.deepSpace;
        textColor = AppColors.frost;
        borderColor = AppColors.inkCharcoal;
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: isSelected ? AppColors.brandPink : borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            mode.name.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final models.FontFamily fontFamily;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontButton({
    required this.fontFamily,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String fontName;
    String displayFamily;

    switch (fontFamily) {
      case models.FontFamily.sans:
        fontName = 'Sans';
        displayFamily = 'sans-serif';
        break;
      case models.FontFamily.serif:
        fontName = 'Serif';
        displayFamily = 'serif';
        break;
      case models.FontFamily.mono:
        fontName = 'Mono';
        displayFamily = 'monospace';
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPink.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.brandPink
                : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            fontName,
            style: TextStyle(
              fontSize: 14,
              fontFamily: displayFamily,
              color: isSelected
                  ? AppColors.brandPink
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
```

### 4. Table of Contents Drawer (`widgets/drawer/toc_drawer.dart`)

```dart
import 'package:flutter/material.dart';
import '../../models/chapter.dart';
import '../../models/bookmark.dart';
import '../../models/search_result.dart';
import '../../theme/app_colors.dart';
import '../icons/custom_icons.dart';

class TocDrawerContent extends StatefulWidget {
  final List<Chapter> chapters;
  final String currentChapterId;
  final List<Bookmark> bookmarks;
  final Function(String) onChapterSelected;
  final Function(List<SearchResult>) onSearchResults;

  const TocDrawerContent({
    super.key,
    required this.chapters,
    required this.currentChapterId,
    required this.bookmarks,
    required this.onChapterSelected,
    required this.onSearchResults,
  });

  @override
  State<TocDrawerContent> createState() => _TocDrawerContentState();
}

class _TocDrawerContentState extends State<TocDrawerContent> {
  String _searchQuery = '';
  List<SearchResult> _searchResults = [];

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });

    if (query.length < 3) {
      setState(() {
        _searchResults = [];
      });
      widget.onSearchResults([]);
      return;
    }

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final chapter in widget.chapters) {
      // Strip HTML tags
      final text = chapter.content.replaceAll(RegExp(r'<[^>]*>'), '');
      final lowerText = text.toLowerCase();

      int index = lowerText.indexOf(lowerQuery);
      int matchCount = 0;

      while (index != -1 && matchCount < 3) {
        final start = (index - 40).clamp(0, text.length);
        final end = (index + query.length + 40).clamp(0, text.length);

        String snippet = text.substring(start, end);
        if (start > 0) snippet = '...$snippet';
        if (end < text.length) snippet = '$snippet...';

        results.add(SearchResult(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          snippet: snippet,
          matchIndex: index,
        ));

        matchCount++;
        index = lowerText.indexOf(lowerQuery, index + 1);
      }
    }

    setState(() {
      _searchResults = results;
    });
    widget.onSearchResults(results);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        TextField(
          onChanged: _handleSearch,
          decoration: InputDecoration(
            hintText: 'Query database...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
            prefixIcon: CustomIcons.search(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              size: 20,
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? AppColors.inkCharcoal
                : AppColors.frost,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.brandPink,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Search Results
        if (_searchQuery.length >= 3) ...[
          _buildSectionHeader('RESULTS', theme),
          const SizedBox(height: 8),
          if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No matching protocols found.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            )
          else
            ..._searchResults.map((result) => _SearchResultItem(
              result: result,
              onTap: () => widget.onChapterSelected(result.chapterId),
            )),
          const SizedBox(height: 24),
        ],

        // Bookmarks
        if (widget.bookmarks.isNotEmpty && _searchQuery.isEmpty) ...[
          _buildSectionHeader('SAVED LOCATIONS', theme),
          const SizedBox(height: 8),
          ...widget.bookmarks.map((bookmark) => _BookmarkItem(
            bookmark: bookmark,
            onTap: () => widget.onChapterSelected(bookmark.chapterId),
          )),
          const SizedBox(height: 24),
        ],

        // Chapter List
        if (_searchQuery.isEmpty) ...[
          _buildSectionHeader('PROTOCOLS', theme),
          const SizedBox(height: 8),
          ...widget.chapters.map((chapter) => _ChapterItem(
            chapter: chapter,
            isActive: chapter.id == widget.currentChapterId,
            onTap: () => widget.onChapterSelected(chapter.id),
          )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.chapterTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPink,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.neonTeal,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                '"${result.snippet}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'serif',
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkItem extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;

  const _BookmarkItem({
    required this.bookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            CustomIcons.bookmark(
              size: 16,
              color: AppColors.brandPink,
              filled: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bookmark.name,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterItem extends StatelessWidget {
  final Chapter chapter;
  final bool isActive;
  final VoidCallback onTap;

  const _ChapterItem({
    required this.chapter,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brandPink.withOpacity(0.1)
              : Colors.transparent,
          border: isActive
              ? Border.all(
                  color: AppColors.brandPink.withOpacity(0.2),
                )
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          chapter.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? AppColors.brandPink
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
```

---

## Feature Implementation

### Main Reader Screen (`screens/reader_screen.dart`)

This is the core screen that ties everything together. Due to length constraints, here's the structure and key implementation details:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/user_settings.dart' as models;
import '../providers/settings_provider.dart';
import '../providers/bookmark_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/drawer/custom_drawer.dart';
import '../widgets/drawer/toc_drawer.dart';
import '../widgets/drawer/settings_drawer.dart';
import '../widgets/icons/custom_icons.dart';
import '../constants/mock_data.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late String _currentChapterId;
  bool _isMenuOpen = false;
  bool _isSettingsOpen = false;
  bool _showControls = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapterId = MockData.book.chapters.first.id;
    _initializeAutoHideControls();
    _loadLastReadChapter();
  }

  void _initializeAutoHideControls() {
    // Implement auto-hide logic similar to React version
    // Use Timer and ScrollController listener
  }

  void _loadLastReadChapter() async {
    // Load from StorageService
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, BookmarkProvider>(
      builder: (context, settingsProvider, bookmarkProvider, child) {
        final settings = settingsProvider.settings;
        final chapter = _getCurrentChapter();
        final isBookmarked = bookmarkProvider.isBookmarked(_currentChapterId);

        return Scaffold(
          body: Stack(
            children: [
              // Main Content
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // App Bar
                  SliverAppBar(
                    // ... implementation
                  ),

                  // Chapter Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Html(
                        data: chapter.content,
                        style: _getHtmlStyles(settings),
                      ),
                    ),
                  ),

                  // Chapter Navigation
                  SliverToBoxAdapter(
                    child: _buildChapterNavigation(),
                  ),
                ],
              ),

              // TOC Drawer
              CustomDrawer(
                isOpen: _isMenuOpen,
                onClose: () => setState(() => _isMenuOpen = false),
                title: 'Enchiridion Index',
                position: DrawerPosition.left,
                child: TocDrawerContent(
                  // ... props
                ),
              ),

              // Settings Drawer
              CustomDrawer(
                isOpen: _isSettingsOpen,
                onClose: () => setState(() => _isSettingsOpen = false),
                title: 'Visual Interface',
                position: DrawerPosition.right,
                child: SettingsPanel(
                  // ... props
                ),
              ),

              // Reading Progress Bar
              _buildProgressBar(),
            ],
          ),
        );
      },
    );
  }

  Map<String, Style> _getHtmlStyles(models.UserSettings settings) {
    // Return HTML styling based on settings
    // Map fontSize percentage, lineHeight, fontFamily to Flutter styles
  }

  Chapter _getCurrentChapter() {
    return MockData.book.chapters.firstWhere(
      (c) => c.id == _currentChapterId,
      orElse: () => MockData.book.chapters.first,
    );
  }

  Widget _buildChapterNavigation() {
    // Previous/Next buttons
  }

  Widget _buildProgressBar() {
    // Bottom progress indicator
  }
}
```

### State Management with Provider

#### Settings Provider (`providers/settings_provider.dart`)

```dart
import 'package:flutter/foundation.dart';
import '../models/user_settings.dart';
import '../services/storage_service.dart';

class SettingsProvider with ChangeNotifier {
  UserSettings _settings = UserSettings.defaultSettings;

  UserSettings get settings => _settings;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await StorageService.getSettings();
    notifyListeners();
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    await StorageService.saveSettings(newSettings);
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
```

#### Bookmark Provider (`providers/bookmark_provider.dart`)

```dart
import 'package:flutter/foundation.dart';
import '../models/bookmark.dart';
import '../services/storage_service.dart';

class BookmarkProvider with ChangeNotifier {
  List<Bookmark> _bookmarks = [];

  List<Bookmark> get bookmarks => _bookmarks;

  BookmarkProvider() {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    _bookmarks = await StorageService.getBookmarks();
    notifyListeners();
  }

  bool isBookmarked(String chapterId) {
    return _bookmarks.any((b) => b.chapterId == chapterId);
  }

  Future<void> toggleBookmark(String chapterId, String chapterTitle) async {
    if (isBookmarked(chapterId)) {
      // Remove bookmark
      final bookmark = _bookmarks.firstWhere((b) => b.chapterId == chapterId);
      await StorageService.removeBookmark(bookmark.id);
      _bookmarks.removeWhere((b) => b.chapterId == chapterId);
    } else {
      // Add bookmark
      final newBookmark = Bookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chapterId: chapterId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        name: chapterTitle,
        scrollProgress: 0.0,
      );
      await StorageService.saveBookmark(newBookmark);
      _bookmarks.insert(0, newBookmark);
    }
    notifyListeners();
  }
}
```

### Mock Data (`constants/mock_data.dart`)

```dart
import '../models/book.dart';
import '../models/chapter.dart';

class MockData {
  static final Book book = Book(
    id: 'book-001',
    title: 'Enchiridion Guide',
    author: 'System Core',
    coverUrl: 'https://picsum.photos/300/450',
    chapters: [
      Chapter(
        id: 'ch1',
        order: 1,
        title: 'Protocol 1: Initialization',
        content: '''
          <h2>The Shift</h2>
          <p>It was a bright cold day in April, and the clocks were striking thirteen. Winston Smith, his chin nuzzled into his breast in an effort to escape the vile wind, slipped quickly through the glass doors of Victory Mansions, though not quickly enough to prevent a swirl of gritty dust from entering along with him.</p>
          <p>The hallway smelt of boiled cabbage and old rag mats. At one end of it a coloured poster, too large for indoor display, had been tacked to the wall. It depicted simply an enormous face, more than a metre wide: the face of a man of about forty-five, with a heavy black moustache and ruggedly handsome features.</p>
          <p>Winston made for the stairs. It was no use trying the lift. Even at the best of times it was seldom working, and at present the electric current was cut off during daylight hours. It was part of the economy drive in preparation for Hate Week.</p>
          <h3>The Flat</h3>
          <p>Inside the flat a fruity voice was reading out a list of figures which had something to do with the production of pig-iron. The voice came from an oblong metal plaque like a dulled mirror which formed part of the surface of the right-hand wall. Winston turned a switch and the voice sank somewhat, though the words were still distinguishable.</p>
        ''',
      ),
      // Add remaining chapters from constants.ts
    ],
  );
}
```

### Main App Entry (`main.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bookmark_provider.dart';
import 'screens/reader_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EnchiridionApp());
}

class EnchiridionApp extends StatelessWidget {
  const EnchiridionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            title: 'Enchiridion',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(settingsProvider.settings.theme),
            home: const ReaderScreen(),
          );
        },
      ),
    );
  }
}
```

---

## Platform-Specific Considerations

### iOS Configuration

1. **Info.plist** - Add app name and permissions if needed:
```xml
<key>CFBundleName</key>
<string>Enchiridion</string>
<key>CFBundleDisplayName</key>
<string>Enchiridion</string>
```

2. **Status Bar** - Configure in `main.dart`:
```dart
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const EnchiridionApp());
}
```

### Android Configuration

1. **MainActivity.kt** - Ensure using FlutterActivity

2. **AndroidManifest.xml** - Set app name:
```xml
<application
    android:label="Enchiridion"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

3. **Material 3** - Already configured in theme

### Safe Area Handling

Wrap content in `SafeArea` widgets where needed, especially for the app bar and bottom progress bar.

---

## Testing Strategy

### Unit Tests

Test the following:
- `StorageService` methods (mocked SharedPreferences)
- Data model serialization/deserialization
- Search algorithm
- Settings state updates

### Widget Tests

Test:
- Theme switching
- Drawer opening/closing
- Chapter navigation
- Bookmark toggle
- Search functionality

### Integration Tests

Test:
- Complete user flow from opening app to reading
- Settings persistence across app restarts
- Bookmark creation and navigation

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create Flutter project and folder structure
- [ ] Add all dependencies
- [ ] Implement data models
- [ ] Create theme and color system
- [ ] Implement StorageService

### Phase 2: State Management
- [ ] Create SettingsProvider
- [ ] Create BookmarkProvider
- [ ] Set up Provider in main.dart

### Phase 3: UI Components
- [ ] Build CustomIcons
- [ ] Build CustomDrawer
- [ ] Build SettingsPanel
- [ ] Build TocDrawerContent

### Phase 4: Main Screen
- [ ] Build ReaderScreen scaffold
- [ ] Implement HTML content rendering
- [ ] Add app bar with controls
- [ ] Add chapter navigation
- [ ] Implement reading progress bar

### Phase 5: Features
- [ ] Implement auto-hide controls
- [ ] Implement search functionality
- [ ] Implement bookmark system
- [ ] Add last-read-chapter persistence

### Phase 6: Polish
- [ ] Add animations and transitions
- [ ] Test on iOS and Android
- [ ] Optimize performance
- [ ] Add splash screen and app icon

---

## Key Differences from React Version

1. **State Management**: Provider instead of React hooks
2. **HTML Rendering**: `flutter_html` package instead of `dangerouslySetInnerHTML`
3. **Storage**: `shared_preferences` instead of localStorage
4. **Styling**: Widget composition instead of Tailwind classes
5. **Navigation**: Single screen with drawers instead of web-based routing
6. **Icons**: Flutter Material Icons instead of SVG components

---

## Performance Optimization Tips

1. Use `const` constructors wherever possible
2. Implement proper `keys` for list items
3. Consider using `ListView.builder` for large chapter lists
4. Memoize expensive computations in providers
5. Use `RepaintBoundary` for complex widgets
6. Optimize HTML rendering by caching parsed content

---

## Additional Resources

- Flutter Documentation: https://docs.flutter.dev
- Provider Package: https://pub.dev/packages/provider
- Flutter HTML: https://pub.dev/packages/flutter_html
- Shared Preferences: https://pub.dev/packages/shared_preferences

---

**END OF GUIDE**

This comprehensive guide should enable any Flutter developer to build an exact replica of the Enchiridion reader app for iOS and Android. Follow the phases in the implementation checklist for a structured development approach.
