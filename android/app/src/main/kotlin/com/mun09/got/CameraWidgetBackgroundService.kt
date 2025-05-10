package com.mun09.got

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import java.util.HashSet
import java.util.concurrent.atomic.AtomicBoolean

class CameraWidgetBackgroundService : Service() {
    private val TAG = "CameraWidgetService"
    private var wakeLock: PowerManager.WakeLock? = null
    private var flutterEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private var locationManager: LocationManager? = null
    private val isRunning = AtomicBoolean(false)

    // 위치 리스너
    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            // 위치 정보가 업데이트될 때만 사용하므로 별도 처리 없음
        }

        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

        override fun onProviderEnabled(provider: String) {}

        override fun onProviderDisabled(provider: String) {}
    }

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "com.got.got.camera_widget"
        const val NOTIFICATION_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "서비스 생성")

        // 위치 매니저 초기화
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        // 포그라운드 서비스 시작
        createNotificationChannel()
        startForeground()

        // WakeLock 획득
        acquireWakeLock()

        // Flutter 엔진 초기화

    }

    private fun getOrCreateFlutterEngine() {
        if (flutterEngine == null) {
            initializeFlutterEngine()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "카메라 위젯 서비스",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "위젯 작동을 위한 백그라운드 서비스입니다"
            }

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForeground() {
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("GOT 위젯 서비스 실행 중")
            .setContentText("위젯이 정상적으로 작동하고 있습니다")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "GOT::CameraWidgetWakeLock"
        )
        wakeLock?.acquire(30 * 1000L) // 30초 동안 WakeLock 유지
    }

    private fun initializeFlutterEngine() {
        try {
            // SharedPreferences에서 콜백 핸들 가져오기
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val callbackHandleString =
                prefs.getString("flutter.camera_widget_callback_handle", null)

            if (callbackHandleString != null) {
                val callbackHandle = callbackHandleString.toLong()
                val callbackInfo =
                    FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

                if (callbackInfo != null) {
                    // Flutter 엔진 생성
                    flutterEngine = FlutterEngine(this)

                    // Dart 콜백 실행 준비
                    val dartBundlePath =
                        FlutterInjector.instance().flutterLoader().findAppBundlePath()
                    flutterEngine?.dartExecutor?.executeDartCallback(
                        DartExecutor.DartCallback(
                            assets,
                            dartBundlePath,
                            callbackInfo
                        )
                    )

                    // 메서드 채널 설정
                    backgroundChannel = MethodChannel(
                        flutterEngine!!.dartExecutor.binaryMessenger,
                        "com.got.got/background_service"
                    )

                    Log.d(TAG, "Flutter 엔진 초기화 완료")
                    isRunning.set(true)
                } else {
                    Log.e(TAG, "콜백 정보를 찾을 수 없습니다")
                }
            } else {
                Log.e(TAG, "콜백 핸들이 저장되어 있지 않습니다")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Flutter 엔진 초기화 실패", e)
        }
    }

    private var shouldRun = true

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "서비스 시작 명령 수신: ${intent?.action}")

        when (intent?.action) {
            "TAKE_PHOTO" -> {
                takePhotoAndProcess()
            }

            "STOP_SERVICE" -> {
                Log.d(TAG, "서비스 종료 요청 수신")
                shouldRun = false
                _stopForeground();
                stopSelf()
                return START_NOT_STICKY
            }
        }    // 작업 완료 후 자동 종료를 위한 타이머 설정
        // 최대 1분 후에 자동 종료
        Handler(Looper.getMainLooper()).postDelayed({
            if (shouldRun) {
                Log.d(TAG, "시간 초과로 서비스 자동 종료")
                _stopForeground()
                stopSelf()
            }
        }, 60 * 1000L) // 1분

        // 서비스가 종료되더라도 자동으로 재시작하지 않음
        // 배터리 최적화
        return START_NOT_STICKY
    }

    private fun takePhotoAndProcess() {
        // 카메라를 통해 사진 촬영 및 저장
        CameraHelper(this).capturePhoto(
            onSuccess = { imagePath ->
                Log.d(TAG, "사진 촬영 성공: $imagePath")
                processImage(imagePath)
            },
            onError = { error ->
                Log.e(TAG, "사진 촬영 실패: $error")
            }
        )
    }

    private fun processImage(imagePath: String) {
        // 위치 정보 가져오기
        try {
            getOrCreateFlutterEngine()
            if (locationPermissionGranted()) {
                getCurrentLocation { location ->
                    if (location != null) {
                        // Flutter 엔진에 위치 정보와 이미지 경로 전달
                        if (isRunning.get() && flutterEngine != null && backgroundChannel != null) {
                            val args = HashMap<String, Any>()
                            args["imagePath"] = imagePath
                            args["latitude"] = location.latitude
                            args["longitude"] = location.longitude

                            backgroundChannel?.invokeMethod("processImage", args)
                            logDebug(
                                TAG,
                                "위치 정보와 함께 이미지 처리: $imagePath, 위치: ${location.latitude}, ${location.longitude}"
                            )
                        } else {
                            // Flutter 엔진이 없거나 실행 중이 아닌 경우 로컬 저장
                            saveImageInfoLocally(imagePath, location.latitude, location.longitude)
                        }
                    } else {
                        // 위치가 null인 경우
                        if (isRunning.get() && backgroundChannel != null) {
                            backgroundChannel?.invokeMethod(
                                "processImage",
                                mapOf("imagePath" to imagePath)
                            )
                        } else {
                            saveImageInfoLocally(imagePath, null, null)
                        }
                        Log.d(TAG, "위치 정보 없이 이미지 처리: $imagePath")
                    }
                }
            } else {
                // 권한이 없는 경우
                if (isRunning.get() && backgroundChannel != null) {
                    backgroundChannel?.invokeMethod("processImage", mapOf("imagePath" to imagePath))
                } else {
                    saveImageInfoLocally(imagePath, null, null)
                }
                Log.d(TAG, "위치 권한 없음, 이미지만 처리: $imagePath")
            }
        } catch (e: Exception) {
            Log.e(TAG, "이미지 처리 중 오류 발생", e)
        }

        setServiceShutdownTimer(5000L) // 5초 후 종료
        releaseWakeLockIfNeeded();
    }

    // 중복 타이머 설정을 방지하기 위한 변수
    private var shutdownTimerSet = false

    private fun setServiceShutdownTimer(delayMillis: Long) {
        if (!shutdownTimerSet) {
            shutdownTimerSet = true
            Handler(Looper.getMainLooper()).postDelayed({
                if (shouldRun) {
                    Log.d(TAG, "작업 완료 후 서비스 종료")
                    _stopForeground()
                    stopSelf()
                }
            }, delayMillis)
        }
    }

    // 이미지 처리 완료 후 WakeLock 해제
    private fun releaseWakeLockIfNeeded() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "WakeLock 해제됨")
            }
        }
    }

    // 현재 위치 가져오기
    private fun getCurrentLocation(callback: (Location?) -> Unit) {
        try {
            // 마지막으로 알려진 위치 확인
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = locationManager.getProviders(true)
            var bestLocation: Location? = null

            // 사용 가능한 모든 제공자에서 마지막 위치 확인
            for (provider in providers) {
                val location = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || location.accuracy < bestLocation.accuracy) {
                    bestLocation = location
                }
            }

            if (bestLocation != null && bestLocation.time >= System.currentTimeMillis() - 5 * 60 * 1000) {
                // 최근 5분 이내의 위치면 바로 반환
                callback(bestLocation)
                return
            }

            // 실시간 위치 업데이트 요청
            val locationTimeout = 5000L // 10초 제한
            var locationReceived = false

            // GPS 또는 네트워크 제공자 사용
            val gpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val networkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

            if (gpsEnabled || networkEnabled) {
                val provider =
                    if (gpsEnabled) LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER

                val singleUpdateListener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        locationManager.removeUpdates(this)
                        locationReceived = true
                        callback(location)
                    }

                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }

                locationManager.requestLocationUpdates(
                    provider,
                    0L,
                    0f,
                    singleUpdateListener
                )

                // 제한 시간 이후에 위치를 받지 못했으면 최선의 위치 사용
                android.os.Handler().postDelayed({
                    if (!locationReceived) {
                        locationManager.removeUpdates(singleUpdateListener)
                        callback(bestLocation)
                    }
                }, locationTimeout)
            } else {
                // 제공자가 없으면 최선의 위치 반환
                callback(bestLocation)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "위치 권한 거부됨", e)
            callback(null)
        } catch (e: Exception) {
            Log.e(TAG, "위치 가져오기 오류", e)
            callback(null)
        }
    }

    // 위치 권한 확인
    private fun locationPermissionGranted(): Boolean {
        return checkCallingOrSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
                checkCallingOrSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    // Flutter 엔진이 사용불가능할 때 로컬에 데이터 저장
    private fun saveImageInfoLocally(imagePath: String, latitude: Double?, longitude: Double?) {
        // SharedPreferences에 경로와 위치 정보 저장
        val prefs = getSharedPreferences("GOT_PENDING_IMAGES", Context.MODE_PRIVATE)
        val pendingImages =
            prefs.getStringSet("pending_images", HashSet<String>()) ?: HashSet<String>()

        val imageData =
            "$imagePath|${latitude ?: "null"}|${longitude ?: "null"}|${System.currentTimeMillis()}"
        val newPendingImages = HashSet<String>(pendingImages)
        newPendingImages.add(imageData)

        prefs.edit().putStringSet("pending_images", newPendingImages).apply()
        Log.d(TAG, "이미지 정보를 로컬에 저장: $imageData")
    }

    override fun onDestroy() {
        Log.d(TAG, "서비스 종료")
        releaseWakeLockIfNeeded()

        try {
            locationManager?.removeUpdates(locationListener)
        } catch (e: Exception) {
            Log.e(TAG, "위치 업데이트 제거 중 오류", e)
        }

        flutterEngine?.destroy()
        flutterEngine = null
        backgroundChannel = null
        isRunning.set(false)

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    fun _stopForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // API 33+
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) { // API 24-32
            stopForeground(true)
        } else { // API 23 이하
            stopForeground(true)
        }
    }
}