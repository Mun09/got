package com.got.got

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.RemoteViews

class CameraWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "CameraWidgetProvider"
        private const val ACTION_TAKE_PHOTO = "com.got.got.ACTION_TAKE_PHOTO"
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

        // 버튼 클릭 시 백그라운드 서비스 실행 (카메라 기능 작동)
        val intent = Intent(context, CameraWidgetBackgroundService::class.java).apply {
            action = "TAKE_PHOTO"
        }

        // 안드로이드 버전에 따른 PendingIntent 플래그 설정
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getService(context, 0, intent, pendingIntentFlags)
        views.setOnClickPendingIntent(R.id.widget_camera_icon, pendingIntent)

        // 위젯 업데이트
        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "위젯 ID $widgetId 업데이트 완료")

        // 백그라운드 서비스 시작 (위젯 초기화용)
        val serviceIntent = Intent(context, CameraWidgetBackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    override fun onEnabled(context: Context) {
        // 첫 위젯이 추가될 때 호출됨
        Log.d(TAG, "onEnabled: 첫 위젯 활성화")
    }

    override fun onDisabled(context: Context) {
        // 마지막 위젯이 제거될 때 호출됨
        Log.d(TAG, "onDisabled: 모든 위젯 비활성화")
    }
}