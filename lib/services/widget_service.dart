// lib/services/widget_service.dart 수정
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'location_service.dart';
import 'memory_service.dart';

// 백그라운드에서 호출될 콜백 함수
@pragma('vm:entry-point')
void widgetCameraCallback() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 위젯 서비스 준비
  await WidgetService.initialize();
}

class WidgetService {
  static const foregroundPlatform = MethodChannel('com.got.got/camera_widget');
  static const backgroundPlatform = MethodChannel(
    'com.got.got/background_service',
  );

  // 초기화 메서드
  static Future<void> initialize() async {
    // 위젯 콜백 등록
    final callback =
        PluginUtilities.getCallbackHandle(widgetCameraCallback)?.toRawHandle();

    // 콜백 핸들 저장
    if (callback != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'camera_widget_callback_handle',
        callback.toString(),
      );

      // 네이티브에 콜백 ID 전달
      try {
        await foregroundPlatform.invokeMethod('registerCallback', {
          'callbackHandle': callback,
        });
      } catch (e) {
        print('네이티브에 콜백 등록 실패: $e');
      }
    }

    // 메서드 채널 리스너 설정
    foregroundPlatform.setMethodCallHandler(_handleMethodCall);
    backgroundPlatform.setMethodCallHandler(_handleBackgroundCall);
  }

  // 메인 메서드 채널 핸들러
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'processBackgroundImage') {
      // 백그라운드에서 저장된 이미지 처리
      final imagePath = call.arguments['imagePath'] as String;
      final latitude = call.arguments['latitude'] as double?;
      final longitude = call.arguments['longitude'] as double?;

      await _processBackgroundImage(imagePath, latitude, longitude);
    }
    return null;
  }

  // 백그라운드 메서드 채널 핸들러
  static Future<dynamic> _handleBackgroundCall(MethodCall call) async {
    print('백그라운드 호출: ${call.method}');

    if (call.method == 'processImage') {
      final imagePath = call.arguments['imagePath'] as String;
      final latitude = call.arguments['latitude'] as double?;
      final longitude = call.arguments['longitude'] as double?;

      // 네이티브에서 이미 수집된 위치 정보와 함께 이미지 처리
      await _processBackgroundImage(imagePath, latitude, longitude);
    }
    return null;
  }

  // 백그라운드에서 이미지 처리 (네이티브에서 위치정보 제공)
  static Future<void> _processBackgroundImage(
    String imagePath,
    double? latitude,
    double? longitude,
  ) async {
    try {
      // 사진 파일
      final savedImage = File(imagePath);

      // MemoryService 초기화 및 데이터베이스 연결
      final memoryService = MemoryService();

      // 메모리 저장
      await memoryService.saveMemory(
        [savedImage.path],
        '위젯에서 자동 촬영',
        '위젯에서 자동 촬영',
        latitude,
        longitude,
      );

      print('백그라운드 자동 촬영 이미지 저장 완료: $imagePath');
    } catch (e) {
      print('백그라운드 이미지 처리 중 오류: $e');
    }
  }

  // 네이티브에서 촬영된 이미지 처리 (앱이 실행 중일 때)
  static Future<void> processImageFromNative(String imagePath) async {
    try {
      print("자동 촬영 완료: $imagePath");

      // 위치 정보 가져오기
      final LocationService locationService = LocationService();
      final position = await locationService.getBackgroundLocation().catchError(
        (error) {
          print('위치 정보 가져오기 실패: $error');
          return null;
        },
      );

      if (position != null)
        print("위치 정보: ${position.latitude}, ${position.longitude}");
      else
        print("위치 정보를 가져올 수 없습니다.");

      // MemoryService로 저장
      await _processBackgroundImage(
        imagePath,
        position?.latitude,
        position?.longitude,
      );
    } catch (e) {
      print('이미지 처리 중 오류: $e');
    }
  }
}
