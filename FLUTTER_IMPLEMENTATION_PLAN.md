# Flutter Migration - Phased Implementation Plan

## Overview
This plan breaks down the Flutter migration into 7 manageable phases, each building on the previous one. Each phase produces working, testable code before moving to the next.

---

## **Phase 1: Project Foundation & Setup**
**Goal:** Create the basic Flutter project structure with essential configuration

### Deliverables:
1. Create `flutter_app/` directory structure
2. Generate `pubspec.yaml` with all required dependencies
3. Create folder structure:
   - `lib/models/`
   - `lib/services/`
   - `lib/providers/`
   - `lib/widgets/`
   - `lib/screens/`
   - `lib/theme/`
   - `lib/constants/`
4. Create `.gitignore` for Flutter
5. Add basic `README.md` for Flutter app

### Success Criteria:
- Project structure exists
- `flutter pub get` runs successfully
- No compilation errors

**Estimated Files:** 2 files (pubspec.yaml, README.md) + folder structure

---

## **Phase 2: Data Models & Core Types**
**Goal:** Implement all data models with JSON serialization

### Deliverables:
1. `lib/models/chapter.dart` - Chapter model
2. `lib/models/book.dart` - Book model
3. `lib/models/user_settings.dart` - Settings with enums (ThemeMode, FontFamily)
4. `lib/models/bookmark.dart` - Bookmark model
5. `lib/models/search_result.dart` - Search result model

### Success Criteria:
- All models compile
- JSON serialization/deserialization works
- Models match TypeScript interfaces from original app

**Estimated Files:** 5 files

---

## **Phase 3: Theme System & Design Tokens**
**Goal:** Establish the visual design system

### Deliverables:
1. `lib/theme/app_colors.dart` - All color constants (deep-space, frost, brand-pink, etc.)
2. `lib/theme/app_theme.dart` - ThemeData for light/dark/sepia modes
3. Test theme switching works

### Success Criteria:
- All three themes (light, dark, sepia) are properly defined
- Colors match the React app exactly
- Themes can be applied to a basic test screen

**Estimated Files:** 2 files

---

## **Phase 4: Storage Service & State Management**
**Goal:** Implement data persistence and state management layer

### Deliverables:
1. `lib/services/storage_service.dart` - SharedPreferences wrapper for settings, bookmarks, last-read
2. `lib/providers/settings_provider.dart` - SettingsProvider with ChangeNotifier
3. `lib/providers/bookmark_provider.dart` - BookmarkProvider with ChangeNotifier

### Success Criteria:
- Settings can be saved and loaded from storage
- Bookmarks can be added, removed, and persisted
- Providers notify listeners on changes
- Can write unit tests for storage operations

**Estimated Files:** 3 files

---

## **Phase 5: Mock Data & Constants**
**Goal:** Port existing book content from React app

### Deliverables:
1. `lib/constants/mock_data.dart` - Convert `constants.ts` MOCK_BOOK to Dart
2. Copy all chapter content from React app
3. Ensure HTML content is preserved correctly

### Success Criteria:
- All chapters from React app are available
- Content formatting preserved
- Book metadata matches original

**Estimated Files:** 1 file

---

## **Phase 6: Reusable UI Components**
**Goal:** Build the widget library (icons, drawers, panels)

### Deliverables:
1. `lib/widgets/icons/custom_icons.dart` - Icon wrapper utilities
2. `lib/widgets/drawer/custom_drawer.dart` - Sliding drawer with backdrop
3. `lib/widgets/drawer/settings_drawer.dart` - Settings panel with sliders and theme buttons
4. `lib/widgets/drawer/toc_drawer.dart` - Table of contents with search, bookmarks, chapter list

### Success Criteria:
- All widgets compile independently
- Drawers can slide in/out with animations
- Settings panel updates settings in real-time
- TOC search algorithm works (3+ characters, 3 results per chapter)
- Widgets are reusable and properly themed

**Estimated Files:** 4 files

---

## **Phase 7: Main Application & Reader Screen**
**Goal:** Assemble everything into the working reader app

### Deliverables:
1. `lib/screens/reader_screen.dart` - Main reader with:
   - HTML content rendering with `flutter_html`
   - Auto-hiding controls
   - Chapter navigation (prev/next)
   - App bar with menu/bookmark/settings buttons
   - Reading progress bar
   - Scroll controller for auto-hide
2. `lib/main.dart` - App entry point with:
   - Provider setup (MultiProvider)
   - Theme switching from SettingsProvider
   - MaterialApp configuration

### Success Criteria:
- App launches without errors
- Can read chapters with proper HTML rendering
- Can switch between chapters
- Settings work (theme, font, size, line height)
- Bookmarks can be added/removed
- Search finds text across chapters
- Controls auto-hide after 3 seconds
- Last-read chapter persists across app restarts
- App matches React version in functionality

**Estimated Files:** 2 files

---

## **Phase 8: Platform Configuration & Polish** *(Optional)*
**Goal:** iOS/Android specific configuration and final touches

### Deliverables:
1. iOS Info.plist configuration
2. Android manifest updates
3. App icon and splash screen
4. Status bar styling
5. Safe area handling
6. Performance optimizations

### Success Criteria:
- App runs on both iOS and Android
- Proper branding (app name, icon)
- Platform-specific polish applied

**Estimated Files:** Configuration files only

---

## Summary by Phase

| Phase | Focus Area | Files | Can Test? |
|-------|-----------|-------|-----------|
| 1 | Setup | 2 | ✅ Structure |
| 2 | Models | 5 | ✅ Unit tests |
| 3 | Theme | 2 | ✅ Visual |
| 4 | State | 3 | ✅ Unit tests |
| 5 | Data | 1 | ✅ Data loads |
| 6 | Widgets | 4 | ✅ Widget tests |
| 7 | Integration | 2 | ✅ Full app |
| 8 | Polish | Config | ✅ Devices |

**Total Estimated Files:** ~19 Dart files + configuration

---

## Development Approach

After each phase:
1. ✅ Verify code compiles
2. ✅ Test core functionality
3. ✅ Commit to version control
4. ✅ Get approval before next phase

---

## Progress Tracking

- [x] Phase 1: Project Foundation & Setup ✅
- [x] Phase 2: Data Models & Core Types ✅
- [x] Phase 3: Theme System & Design Tokens ✅
- [x] Phase 4: Storage Service & State Management ✅
- [x] Phase 5: Mock Data & Constants ✅
- [x] Phase 6: Reusable UI Components ✅
- [x] Phase 7: Main Application & Reader Screen ✅
- [ ] Phase 8: Platform Configuration & Polish (Optional)

---

## Notes

- Flutter app will be created in `flutter_app/` subdirectory
- Each phase builds on previous work
- Code will be tested and verified before proceeding
- Plan follows the structure outlined in `FLUTTER_MIGRATION_GUIDE.md`
