package com.mun09.got

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.edit
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.got.got/camera_widget"
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "registerCallback") {
                try {
                    val callbackHandle = call.argument<Long>("callbackHandle")
                    // SharedPreferences에 콜백 저장
                    getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit() {
                        putString(
                            "flutter.camera_widget_callback_handle",
                            callbackHandle.toString()
                        )
                    }

                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        Handler(Looper.getMainLooper()).postDelayed({
            loadPendingImages()
        }, 2000) // 앱 초기화 완료 후 2초 뒤에 실행

    }

    private fun loadPendingImages() {
        val prefs = getSharedPreferences("GOT_PENDING_IMAGES", Context.MODE_PRIVATE)
        val pendingImages = prefs.getStringSet("pending_images", HashSet<String>())

        if (!pendingImages.isNullOrEmpty()) {
            logDebug("MainActivity", "저장된 이미지 정보 ${pendingImages.size}개 발견")

            val processedImages = HashSet<String>()

            for (imageData in pendingImages) {
                try {
                    val parts = imageData.split("|")
                    if (parts.size < 4) continue

                    val imagePath = parts[0]
                    val latitude = if (parts[1] == "null") null else parts[1].toDoubleOrNull()
                    val longitude = if (parts[2] == "null") null else parts[2].toDoubleOrNull()
                    val timestamp = parts[3].toLongOrNull() ?: System.currentTimeMillis()

                    // 파일 존재 확인
                    val file = File(imagePath)
                    if (!file.exists()) {
                        processedImages.add(imageData) // 파일이 없으면 처리된 것으로 간주
                        continue
                    }

                    // Flutter에 전달할 인자 준비
                    val args = HashMap<String, Any>()
                    args["imagePath"] = imagePath
                    if (latitude != null) args["latitude"] = latitude
                    if (longitude != null) args["longitude"] = longitude

                    // Flutter 메서드 호출
                    channel.invokeMethod("processBackgroundImage", args)

                    // 성공적으로 전달된 항목 표시
                    processedImages.add(imageData)
                } catch (e: Exception) {
                    logDebug("MainActivity", "이미지 처리 중 오류: ${e.message}")
                }
            }

            // 처리된 항목 제거
            val remainingImages = HashSet<String>(pendingImages)
            remainingImages.removeAll(processedImages)

            // 남은 항목만 저장
            prefs.edit() { putStringSet("pending_images", remainingImages) }
        }
    }
}

