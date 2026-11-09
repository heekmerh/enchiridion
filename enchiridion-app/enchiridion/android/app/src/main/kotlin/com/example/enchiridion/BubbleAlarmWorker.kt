package com.example.enchiridion

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

private const val UNIQUE_WORK_NAME = "bubble_quick_check"
private const val FIRST_RUN_DELAY_MINUTES = 3L
private const val PREFS_NAME = "study_buddy_prefs"
private const val PREF_INTERVAL_MINUTES = "interval_minutes"
private const val PREF_ENABLED = "enabled"
const val DEFAULT_INTERVAL_MINUTES = 45L
private const val MIN_INTERVAL_MINUTES = 15L
private const val MAX_INTERVAL_MINUTES = 180L

// Runs `bubbleAlarmCallback` in a fresh, plugin-registered headless Flutter
// engine, then re-enqueues itself after the Study Buddy interval (default 45
// min) — keeping ambient "Quick Check" prompts flowing app-open or not. Not
// built on android_alarm_manager_plus: its headless engine never calls
// GeneratedPluginRegistrant.registerWith(...), so shared_preferences/
// supabase_flutter calls would throw MissingPluginException there.
class BubbleAlarmWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    companion object {
        // Set for the duration of a headless Dart entrypoint run; counted
        // down by BubblePlugin when Dart calls "workFinished".
        @Volatile
        var pendingLatch: CountDownLatch? = null

        fun armOnAppStart(context: Context, intervalMinutes: Long? = null) {
            if (intervalMinutes != null) {
                saveInterval(context, intervalMinutes)
            }
            setEnabled(context, true)
            val request = OneTimeWorkRequestBuilder<BubbleAlarmWorker>()
                .setInitialDelay(FIRST_RUN_DELAY_MINUTES, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.KEEP,
                request,
            )
        }

        // Unlike armOnAppStart's KEEP (never resets an already-ticking
        // countdown), a Settings change must take effect immediately:
        // REPLACE cancels the pending run and re-enqueues at the new interval.
        fun rearmForSettingsChange(context: Context, intervalMinutes: Long) {
            saveInterval(context, intervalMinutes)
            setEnabled(context, true)
            enqueueNext(context)
        }

        fun enqueueNext(context: Context) {
            val delayMinutes = getInterval(context)
            val request = OneTimeWorkRequestBuilder<BubbleAlarmWorker>()
                .setInitialDelay(delayMinutes, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }

        fun cancelSchedule(context: Context) {
            setEnabled(context, false)
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
        }

        fun getInterval(context: Context): Long {
            return try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.getLong(PREF_INTERVAL_MINUTES, DEFAULT_INTERVAL_MINUTES)
                    .coerceIn(MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES)
            } catch (_: Exception) {
                DEFAULT_INTERVAL_MINUTES
            }
        }

        private fun saveInterval(context: Context, intervalMinutes: Long) {
            try {
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putLong(
                        PREF_INTERVAL_MINUTES,
                        intervalMinutes.coerceIn(
                            MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES))
                    .apply()
            } catch (_: Exception) {
            }
        }

        private fun setEnabled(context: Context, enabled: Boolean) {
            try {
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(PREF_ENABLED, enabled)
                    .apply()
            } catch (_: Exception) {
            }
        }

        private fun isEnabled(context: Context): Boolean {
            return try {
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getBoolean(PREF_ENABLED, true)
            } catch (_: Exception) {
                true
            }
        }
    }

    override fun doWork(): Result {
        DiagLog.event(applicationContext, "START", "alarm_worker_dowork")
        val latch = CountDownLatch(1)
        pendingLatch = latch
        val engineRef = AtomicReference<FlutterEngine?>()

        Handler(Looper.getMainLooper()).post {
            try {
                val engine = FlutterEngine(applicationContext)
                GeneratedPluginRegistrant.registerWith(engine)
                engine.plugins.add(BubblePlugin())
                engineRef.set(engine)

                val appBundlePath =
                    FlutterInjector.instance().flutterLoader().findAppBundlePath()
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        appBundlePath,
                        "package:enchiridion/services/bubble_alarm_callback.dart",
                        "bubbleAlarmCallback",
                    ),
                )
            } catch (e: Exception) {
                DiagLog.event(applicationContext, "ERROR", "alarm_worker_engine_create", "error=$e")
                latch.countDown()
            }
        }

        // Bounded wait: bubbleAlarmCallback calls back via "workFinished"
        // when its work (picking a question, posting the bubble) is done.
        // If that signal never arrives — a crash, a hung network call — this
        // falls through, and the alarm chain still self-heals below.
        val signaled = latch.await(60, TimeUnit.SECONDS)
        pendingLatch = null
        DiagLog.event(
            applicationContext,
            "END",
            "alarm_worker_dowork",
            "signaled=$signaled",
        )

        Handler(Looper.getMainLooper()).post { engineRef.get()?.destroy() }

        // Always re-arm, regardless of what happened above — this is the
        // entire mechanism that keeps ambient prompts alive; see class doc.
        // Skipped only when the user has switched Study Buddy off.
        if (isEnabled(applicationContext)) {
            enqueueNext(applicationContext)
        }

        return Result.success()
    }
}
