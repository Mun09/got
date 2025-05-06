// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // 게터
  Position? get currentPosition => _currentPosition;

  String? get currentAddress => _currentAddress;

  bool get isLoading => _isLoading;

  // 위치 권한 요청 및 초기화
  Future<void> initialize() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }

    await getCurrentLocation();
    startLocationUpdates();
  }

  // 현재 위치 한번만 가져오기
  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _updateAddressFromPosition();

      return _currentPosition;
    } catch (e) {
      print('위치 가져오기 오류: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 위치 스트림 시작
  void startLocationUpdates() {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      print("위치 업데이트: $position");
      _currentPosition = position;
      await _updateAddressFromPosition();
      notifyListeners();
    }, onError: (e) => print('위치 스트림 오류: $e'));
  }

  // 위치 정보로부터 주소 업데이트
  Future<void> _updateAddressFromPosition() async {
    if (_currentPosition == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        _currentAddress =
            "${place.locality ?? ''} ${place.subLocality ?? ''} ${place.thoroughfare ?? ''}";
      } else {
        _currentAddress =
            "위도: ${_currentPosition!.latitude}, 경도: ${_currentPosition!.longitude}";
      }
    } catch (e) {
      _currentAddress = "주소를 가져올 수 없습니다";
      print('주소 변환 오류: $e');
    }
  }

  // 리소스 정리
  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}
