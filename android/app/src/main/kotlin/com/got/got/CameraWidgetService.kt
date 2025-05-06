package com.got.got

import android.app.Service
import android.content.Intent
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.Log

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import io.flutter.embedding.engine.FlutterEngineCache
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService

class CameraWidgetService : Service(), LifecycleOwner {
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    private lateinit var engine: FlutterEngine
    private lateinit var methodChannel: MethodChannel
    private val lifecycleRegistry = LifecycleRegistry(this)

    // 알림 관련 상수 추가
    companion object {
        private const val TAG = "CameraWidgetService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "camera_widget_channel"
        private const val CHANNEL_NAME = "카메라 위젯"
        private const val METHOD_CHANNEL_NAME = "com.got.got/camera_widget"
    }

    override fun onCreate() {
        super.onCreate()
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 포그라운드 서비스 시작
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        // Flutter 엔진 초기화
        try {
            initializeFlutterEngine()
            registerMethodChannel()

            // STARTED 상태로 라이프사이클 변경
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)

            // 위젯 클릭 시 즉시 사진 촬영
            Handler(Looper.getMainLooper()).postDelayed({
                // RESUMED 상태로 라이프사이클 변경
                lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
                takePictureWithoutPreview()
            }, 300) // 라이프사이클 상태 변경에 약간의 지연 추가

        } catch (e: Exception) {
            Log.e(TAG, "오류 발생: ${e.message}")
        }

        return START_STICKY
    }

    private fun takePictureWithoutPreview() {
        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()

                val imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .setFlashMode(ImageCapture.FLASH_MODE_AUTO)
                    .build()

                cameraProvider.bindToLifecycle(
                    this,
                    cameraSelector,
                    imageCapture
                )

                // 앱 내부 저장소에 파일 생성
                val timeStamp =
                    SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
                val fileName = "JPEG_${timeStamp}.jpg"
                val photoFile = File(cacheDir, fileName)

                val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()

                // 사진 촬영
                imageCapture.takePicture(
                    outputOptions,
                    ContextCompat.getMainExecutor(this),
                    object : ImageCapture.OnImageSavedCallback {
                        override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                            try {
                                val galleryPath = saveImageToGallery(photoFile)

                                Log.d(TAG, "사진이 성공적으로 갤러리에 저장됨: $galleryPath")

                                // 저장된 파일 경로 전달
                                if (::methodChannel.isInitialized) {
                                    methodChannel.invokeMethod(
                                        "imagePathFromNative",
                                        galleryPath
                                    )
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "이미지 저장 후 처리 중 오류: ${e.message}")
                            } finally {
                                cameraProvider.unbindAll()
                                stopSelf()
                            }
                        }

                        override fun onError(exception: ImageCaptureException) {
                            Log.e(TAG, "사진 촬영 실패: ${exception.message}", exception)
                            if (::methodChannel.isInitialized) {
                                methodChannel.invokeMethod(
                                    "onCameraError",
                                    exception.message ?: "카메라 오류 발생"
                                )
                            }
                            stopSelf()
                        }
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "카메라 사용 중 오류 발생", e)
                stopSelf()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun saveImageToGallery(imageFile: File): String {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "GOT_$timeStamp"

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "$imageFileName.jpg")
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/GOT")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = contentResolver
        val imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            ?: throw IOException("갤러리에 이미지를 저장할 수 없습니다")

        try {
            resolver.openOutputStream(imageUri)?.use { outputStream ->
                imageFile.inputStream().use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(imageUri, contentValues, null, null)
            }

            return getRealPathFromURI(imageUri) ?: imageUri.toString()
        } catch (e: Exception) {
            resolver.delete(imageUri, null, null)
            throw e
        } finally {
            // 임시 파일 삭제
            imageFile.delete()
        }
    }


    // URI를 실제 파일 경로로 변환하는 메서드
    private fun getRealPathFromURI(uri: android.net.Uri?): String {
        if (uri == null) return ""

        val projection = arrayOf(MediaStore.Images.Media.DATA)
        val cursor = contentResolver.query(uri, projection, null, null, null)

        cursor?.use {
            if (it.moveToFirst()) {
                val columnIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                return it.getString(columnIndex)
            }
        }

        // URI를 직접 경로로 사용 (fallback)
        return uri.toString()
    }


    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "위젯 카메라 사용 시 필요한 알림입니다"
                setShowBadge(false)
            }

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("카메라 서비스")
            .setContentText("위젯에서 사진을 촬영 중입니다")
            .setSmallIcon(R.drawable.ic_camera)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
    }

    private fun initializeFlutterEngine() {
        engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put("camera_widget_engine", engine)
    }

    private fun registerMethodChannel() {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePictureNative" -> {
                    takePictureAndReturnPath(result)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun takePictureAndReturnPath(result: MethodChannel.Result) {
        // 카메라 인텐트 생성
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)

        // 저장할 파일 생성
        val photoFile = createImageFile()

        // 파일 URI 생성
        val photoURI = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            photoFile
        )

        // 인텐트에 출력 파일 설정
        intent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(intent)
            result.success(photoFile.absolutePath)
        } catch (e: Exception) {
            result.error("CAMERA_ERROR", e.message, null)
        }
    }

    private fun createImageFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "JPEG_${timeStamp}_"
        val storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File.createTempFile(
            imageFileName,
            ".jpg",
            storageDir
        )
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        if (::engine.isInitialized) {
            engine.destroy()
        }
    }
}