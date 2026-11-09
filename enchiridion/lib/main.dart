import 'dart:io';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bubble_main.dart';
// Keeps the native-selected headless entrypoint library in the AOT program.
// ignore: unused_import
import 'services/bubble_alarm_callback.dart';

import 'config/supabase_config.dart';
import 'navigation/app_navigator.dart';
import 'providers/book_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/announcement_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/pinned_notes_provider.dart';
import 'providers/study_stats_provider.dart';
import 'services/access_service.dart';
import 'services/bubble_scheduler.dart';
import 'services/diagnostics_log.dart';
import 'services/user_data_sync_service.dart';
import 'services/notification_service.dart';
import 'services/play_billing_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common/app_zoom_scope.dart';
import 'widgets/common/system_navigation_inset.dart';
import 'widgets/exam_prep/in_app_study_prompt_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // BubbleActivity launches this same entrypoint (see BubbleActivity.kt): its
  // former secondary entrypoint never started in release AOT builds, leaving
  // the tapped-notification window blank forever. Branch before any of the
  // full-shell setup below — Supabase, sync, the alarm chain — none of which
  // the one-question window needs.
  if (isBubbleRoute(PlatformDispatcher.instance.defaultRouteName)) {
    runBubbleWindow();
    return;
  }

  FlutterError.onError = (details) {
    DiagnosticsLog.error(
        'main_flutter_error', details.exceptionAsString(), details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticsLog.error('main_uncaught_error', error, stack);
    return false;
  };
  // Not awaited: the channel lookup now retries, and on a platform without
  // BubblePlugin (desktop/web) that would otherwise add a second to startup.
  // Lines logged before it lands are buffered, not lost.
  unawaited(DiagnosticsLog.init('main'));
  DiagnosticsLog.event('main_start');

  await DiagnosticsLog.track(
    'main_supabase_init',
    () => Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey),
  );

  final prefs = await DiagnosticsLog.track(
      'main_storage_load', SharedPreferences.getInstance);
  final storageService = StorageService(prefs);
  // Lets AccessService timestamp successful validations so cached grants
  // expire back to freemium after 7 days without a successful check.
  AccessService.instance.bindStorage(storageService);
  // Pre-launch rename: carry dev-device PLAB data from `exam_prep` to
  // `exam_prep_plab`. No-op on fresh installs.
  await storageService.migrateLegacyExamPrepScope();

  // Cross-device continuity: every local user-data mutation uploads in the
  // background from here on; providers refresh via onUserDataMerged when
  // remote state lands.
  // Listening before the first frame lets Play redeliver purchases that finished while the app was closed.
  PlayBillingService.instance.start();

  final userDataSync = UserDataSyncService(storageService);
  storageService.onUserDataChanged = (entity) {
    unawaited(userDataSync.pushEntity(entity));
  };

  // Best-effort: a platform channel failure here (e.g. running on a bare
  // Windows/web target with no notification support) should not block app
  // startup — reviews still work locally, they just won't rebound in the
  // background.
  try {
    await DiagnosticsLog.track('main_notification_service_init',
        NotificationService.instance.initialize);
  } catch (_) {}

  // Ambient "Quick Check" bubble notifications are Android-only (no Bubbles
  // equivalent on iOS yet). Best-effort for the same reason as above.
  if (!kIsWeb && Platform.isAndroid) {
    final studyBuddy = storageService.getSettings();
    if (studyBuddy.studyBuddyEnabled) {
      await DiagnosticsLog.track(
        'main_bubble_arm_on_startup',
        () => BubbleScheduler().armOnStartup(
          intervalMinutes: studyBuddy.studyBuddyIntervalMinutes,
        ),
      );
    } else {
      await DiagnosticsLog.track(
          'main_bubble_cancel_schedule', BubbleScheduler().cancelSchedule);
    }
  }

  DiagnosticsLog.event('main_run_app');
  runApp(EnchiridionApp(storageService: storageService));
}

class EnchiridionApp extends StatefulWidget {
  final StorageService storageService;

  const EnchiridionApp({
    super.key,
    required this.storageService,
  });

  @override
  State<EnchiridionApp> createState() => _EnchiridionAppState();
}

class _EnchiridionAppState extends State<EnchiridionApp> {
  late final SettingsProvider _settingsProvider;
  late final BookmarkProvider _bookmarkProvider;
  late final PinnedNotesProvider _pinnedNotesProvider;
  late final StudyStatsProvider _studyStatsProvider;

  @override
  void initState() {
    super.initState();
    // Created once here — not per-build and not lazily — so the sync hooks
    // can refresh cached provider state after a cross-device pull merges
    // remote data.
    _settingsProvider = SettingsProvider(widget.storageService);
    _bookmarkProvider = BookmarkProvider(widget.storageService);
    _pinnedNotesProvider = PinnedNotesProvider(widget.storageService);
    _studyStatsProvider = StudyStatsProvider(widget.storageService);
    widget.storageService.onUserDataMerged = () {
      _settingsProvider.refresh();
      _bookmarkProvider.refresh();
      _pinnedNotesProvider.refresh();
      _studyStatsProvider.refresh();
    };
  }

  @override
  Widget build(BuildContext context) {
    final storageService = widget.storageService;
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider(create: (_) => AuthProvider(storageService)),
        ChangeNotifierProvider(create: (_) => BookProvider(storageService)),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _bookmarkProvider),
        ChangeNotifierProvider.value(value: _pinnedNotesProvider),
        ChangeNotifierProvider.value(value: _studyStatsProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            title: 'Enchiridion',
            debugShowCheckedModeBanner: false,
            navigatorKey: rootNavigatorKey,
            theme: AppTheme.getTheme(settingsProvider.settings.theme),
            builder: (context, child) => AppZoomScope(
              child: SystemNavigationInset(
                child: InAppStudyPromptHost(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
