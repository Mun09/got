package com.got.got

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import android.os.Handler
import android.os.Looper

class CameraWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "CameraWidgetProvider"
        private const val ACTION_TAKE_PHOTO = "com.got.got.ACTION_TAKE_PHOTO"
        private const val ACTION_BLINK_WIDGET = "com.got.got.ACTION_BLINK_WIDGET"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_BLINK_WIDGET) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )

            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                // 카메라 셔터 소리 재생
                playCameraSound(context)

                // 깜박임 효과 적용 후 사진 촬영
                blinkWidgetAndTakePhoto(context, widgetId)
            }
        }
    }

    private fun playCameraSound(context: Context) {
        try {
            val mediaPlayer = MediaPlayer.create(
                context,
                android.provider.MediaStore.Audio.Media.INTERNAL_CONTENT_URI
            )

            if (mediaPlayer != null) {
                mediaPlayer.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .build()
                )
                mediaPlayer.start()
                mediaPlayer.setOnCompletionListener { mp -> mp.release() }
            } else {
                // 대체 소리 사용
                val soundPool = SoundPool.Builder()
                    .setMaxStreams(1)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .build()
                    )
                    .build()

                val soundId = soundPool.load(context, R.raw.camera_click, 1)
                soundPool.setOnLoadCompleteListener { _, _, _ ->
                    soundPool.play(soundId, 1f, 1f, 0, 0, 1f)
                }

                Handler(Looper.getMainLooper()).postDelayed({
                    soundPool.release()
                }, 1000)
            }
        } catch (e: Exception) {
            // 소리 재생 중 오류 발생 시 무시
        }
    }

    private fun blinkWidgetAndTakePhoto(context: Context, widgetId: Int) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val views = RemoteViews(context.packageName, R.layout.camera_widget)
        val handler = Handler(Looper.getMainLooper())

        // 깜박임 효과를 위해 투명도 변경 (어둡게)
        views.setInt(R.id.widget_camera_button, "setAlpha", 100)
        appWidgetManager.updateAppWidget(widgetId, views)

        // 다시 원래 상태로
        handler.postDelayed({
            views.setInt(R.id.widget_camera_button, "setAlpha", 255)
            appWidgetManager.updateAppWidget(widgetId, views)

            // 사진 촬영 서비스 시작
            val serviceIntent = Intent(context, CameraWidgetBackgroundService::class.java).apply {
                action = "TAKE_PHOTO"
            }
            context.startService(serviceIntent)
        }, 200) // 0.2초 후 원래 상태로
    }


    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate: 위젯 업데이트 시작")

        // 각 위젯 인스턴스마다 뷰 업데이트
        for (widgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        // 위젯 레이아웃 가져오기
        val views = RemoteViews(context.packageName, R.layout.camera_widget)
        views.setInt(R.id.widget_camera_button, "setBackgroundColor", Color.TRANSPARENT)

        // 깜박임 효과를 위한 인텐트
        val blinkIntent = Intent(context, CameraWidgetProvider::class.java).apply {
            action = ACTION_BLINK_WIDGET
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }

        // 안드로이드 버전에 따른 PendingIntent 플래그 설정
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val blinkPendingIntent = PendingIntent.getBroadcast(
            context,
            widgetId,  // 고유한 ID 사용
            blinkIntent,
            pendingIntentFlags
        )

        // 클릭 시 깜박임 효과 동작하도록 설정
        views.setOnClickPendingIntent(R.id.widget_camera_button, blinkPendingIntent)

        // 위젯 업데이트
        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "위젯 ID $widgetId 업데이트 완료")
    }

    override fun onEnabled(context: Context) {
        // 첫 위젯이 추가될 때 호출됨
        Log.d(TAG, "onEnabled: 첫 위젯 활성화")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // 마지막 위젯이 제거될 때 호출됨
        Log.d(TAG, "onDisabled: 모든 위젯 비활성화")

        // 모든 위젯이 삭제되면 서비스 종료
        val stopIntent = Intent(context, CameraWidgetBackgroundService::class.java).apply {
            action = "STOP_SERVICE"
        }
        context.startService(stopIntent)
    }

    // 위젯이 삭제될 때 서비스 종료
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)

        // 위젯이 삭제되면 서비스 종료
        val stopIntent = Intent(context, CameraWidgetBackgroundService::class.java).apply {
            action = "STOP_SERVICE"
        }
        context.startService(stopIntent)
    }


}