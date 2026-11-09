package com.example.enchiridion

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

private const val CHANNEL_NAME = "enchiridion/bubbles"
private const val NOTIFICATION_CHANNEL_ID = "quick_check"
private const val SHORTCUT_ID = "study_buddy"

// Stable per-question id for both the notification and its PendingIntent
// request code. A raw `questionId.hashCode()` could collide across question
// ids, which with FLAG_UPDATE_CURRENT delivers the wrong question's extras;
// deriving from the `exam-NNNN` trailing digits is collision-free instead.
internal fun quickCheckNotificationId(questionId: String): Int {
    val digits = questionId.takeLastWhile { it.isDigit() }
    val parsed = digits.toIntOrNull()
    // Offset keeps these clear of unrelated notification ids in this app.
    if (parsed != null) return 40000 + parsed
    // Non-conforming id (never in the bundled bank): fall back to a positive
    // hash. Collisions are possible but confined to this case.
    return 40000 + (questionId.hashCode() and 0xffff)
}

// Bridges the Dart bubble-notification code to the native "Quick Check"
// feature: scheduling (via BubbleAlarmWorker) and posting an Android Bubble
// (or plain notification fallback), both landing on BubbleActivity.
// Registered on three engines — the visible app, BubbleActivity, and the
// headless alarm worker — each calling only the methods relevant to it.
class BubblePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val context = appContext
        if (context == null) {
            result.error("no_context", "BubblePlugin not attached to an engine", null)
            return
        }
        when (call.method) {
            // Tells the Dart-side DiagnosticsLog exactly where DiagLog is
            // writing, so both land in the one file/timeline.
            "diagLogDir" -> {
                result.success(DiagLog.directory(context))
            }
            // Called on every Android app launch. KEEP preserves a pending
            // run and starts a new chain if WorkManager has lost the old one.
            "armBubbleSchedule" -> {
                val intervalArg = (call.argument<Number>("intervalMinutes"))?.toLong()
                DiagLog.event(context, "EVENT", "arm_on_app_start", "interval=$intervalArg")
                BubbleAlarmWorker.armOnAppStart(context, intervalArg)
                result.success(null)
            }
            // Called when the user changes the Study Buddy toggle/interval in
            // Settings. Unlike armBubbleSchedule (KEEP, for app-startup arm),
            // this uses REPLACE so a shortened/lengthened interval takes
            // effect immediately instead of waiting out the old schedule.
            "rearmBubbleSchedule" -> {
                val intervalArg = (call.argument<Number>("intervalMinutes"))?.toLong()
                    ?: DEFAULT_INTERVAL_MINUTES
                DiagLog.event(context, "EVENT", "rearm_for_settings_change", "interval=$intervalArg")
                BubbleAlarmWorker.rearmForSettingsChange(context, intervalArg)
                result.success(null)
            }
            "cancelBubbleSchedule" -> {
                DiagLog.event(context, "EVENT", "cancel_schedule")
                BubbleAlarmWorker.cancelSchedule(context)
                result.success(null)
            }
            // Called from the headless engine by bubbleAlarmCallback once it
            // has picked a question.
            "showBubble" -> {
                val scope = call.argument<String>("scope") ?: ""
                val questionId = call.argument<String>("questionId") ?: ""
                val title = call.argument<String>("title") ?: "Quick Check"
                val teaser = call.argument<String>("teaser") ?: ""
                // Full question text for the expanded view; falls back to
                // the teaser on older posts that didn't send it.
                val fullText = call.argument<String>("fullText") ?: teaser
                DiagLog.event(context, "EVENT", "show_bubble", "question_id=$questionId")
                showBubble(context, scope, questionId, title, teaser, fullText)
                result.success(null)
            }
            // Clears a prompt once its answer is recorded, without closing
            // the window, so backing out afterwards can't leave a prompt in
            // the shade for an already-answered question.
            "cancelBubbleNotification" -> {
                val questionId = call.argument<String>("questionId")
                if (questionId != null && questionId.isNotEmpty()) {
                    NotificationManagerCompat.from(context)
                        .cancel(quickCheckNotificationId(questionId))
                }
                result.success(null)
            }
            // Cancels only this window's own prompt: prompts are posted under
            // per-question ids now, so closing one must not clear another
            // that is still waiting in the shade. A missing questionId (a
            // window that never resolved one) closes without cancelling.
            "dismissBubble" -> {
                val questionId = call.argument<String>("questionId")
                DiagLog.event(context, "EVENT", "dismiss_bubble", "question_id=$questionId")
                if (questionId != null && questionId.isNotEmpty()) {
                    NotificationManagerCompat.from(context)
                        .cancel(quickCheckNotificationId(questionId))
                }
                activity?.finish()
                result.success(null)
            }
            // Called from the headless engine at the end of
            // bubbleAlarmCallback, success or failure — unblocks
            // BubbleAlarmWorker.doWork()'s wait so it can tear the engine
            // down and re-arm the next run.
            "workFinished" -> {
                DiagLog.event(context, "EVENT", "work_finished_signal")
                BubbleAlarmWorker.pendingLatch?.countDown()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return
        // Bubbles require IMPORTANCE_HIGH or above; below that Android will
        // never offer to expand the notification into a bubble at all.
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Quick Check",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Spaced-repetition study prompts."
        }
        manager.createNotificationChannel(channel)
    }

    private fun bubbleActivityIntent(context: Context, scope: String, questionId: String): Intent {
        // logdir lets bubble_main.dart start its log with no platform-channel
        // round trip, so that window can still be diagnosed when channels in
        // its engine are the thing that isn't responding.
        val route = "/bubble?scope=${Uri.encode(scope)}&question=${Uri.encode(questionId)}" +
            "&logdir=${Uri.encode(DiagLog.directory(context))}"
        return FlutterActivity.NewEngineIntentBuilder(BubbleActivity::class.java)
            .initialRoute(route)
            .build(context)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    private fun showBubble(
        context: Context,
        scope: String,
        questionId: String,
        title: String,
        teaser: String,
        fullText: String,
    ) {
        ensureNotificationChannel(context)

        val notificationId = quickCheckNotificationId(questionId)
        val contentIntent = bubbleActivityIntent(context, scope, questionId)
        // Bubble intents specifically must be mutable — Android rejects an
        // immutable PendingIntent in BubbleMetadata.
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val icon = IconCompat.createWithResource(context, R.mipmap.ic_launcher)
        val person = Person.Builder().setName("Study Buddy").setIcon(icon).build()

        val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            // Collapsed row shows the short teaser.
            .setContentText(teaser)
            .setStyle(
                // Expanded view shows the full question text, not the
                // truncated teaser — previously both showed the teaser, so
                // expanding the notification never revealed the rest.
                NotificationCompat.MessagingStyle(person)
                    .addMessage(fullText, System.currentTimeMillis(), person),
            )
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        // Bubbles are API 30+; wrapped defensively so an unexpected Bubbles
        // failure falls back to the plain notification above instead of
        // crashing the worker.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                publishShortcut(context, person, icon)
                builder.setShortcutId(SHORTCUT_ID)
                val bubbleMetadata = NotificationCompat.BubbleMetadata
                    .Builder(pendingIntent, icon)
                    .setDesiredHeight(600)
                    .setAutoExpandBubble(false)
                    .setSuppressNotification(false)
                    .build()
                builder.setBubbleMetadata(bubbleMetadata)
            } catch (_: Exception) {
                // Fall through with the plain notification built above.
            }
        }

        val notificationManager = NotificationManagerCompat.from(context)
        if (!notificationManager.areNotificationsEnabled()) {
            Log.w("BubbleAlarm", "outcome=notifications_disabled")
        }
        notificationManager.notify(notificationId, builder.build())
    }

    private fun publishShortcut(context: Context, person: Person, icon: IconCompat) {
        val shortcut = ShortcutInfoCompat.Builder(context, SHORTCUT_ID)
            .setLongLived(true)
            .setIcon(icon)
            .setShortLabel("Study Buddy")
            .setPersons(arrayOf(person))
            .setCategories(setOf("android.shortcut.conversation"))
            .setIntent(Intent(context, BubbleActivity::class.java).setAction(Intent.ACTION_VIEW))
            .build()
        ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
    }
}
