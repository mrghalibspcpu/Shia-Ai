package com.shiaai.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.shiaai.app/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "refresh") {
                    MomentWidgetProvider.refreshAll(this)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
