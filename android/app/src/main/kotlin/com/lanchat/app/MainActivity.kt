package com.lanchat.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * LanChat 主 Activity
 * 处理系统分享 Intent 和 Flutter Method Channel 通信
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "LanChat"
        private const val SHARE_CHANNEL = "lanchat/share"
    }

    private var shareChannel: MethodChannel? = null
    private var pendingSharedFiles = mutableListOf<String>()
    private var pendingSharedText: String? = null
    private var pendingSourceApp: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 注册分享 Method Channel
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL
        )

        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedData" -> {
                    result.success(getSharedDataMap())
                    clearSharedData()
                }
                "clearSharedData" -> {
                    clearSharedData()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
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

    /**
     * 处理系统分享 Intent
     */
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        val action = intent.action
        val type = intent.type

        Log.d(TAG, "handleIntent: action=$action, type=$type")

        when (action) {
            Intent.ACTION_SEND -> handleSendIntent(intent)
            Intent.ACTION_SEND_MULTIPLE -> handleSendMultipleIntent(intent)
            Intent.ACTION_VIEW -> handleViewIntent(intent)
        }
    }

    /**
     * 处理发送单个文件
     */
    private fun handleSendIntent(intent: Intent) {
        // 提取来源 App
        pendingSourceApp = intent.`package` ?: "unknown"

        // 检查是否有文件
        val fileUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (fileUri != null) {
            val path = copyFileToCache(fileUri)
            if (path != null) {
                pendingSharedFiles.add(path)
                Log.d(TAG, "收到分享文件: $path")
            }
        }

        // 检查是否有文本
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (sharedText != null) {
            pendingSharedText = sharedText
        }

        // 通知 Flutter 端
        notifyFlutter()
    }

    /**
     * 处理发送多个文件
     */
    private fun handleSendMultipleIntent(intent: Intent) {
        pendingSourceApp = intent.`package` ?: "unknown"

        val fileUris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        if (fileUris != null) {
            for (uri in fileUris) {
                val path = copyFileToCache(uri)
                if (path != null) {
                    pendingSharedFiles.add(path)
                }
            }
            Log.d(TAG, "收到多个分享文件: ${pendingSharedFiles.size}")
        }

        notifyFlutter()
    }

    /**
     * 处理查看文件
     */
    private fun handleViewIntent(intent: Intent) {
        val uri = intent.data ?: return
        val path = copyFileToCache(uri)
        if (path != null) {
            pendingSharedFiles.add(path)
            pendingSourceApp = intent.`package` ?: "unknown"
            notifyFlutter()
        }
    }

    /**
     * 将 URI 文件复制到应用缓存目录
     */
    private fun copyFileToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null

            // 尝试获取文件名
            var fileName = "shared_file"
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(
                        android.provider.OpenableColumns.DISPLAY_NAME
                    )
                    if (nameIndex >= 0) {
                        fileName = it.getString(nameIndex) ?: fileName
                    }
                }
            }

            val cacheDir = File(cacheDir, "shared")
            cacheDir.mkdirs()
            val file = File(cacheDir, fileName)

            // 避免重名
            var finalFile = file
            var counter = 1
            while (finalFile.exists()) {
                val dot = fileName.lastIndexOf('.')
                val newName = if (dot == -1) {
                    "${fileName}_$counter"
                } else {
                    "${fileName.substring(0, dot)}_$counter${fileName.substring(dot)}"
                }
                finalFile = File(cacheDir, newName)
                counter++
            }

            FileOutputStream(finalFile).use { output ->
                inputStream.copyTo(output)
            }

            finalFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "复制文件失败: $uri", e)
            null
        }
    }

    /**
     * 通知 Flutter 端有新分享数据
     */
    private fun notifyFlutter() {
        shareChannel?.invokeMethod(
            "onSharedDataReceived",
            getSharedDataMap()
        )
    }

    /**
     * 构建分享数据 Map
     */
    private fun getSharedDataMap(): Map<String, Any?> {
        return mapOf(
            "filePaths" to pendingSharedFiles.toList(),
            "textContent" to pendingSharedText,
            "sourceApp" to pendingSourceApp
        )
    }

    /**
     * 清理已处理的分享数据
     */
    private fun clearSharedData() {
        pendingSharedFiles.clear()
        pendingSharedText = null
        pendingSourceApp = null
    }
}
