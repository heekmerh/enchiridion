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
private const val NOTIFICATION_ID = 4271
private const val SHORTCUT_ID = "study_buddy"

/**
 * Bridges `lib/services/bubble_alarm_callback.dart`, `lib/bubble_main.dart`,
 * and `lib/main.dart` to the native pieces of the ambient "Quick Check"
 * bubble-notification feature: scheduling (via [BubbleAlarmWorker]) and
 * posting an Android Bubble (falling back to a plain notification where
 * Bubbles aren't supported/allowed — both land on [BubbleActivity]).
 *
 * Registered on three different engines (see each call site's comment):
 * the visible app's engine, [BubbleActivity]'s engine, and the headless
 * engine [BubbleAlarmWorker] creates — each only ever calls the subset of
 * methods relevant to it.
 */
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
            // Called on every Android app launch. KEEP preserves a pending
            // run and starts a new chain if WorkManager has lost the old one.
            "armBubbleSchedule" -> {
                BubbleAlarmWorker.armOnAppStart(context)
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
                showBubble(context, scope, questionId, title, teaser, fullText)
                result.success(null)
            }
            // Called from BubbleActivity's engine (bubble_main.dart) once
            // the user has closed the answer card.
            "dismissBubble" -> {
                NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
                activity?.finish()
                result.success(null)
            }
            // Called from the headless engine at the end of
            // bubbleAlarmCallback, success or failure — unblocks
            // BubbleAlarmWorker.doWork()'s wait so it can tear the engine
            // down and re-arm the next run.
            "workFinished" -> {
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
        val route = "/bubble?scope=${Uri.encode(scope)}&question=${Uri.encode(questionId)}"
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

        val contentIntent = bubbleActivityIntent(context, scope, questionId)
        // Bubble intents specifically must be mutable — Android rejects an
        // immutable PendingIntent in BubbleMetadata.
        val pendingIntent = PendingIntent.getActivity(
            context,
            questionId.hashCode(),
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

        // Bubbles are API 30+. Wrapped defensively: if anything about this
        // device/build's Bubbles surface behaves unexpectedly, falling back
        // to the plain notification built above (still fully functional —
        // it opens the same BubbleActivity, just not as an actual bubble)
        // is strictly better than crashing the worker.
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
        notificationManager.notify(NOTIFICATION_ID, builder.build())
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
