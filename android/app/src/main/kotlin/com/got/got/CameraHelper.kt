package com.got.got

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraHelper(private val context: Context) {
    private val TAG = "CameraHelper"
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    fun capturePhoto(onSuccess: (String) -> Unit, onError: (String) -> Unit) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()

                // 이미지 캡처 설정
                val imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .build()

                // 카메라 선택
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                // 카메라 바인딩을 위한 LifecycleOwner 구현
                val lifecycleOwner = object : LifecycleOwner {
                    val lifecycleRegistry = LifecycleRegistry(this)

                    init {
                        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
                        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
                        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
                    }

                    override val lifecycle: Lifecycle
                        get() = lifecycleRegistry
                }

                cameraProvider.unbindAll()
                val camera = cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    imageCapture
                )

                // 사진 파일 생성
                val photoFile = createPhotoFile()
                val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()

                // 사진 촬영
                imageCapture.takePicture(
                    outputOptions,
                    ContextCompat.getMainExecutor(context),
                    object : ImageCapture.OnImageSavedCallback {
                        override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                            val savedUri = outputFileResults.savedUri ?: Uri.fromFile(photoFile)
                            Log.d(TAG, "사진이 성공적으로 갤러리에 저장됨: ${photoFile.absolutePath}")
                            onSuccess(photoFile.absolutePath)

                            // 리소스 해제
                            cameraProvider.unbindAll()
                            lifecycleOwner.lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
                            lifecycleOwner.lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
                            lifecycleOwner.lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
                        }

                        override fun onError(exception: ImageCaptureException) {
                            Log.e(TAG, "사진 촬영 실패: ${exception.message}", exception)
                            onError("사진 촬영 실패: ${exception.message}")

                            // 리소스 해제
                            cameraProvider.unbindAll()
                            lifecycleOwner.lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
                            lifecycleOwner.lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
                            lifecycleOwner.lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
                        }
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "카메라 사용 중 오류 발생", e)
                onError("카메라 바인딩 실패: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun createPhotoFile(): File {
        // GOT 폴더 생성
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val fileName = "JPEG_${timeStamp}.jpg"

        // context.cacheDir 사용
        val photoFile = File(context.cacheDir, fileName)
        return photoFile
    }

    fun shutdown() {
        cameraExecutor.shutdown()
    }
}