package xyz.nokarin.aqloss

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initAudioContext(applicationContext)
    }

    private external fun initAudioContext(context: Any)

    companion object {
        init {
            System.loadLibrary("aqloss_rust_core")
        }
    }
}