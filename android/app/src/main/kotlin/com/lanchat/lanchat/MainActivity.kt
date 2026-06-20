package com.lanchat.lanchat

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "lanchat/share"
    private var methodChannel: MethodChannel? = null
    private val TAG = "MainActivity"
    private val SHARE_DATA_FILE = "share_data.json"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedData" -> {
                    val data = loadShareData()
                    result.success(data)
                }
                "clearSharedData" -> {
                    clearShareDataFile()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, "onCreate")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, "onNewIntent")
    }

    // onResume 不再需要，分享数据已持久化到文件

    private fun handleIntent(intent: Intent?, from: String) {
        if (intent == null) return
        val action = intent.action
        when (action) {
            Intent.ACTION_SEND -> {
                val data = parseSendIntent(intent)
                if (data != null) {
                    val filePaths = data["filePaths"] as? List<*>
                    showToast("收到分享：${filePaths?.size ?: 0} 个文件")
                    dispatchShareData(data)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val data = parseSendMultipleIntent(intent)
                if (data != null) {
                    val filePaths = data["filePaths"] as? List<*>
                    showToast("收到分享：${filePaths?.size ?: 0} 个文件")
                    dispatchShareData(data)
                }
            }
        }
    }

    private fun dispatchShareData(data: Map<String, Any?>) {
        saveShareData(data)
        if (methodChannel != null) {
            runOnUiThread {
                try {
                    methodChannel?.invokeMethod("onSharedDataReceived", data)
                } catch (e: Exception) {
                    Log.e(TAG, "invokeMethod onSharedDataReceived 失败", e)
                }
            }
        }
    }

    private fun parseSendIntent(intent: Intent): Map<String, Any?>? {
        return try {
            val extras = intent.extras ?: return null
            val text = extras.getCharSequence(Intent.EXTRA_TEXT)?.toString()
            val uri = extras.getParcelable<Uri>(Intent.EXTRA_STREAM)
            val filePath = if (uri != null) copyFileToAppDir(uri) else null
            val filePaths = if (filePath != null) listOf(filePath) else emptyList()
            val result = mutableMapOf<String, Any?>()
            if (text != null) result["textContent"] = text
            if (filePaths.isNotEmpty()) result["filePaths"] = filePaths
            result["sourceApp"] = null
            if (result["textContent"] != null || filePaths.isNotEmpty()) result else null
        } catch (e: Exception) {
            Log.e(TAG, "parseSendIntent 异常", e)
            null
        }
    }

    private fun parseSendMultipleIntent(intent: Intent): Map<String, Any?>? {
        return try {
            val extras = intent.extras ?: return null
            val text = extras.getCharSequence(Intent.EXTRA_TEXT)?.toString()
            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            val filePaths = uris?.mapNotNull { copyFileToAppDir(it) } ?: emptyList()
            val result = mutableMapOf<String, Any?>()
            if (text != null) result["textContent"] = text
            if (filePaths.isNotEmpty()) result["filePaths"] = filePaths
            result["sourceApp"] = null
            if (result["textContent"] != null || filePaths.isNotEmpty()) result else null
        } catch (e: Exception) {
            Log.e(TAG, "parseSendMultipleIntent 异常", e)
            null
        }
    }

    private fun copyFileToAppDir(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream == null) {
                Log.e(TAG, "copyFileToAppDir: 无法打开 URI: $uri")
                return null
            }

            val fileName = getFileNameFromUri(uri)
            val sharedDir = File(getExternalFilesDir(null), "shared")
            if (!sharedDir.exists()) sharedDir.mkdirs()
            val destFile = File(sharedDir, fileName)

            // 文件名冲突时加后缀
            val finalDest = if (destFile.exists()) {
                val name = destFile.name
                val dotIdx = name.lastIndexOf('.')
                val baseName = if (dotIdx >= 0) name.substring(0, dotIdx) else name
                val ext = if (dotIdx >= 0) name.substring(dotIdx + 1) else ""
                var counter = 1
                var newFile: File
                do {
                    val newName = if (ext.isNotEmpty()) "${baseName}_$counter.$ext" else "${baseName}_$counter"
                    newFile = File(sharedDir, newName)
                    counter++
                } while (newFile.exists())
                newFile
            } else {
                destFile
            }

            val outputStream = FileOutputStream(finalDest)
            inputStream.use { input ->
                outputStream.use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    bytesRead = input.read(buffer)
                    while (bytesRead != -1) {
                        output.write(buffer, 0, bytesRead)
                        bytesRead = input.read(buffer)
                    }
                    output.flush()
                }
            }

            finalDest.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "复制文件失败: $uri", e)
            null
        }
    }

    private fun getFileNameFromUri(uri: Uri): String {
        return try {
            val cursor = contentResolver.query(uri, arrayOf("_display_name"), null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex("_display_name")
                    if (nameIndex >= 0) {
                        return it.getString(nameIndex) ?: fallbackName(uri)
                    }
                }
            }
            fallbackName(uri)
        } catch (e: Exception) {
            Log.w(TAG, "获取文件名失败: $uri", e)
            fallbackName(uri)
        }
    }

    private fun fallbackName(uri: Uri): String {
        val lastSeg = uri.lastPathSegment ?: "file"
        return lastSeg.replace(Regex("[^a-zA-Z0-9._-]"), "_")
    }

    private fun showToast(msg: String) {
        runOnUiThread {
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        }
    }

    /**
     * 将分享数据写入 JSON 文件（持久化，Activity 重建不丢失）
     */
    private fun saveShareData(data: Map<String, Any?>) {
        try {
            val json = JSONObject()
            for ((key, value) in data) {
                json.put(key, value)
            }
            val file = File(getExternalFilesDir(null), SHARE_DATA_FILE)
            file.writeText(json.toString())
        } catch (e: Exception) {
            Log.e(TAG, "写入分享数据失败", e)
        }
    }

    /**
     * 从 JSON 文件读取分享数据
     */
    private fun loadShareData(): Map<String, Any?>? {
        return try {
            val file = File(getExternalFilesDir(null), SHARE_DATA_FILE)
            if (!file.exists()) return null
            val jsonStr = file.readText()
            val json = JSONObject(jsonStr)
            val result = mutableMapOf<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value = json.get(key)
                // JSONArray 转 List<String>
                if (key == "filePaths" && value is org.json.JSONArray) {
                    val list = mutableListOf<String>()
                    for (i in 0 until value.length()) {
                        list.add(value.getString(i))
                    }
                    result[key] = list
                } else if (value is String || value == null) {
                    result[key] = value
                }
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "读取分享数据失败", e)
            null
        }
    }

    /**
     * 清除分享数据文件
     */
    private fun clearShareDataFile() {
        try {
            val file = File(getExternalFilesDir(null), SHARE_DATA_FILE)
            if (file.exists()) file.delete()
        } catch (e: Exception) {
            Log.e(TAG, "删除分享数据文件失败", e)
        }
    }

    override fun onDestroy() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        super.onDestroy()
    }
}
