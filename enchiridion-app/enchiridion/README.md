# Enchiridion - Flutter Edition

A futuristic, offline-first reader application built with Flutter. This is a mobile-native version of the Enchiridion reader, featuring intelligent typography and focus-driven design for iOS and Android.

## Features

- 📖 Multi-chapter book reader with HTML content rendering
- 🎨 Three theme modes: Light, Dark, and Sepia
- ✏️ Customizable typography (font family, size, line height)
- 🔍 Full-text search across all chapters
- 🔖 Bookmark management
- 📊 Reading progress tracking
- 👻 Auto-hiding controls for distraction-free reading
- 💾 Persistent user settings
- ⬅️➡️ Chapter navigation with Previous/Next buttons
- 📱 Slide-out drawers for TOC and Settings

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- iOS development setup (for iOS builds)
- Android development setup (for Android builds)

### Installation

1. Navigate to the project directory:
   ```bash
   cd enchiridion
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### iOS
```bash
cd ios
pod install
cd ..
flutter run
```

#### Android
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── book.dart
│   ├── chapter.dart
│   ├── user_settings.dart
│   ├── bookmark.dart
│   └── search_result.dart
├── services/                 # Business logic
│   └── storage_service.dart
├── providers/                # State management
│   ├── settings_provider.dart
│   └── bookmark_provider.dart
├── widgets/                  # Reusable UI components
│   ├── drawer/
│   ├── icons/
│   └── common/
├── screens/                  # Main screens
│   └── reader_screen.dart
├── theme/                    # Design system
│   ├── app_colors.dart
│   ├── app_theme.dart
│   └── text_styles.dart
└── constants/                # Constants
    └── mock_data.dart
```

## Development

### Running Tests
```bash
flutter test
```

### Building for Production

#### iOS
```bash
flutter build ios --release
```

#### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## Architecture

This app uses:
- **Provider** for state management
- **SharedPreferences** for local storage
- **flutter_html** for HTML content rendering
- **Material 3** design system

## Related Documentation

- See `../FLUTTER_MIGRATION_GUIDE.md` for complete migration details
- See `../FLUTTER_IMPLEMENTATION_PLAN.md` for phased implementation plan
- See `../CLAUDE.md` for React version documentation

## License

This project is part of the Enchiridion reader application suite.
