import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Keep native-selected secondary entrypoint libraries in the AOT program.
// ignore: unused_import
import 'bubble_main.dart';
// ignore: unused_import
import 'services/bubble_alarm_callback.dart';

import 'config/supabase_config.dart';
import 'navigation/app_navigator.dart';
import 'providers/book_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/pinned_notes_provider.dart';
import 'services/bubble_scheduler.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/exam_prep/in_app_study_prompt_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // Best-effort: a platform channel failure here (e.g. running on a bare
  // Windows/web target with no notification support) should not block app
  // startup — reviews still work locally, they just won't rebound in the
  // background.
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  // Ambient "Quick Check" bubble notifications are Android-only (no Bubbles
  // equivalent on iOS yet). Best-effort for the same reason as above.
  if (!kIsWeb && Platform.isAndroid) {
    await BubbleScheduler().armOnStartup();
  }

  runApp(EnchiridionApp(storageService: storageService));
}

class EnchiridionApp extends StatelessWidget {
  final StorageService storageService;

  const EnchiridionApp({
    super.key,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider(create: (_) => AuthProvider(storageService)),
        ChangeNotifierProvider(create: (_) => BookProvider(storageService)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => BookmarkProvider(storageService)),
        ChangeNotifierProvider(
            create: (_) => PinnedNotesProvider(storageService)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            title: 'Enchiridion',
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            theme: AppTheme.getTheme(settingsProvider.settings.theme),
            builder: (context, child) => InAppStudyPromptHost(
              child: child ?? const SizedBox.shrink(),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
