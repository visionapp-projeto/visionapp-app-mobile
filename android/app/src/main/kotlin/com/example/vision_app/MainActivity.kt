package com.example.vision_app

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("DEEPLINK", "onNewIntent data=" + intent.dataString)
    }
}
