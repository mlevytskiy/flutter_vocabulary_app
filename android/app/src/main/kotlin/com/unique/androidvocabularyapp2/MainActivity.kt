package com.unique.androidvocabularyapp2

import android.graphics.Rect
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The photo tab's area of the screen edge is kept out of the Back
        // gesture (side-bar-for-main-screen ADR-0002). Android 10+ only;
        // below that there is no edge gesture to exclude.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab/system_gesture_exclusion")
            .setMethodCallHandler { call, result ->
                if (call.method != "setRects") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val rects = (call.arguments as? List<*>).orEmpty().mapNotNull { item ->
                        val m = item as? Map<*, *> ?: return@mapNotNull null
                        Rect(
                            (m["left"] as Number).toInt(),
                            (m["top"] as Number).toInt(),
                            (m["right"] as Number).toInt(),
                            (m["bottom"] as Number).toInt(),
                        )
                    }
                    window.decorView.systemGestureExclusionRects = rects
                }
                result.success(null)
            }
    }
}
