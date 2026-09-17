package com.example.enchiridion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the "answer one Quick Check question" window opened from a tapped
 * bubble (or, on devices/settings where Bubbles aren't available, a plain
 * notification — see [BubblePlugin.showBubble]).
 *
 * Runs its own Flutter engine on the `bubbleMain` Dart entrypoint (see
 * `lib/bubble_main.dart`) rather than the full app shell — no splash
 * screen, no auth gate, just the one question. Declared
 * `resizeableActivity`/`allowEmbedded` in AndroidManifest.xml so Android can
 * host it as an actual expand-in-place bubble; nothing here needs to know
 * whether it was launched as a bubble or as a normal activity — both cases
 * land on the same route.
 */
class BubbleActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "bubbleMain"
    override fun getDartEntrypointLibraryUri(): String = "package:enchiridion/bubble_main.dart"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BubblePlugin())
    }
}
