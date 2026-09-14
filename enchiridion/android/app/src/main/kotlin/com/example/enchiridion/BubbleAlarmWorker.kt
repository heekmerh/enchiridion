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
import kotlin.random.Random

private const val UNIQUE_WORK_NAME = "bubble_quick_check"
private const val MIN_DELAY_MINUTES = 18L
private const val JITTER_MINUTES = 18L // delay = MIN_DELAY_MINUTES + random(0..JITTER_MINUTES)

/**
 * Runs `bubbleAlarmCallback` (lib/services/bubble_alarm_callback.dart) in a
 * fresh, fully plugin-registered headless Flutter engine, then always
 * re-enqueues itself for another run 18-35 minutes later — this is what
 * keeps ambient "Quick Check" prompts flowing whether or not the app is
 * open.
 *
 * Deliberately not built on the `android_alarm_manager_plus` pub package:
 * that plugin's headless engine (`FlutterBackgroundExecutor.
 * startBackgroundIsolate`, in its own Android source) never calls
 * `GeneratedPluginRegistrant.registerWith(...)` — its own README even flags
 * this as an unresolved "may be necessary" gap under "Using other plugins in
 * alarm callbacks" — so `shared_preferences`/`supabase_flutter` calls inside
 * a callback scheduled through it would throw `MissingPluginException`.
 * `WorkManager` gives the same "run Dart in the background, app open or
 * not" capability while leaving engine creation to us, so plugins can be
 * registered correctly.
 */
class BubbleAlarmWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    companion object {
        /**
         * Set for the duration of a headless Dart entrypoint run; counted
         * down by [BubblePlugin] when Dart calls "workFinished".
         */
        @Volatile
        var pendingLatch: CountDownLatch? = null

        fun enqueueNext(context: Context) {
            val delayMinutes = MIN_DELAY_MINUTES + Random.nextLong(JITTER_MINUTES + 1)
            val request = OneTimeWorkRequestBuilder<BubbleAlarmWorker>()
                .setInitialDelay(delayMinutes, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }

    override fun doWork(): Result {
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
                    DartExecutor.DartEntrypoint(appBundlePath, "bubbleAlarmCallback"),
                )
            } catch (_: Exception) {
                latch.countDown()
            }
        }

        // Bounded wait: bubbleAlarmCallback calls back via "workFinished"
        // when its work (picking a question, posting the bubble) is done.
        // If that signal never arrives — a crash, a hung network call — this
        // falls through, and the alarm chain still self-heals below.
        latch.await(60, TimeUnit.SECONDS)
        pendingLatch = null

        Handler(Looper.getMainLooper()).post { engineRef.get()?.destroy() }

        // Always re-arm, regardless of what happened above — this is the
        // entire mechanism that keeps ambient prompts alive; see class doc.
        enqueueNext(applicationContext)

        return Result.success()
    }
}
