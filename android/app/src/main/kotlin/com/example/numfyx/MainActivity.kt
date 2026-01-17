package com.yokwejuste.numfyx

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "numfyx/file_writer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveBytesToDownloads") {
                val args = call.arguments as? Map<String, Any>
                val fileName = args?.get("fileName") as? String ?: "numfyx_report.pdf"
                val bytes = args?.get("bytes") as? ByteArray
                if (bytes == null) {
                    result.error("NO_BYTES", "No bytes provided", null)
                    return@setMethodCallHandler
                }
                try {
                    val contentValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            put(MediaStore.MediaColumns.RELATIVE_PATH, "Download")
                        }
                    }
                    val resolver = applicationContext.contentResolver
                    val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                    if (uri == null) {
                        result.error("INSERT_FAILED", "Could not create MediaStore entry", null)
                        return@setMethodCallHandler
                    }
                    resolver.openOutputStream(uri).use { os ->
                        os?.write(bytes)
                        os?.flush()
                    }
                    result.success(uri.toString())
                } catch (e: Exception) {
                    result.error("WRITE_FAILED", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
