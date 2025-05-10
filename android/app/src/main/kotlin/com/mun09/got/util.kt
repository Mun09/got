package com.mun09.got

import android.util.Log
import io.flutter.plugins.camera.BuildConfig

// 클래스 상단에 디버그 모드 감지 변수 추가
private val DEBUG = BuildConfig.DEBUG

// 로그 메서드 수정
public fun logDebug(tag: String, message: String) {
    if (DEBUG) {
        Log.d(tag, message)
    }
}