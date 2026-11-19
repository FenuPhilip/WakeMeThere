package com.wakemethere.app

import android.content.Intent
import com.wakemethere.app.bridge.WakeMeThereChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WakeMeThereChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Deprecated in Android API; required for the system ringtone picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        WakeMeThereChannel.onActivityResult(requestCode, resultCode, data)
    }
}
