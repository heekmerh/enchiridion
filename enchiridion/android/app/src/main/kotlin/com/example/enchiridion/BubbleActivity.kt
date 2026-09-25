package com.example.enchiridion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the "answer one Quick Check question" window opened from a tapped
 * bubble (or, on devices/settings where Bubbles aren't available, a plain
 * notification — see [BubblePlugin.showBubble]).
 *
 * Runs its own Flutter engine on the default `main` entrypoint, which
 * branches to the one-question window on the launch route (see
 * `runBubbleWindow` in `lib/bubble_main.dart`) rather than booting the full
 * app shell — no splash screen, no auth gate, just the question. Declared
 * `resizeableActivity`/`allowEmbedded` in AndroidManifest.xml so Android can
 * host it as an actual expand-in-place bubble; nothing here needs to know
 * whether it was launched as a bubble or as a normal activity — both cases
 * land on the same route.
 */
class BubbleActivity : FlutterActivity() {
    // Deliberately does NOT override getDartEntrypointFunctionName /
    // getDartEntrypointLibraryUri. Pointing them at a `bubbleMain` entrypoint
    // in `bubble_main.dart` never worked in release AOT builds: the engine
    // reported isExecutingDart=true while not a single Dart statement ran, so
    // the window stayed blank forever. The default `main` entrypoint is the
    // one proven to run, and `main()` branches to the bubble window on the
    // launch route (see isBubbleRoute in lib/bubble_main.dart).

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BubblePlugin())
        // The native→Dart boundary for a tap. Everything before it is native
        // engine construction, invisible to any Dart-side timeout; the next
        // line in the log should be [bubble] bubble_main_entered. If it isn't,
        // Dart never started (the failure described above).
        DiagLog.event(this, "EVENT", "bubble_activity_engine_configured")
    }

    override fun onDestroy() {
        // Distinguishes closing via Close/Skip (preceded by dismiss_bubble)
        // from the system back button, which bypasses it.
        DiagLog.event(this, "EVENT", "bubble_activity_on_destroy")
        super.onDestroy()
    }
}
