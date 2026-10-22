package com.bakeout.bakeout

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var faceVision: FaceVisionChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        faceVision = FaceVisionChannel(flutterEngine.dartExecutor.binaryMessenger).also { it.start() }
    }

    override fun onDestroy() {
        faceVision?.dispose()
        faceVision = null
        super.onDestroy()
    }
}
