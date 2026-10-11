package com.example.enchiridion

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // BubblePlugin is app-local (not a pub package), so it is not part of
        // GeneratedPluginRegistrant and must be added explicitly on every
        // engine that needs it — this one (the visible app), BubbleActivity's
        // engine, and the headless engine BubbleAlarmWorker creates.
        flutterEngine.plugins.add(BubblePlugin())
        DiagLog.event(this, "EVENT", "main_activity_engine_configured")
    }
}
