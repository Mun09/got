// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MediaQuality { low, medium, high }

class SettingsService extends ChangeNotifier {
  // 기본 설정값
  ThemeMode _themeMode = ThemeMode.system;
  double _defaultMapZoom = 15.0;
  bool _useCurrentLocationByDefault = true;
  MediaQuality _mediaQuality = MediaQuality.medium;
  String _userName = '';
  String _userEmail = '';

  // Getters
  ThemeMode get themeMode => _themeMode;

  double get defaultMapZoom => _defaultMapZoom;

  bool get useCurrentLocationByDefault => _useCurrentLocationByDefault;

  MediaQuality get mediaQuality => _mediaQuality;

  int get imageQuality {
    int quality;
    switch (_mediaQuality) {
      case MediaQuality.low:
        quality = 30; // 낮은 품질 (30%)
        break;
      case MediaQuality.medium:
        quality = 70; // 중간 품질 (70%)
        break;
      case MediaQuality.high:
        quality = 100; // 높은 품질 (100%)
        break;
    }
    return quality;
  }

  String get userName => _userName;

  String get userEmail => _userEmail;

  String get appVersion => '1.0.0';

  // SharedPreferences 키 정의
  static const String _themeModeKey = 'theme_mode';
  static const String _defaultMapZoomKey = 'default_map_zoom';
  static const String _useCurrentLocationKey = 'use_current_location';
  static const String _mediaQualityKey = 'media_quality';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  // 초기화
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 테마 모드
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    // 지도 설정
    _defaultMapZoom = prefs.getDouble(_defaultMapZoomKey) ?? 15.0;
    _useCurrentLocationByDefault =
        prefs.getBool(_useCurrentLocationKey) ?? true;

    // 미디어 품질
    final mediaQualityIndex = prefs.getInt(_mediaQualityKey) ?? 1;
    _mediaQuality = MediaQuality.values[mediaQualityIndex];

    // 사용자 정보
    _userName = prefs.getString(_userNameKey) ?? '';
    _userEmail = prefs.getString(_userEmailKey) ?? '';

    notifyListeners();
  }

  // 테마 모드 변경
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  // 기본 지도 줌 레벨 설정
  Future<void> setDefaultMapZoom(double zoom) async {
    _defaultMapZoom = zoom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultMapZoomKey, zoom);
    notifyListeners();
  }

  // 현재 위치 기본 사용 설정
  Future<void> setUseCurrentLocationByDefault(bool value) async {
    _useCurrentLocationByDefault = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useCurrentLocationKey, value);
    notifyListeners();
  }

  // 미디어 품질 설정
  Future<void> setMediaQuality(MediaQuality quality) async {
    _mediaQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mediaQualityKey, quality.index);
    notifyListeners();
  }

  // 사용자 정보 설정
  Future<void> setUserInfo(String name, String email) async {
    _userName = name;
    _userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    notifyListeners();
  }
}
