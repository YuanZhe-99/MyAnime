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

    /**
     * Purpose: Register Android share and file-open channels for the Flutter engine.
     * Inputs: `flutterEngine`.
     * Returns: None.
     * Side effects: Installs method-channel handlers and may dispatch the launch intent into Flutter.
     * Notes: Runs during activity startup and reuses the existing launch intent for cold-start file opens.
     */
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
                } else if (call.method == "shareFiles") {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    val uris = ArrayList<Uri>()
                    for (path in paths) {
                        uris.add(
                            FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                File(path)
                            )
                        )
                    }
                    val shareIntent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                        type = mimeType
                        putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
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

    /**
     * Purpose: Forward new Android intents to the shared file-open handler.
     * Inputs: `intent`.
     * Returns: None.
     * Side effects: May trigger `.myanimeitem` import delivery to Flutter.
     * Notes: Keeps warm-start file opens consistent with cold-start handling.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    /**
     * Purpose: Extract supported file-open intents and notify Flutter with a local file path.
     * Inputs: `intent`.
     * Returns: None.
     * Side effects: May copy content into cache storage and invoke the Flutter file-open channel.
     * Notes: Ignores intents that are not `ACTION_VIEW` or that cannot be copied locally.
     */
    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) {
            val uri = intent.data ?: return
            val path = copyToLocal(uri) ?: return
            fileOpenChannel?.invokeMethod("openFile", path)
        }
    }

    /**
     * Purpose: Copy an opened Android content URI into a temporary local `.myanimeitem` file.
     * Inputs: `uri`.
     * Returns: The cached file path, or `null` on failure.
     * Side effects: Reads from the content resolver and writes a temporary file in the app cache.
     * Notes: The imported file is timestamped to avoid name collisions.
     */
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
