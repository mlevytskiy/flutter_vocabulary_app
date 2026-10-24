package com.unique.androidvocabularyapp

import android.content.Intent
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.provider.Settings
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
        // "Move to Settings" when the microphone is refused (owner, 2026-10-24):
        // this app's info page, with Permissions one tap away.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab/app_settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
