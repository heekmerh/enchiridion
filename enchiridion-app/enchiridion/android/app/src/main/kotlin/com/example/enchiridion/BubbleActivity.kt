package com.example.enchiridion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// Hosts the "answer one Quick Check question" window opened from a tapped
// bubble or fallback plain notification (see BubblePlugin.showBubble).
// Declared resizeableActivity/allowEmbedded in AndroidManifest.xml so
// Android can host it as an actual expand-in-place bubble. Deliberately does
// NOT override getDartEntrypointFunctionName: a `bubbleMain` entrypoint
// never worked in release AOT builds (isExecutingDart=true with no Dart
// statement ever running), so this runs the default `main` entrypoint,
// which branches to the bubble window on the launch route instead (see
// `runBubbleWindow`/`isBubbleRoute` in lib/bubble_main.dart).
class BubbleActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BubblePlugin())
        // Native→Dart boundary for a tap; the next log line should be
        // [bubble] bubble_main_entered, or Dart never started.
        DiagLog.event(this, "EVENT", "bubble_activity_engine_configured")
    }

    override fun onDestroy() {
        // Distinguishes closing via Close/Skip (preceded by dismiss_bubble)
        // from the system back button, which bypasses it.
        DiagLog.event(this, "EVENT", "bubble_activity_on_destroy")
        super.onDestroy()
    }
}
