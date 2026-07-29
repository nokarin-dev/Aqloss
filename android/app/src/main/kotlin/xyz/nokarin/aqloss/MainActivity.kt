package xyz.nokarin.aqloss

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val fileOpenChannel = "xyz.nokarin.aqloss/file_open"
    private var flutterFileChannel: MethodChannel? = null
    private var pendingFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initAudioContext(applicationContext)
        MediaControlsPlugin.register(this, flutterEngine.dartExecutor.binaryMessenger)
        AudioRoutePlugin.register(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        flutterFileChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            fileOpenChannel,
        )
        // Flush pending path from onCreate
        pendingFilePath?.let { path ->
            flutterFileChannel?.invokeMethod("openFile", path)
            pendingFilePath = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    // Intent handling
    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val path = resolveToLocalPath(uri) ?: return

        val ch = flutterFileChannel
        if (ch != null) {
            ch.invokeMethod("openFile", path)
        } else {
            pendingFilePath = path
        }
    }

    private fun resolveToLocalPath(uri: Uri): String? = when (uri.scheme) {
        "file" -> uri.path
        "content" -> copyContentToCache(uri)
        else -> null
    }

    private fun copyContentToCache(uri: Uri): String? = try {
        val name = queryFileName(uri) ?: "aqloss_import_${System.currentTimeMillis()}"
        val dest = File(cacheDir, name)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(dest).use { input.copyTo(it) }
        }
        dest.absolutePath
    } catch (_: Exception) { null }

    private fun queryFileName(uri: Uri): String? = try {
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (c.moveToFirst() && i >= 0) c.getString(i) else null
        }
    } catch (_: Exception) { null }

    // Native init
    private external fun initAudioContext(context: Any)

    companion object {
        init { System.loadLibrary("aqloss_rust_core") }
    }
}