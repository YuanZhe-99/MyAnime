package com.yuanzhe.my_anime

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var fileOpenChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        fileOpenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yuanzhe.my_anime/file_open")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yuanzhe.my_anime/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareFile") {
                    val path = call.argument<String>("path")!!
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        File(path)
                    )
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    val chooser = Intent.createChooser(shareIntent, null).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(chooser)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Handle file open from launch intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) {
            val uri = intent.data ?: return
            val path = copyToLocal(uri) ?: return
            fileOpenChannel?.invokeMethod("openFile", path)
        }
    }

    private fun copyToLocal(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val tempFile = File(cacheDir, "import_${System.currentTimeMillis()}.myanimeitem")
            tempFile.outputStream().use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()
            tempFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
