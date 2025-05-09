import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/got.dart';
import '../models/memory.dart';
import 'dart:async';

class GoogleMapService {
  // 싱글톤 인스턴스
  static final GoogleMapService _instance = GoogleMapService._internal();

  // 팩토리 생성자
  factory GoogleMapService() => _instance;

  // 내부 생성자
  GoogleMapService._internal();

  // 마커 캐시
  final Map<String, Marker> _markerCache = {};

  // 마커 세트
  Set<Marker> _markers = {};

  // 현재 지도 컨트롤러
  GoogleMapController? _mapController;

  // GOT 서비스
  final GOTService _gotService = GOTService();

  // 마커 세트 getter
  Set<Marker> get markers => _markers;

  // 지도 컨트롤러 설정
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  // 지도 컨트롤러 getter
  GoogleMapController? get mapController => _mapController;

  // 지도 컨트롤러 해제
  void disposeMapController() {
    _mapController?.dispose();
    _mapController = null;
  }

  // 메모리 목록에서 GOT 기반 마커 생성
  Future<Set<Marker>> buildMarkers(
    List<Memory> memories,
    Function(GOT) navigateToDetail,
  ) async {
    Set<Marker> newMarkers = {};

    // 메모리 리스트를 GOT 그룹으로 변환
    final gotGroups = await _gotService.organizeMemories(memories);

    // 각 GOT에 대해 하나의 마커 생성
    for (int i = 0; i < gotGroups.length; i++) {
      final got = gotGroups[i];

      // 캐시에서 마커 찾기
      final cacheKey = 'got_${got.id}';
      if (_markerCache.containsKey(cacheKey)) {
        newMarkers.add(_markerCache[cacheKey]!);
      } else {
        // 캐시에 없으면 새로 생성
        final marker = await _createGOTMarker(got, i, navigateToDetail);
        if (marker != null) {
          _markerCache[cacheKey] = marker;
          newMarkers.add(marker);
        }
      }
    }

    _markers = newMarkers;
    return _markers;
  }

  // GOT별 마커 생성 함수
  Future<Marker?> _createGOTMarker(
    GOT got,
    int index,
    Function(GOT) navigateToDetail,
  ) async {
    try {
      // 다양한 색상 지정 (고정된 색상 배열 사용)
      final colors = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.pink,
        Colors.amber,
      ];

      final color = colors[index % colors.length];

      // 색상 및 기록 개수에 따른 마커 크기 조정
      final size = 40 + (got.memories.length > 10 ? 10 : got.memories.length);

      // 커스텀 아이콘 생성
      final BitmapDescriptor customIcon = await _createCircleMarkerIcon(
        color,
        size.toDouble(),
        text: got.memories.length > 1 ? '${got.memories.length}' : null,
      );

      return Marker(
        icon: customIcon,
        markerId: MarkerId('got_${got.id}'),
        position: LatLng(got.latitude, got.longitude),
        infoWindow: InfoWindow(
          title: got.name,
          snippet: '${got.memories.length}개의 기록',
          onTap: () {
            print("GOT 마커 탭: ${got.name}");
            navigateToDetail(got);
          },
        ),
        onTap: () {
          // 정보창 표시 및 상세 페이지로 이동 로직
          if (_mapController != null) {
            _mapController!.showMarkerInfoWindow(MarkerId('got_${got.id}'));
          }
        },
      );
    } catch (e) {
      print('GOT 마커 생성 오류: $e');
      return null;
    }
  }

  // 커스텀 마커 비트맵 생성 함수 (텍스트 추가 기능 포함)
  static Future<BitmapDescriptor> _createCircleMarkerIcon(
    Color color,
    double size, {
    String? text,
  }) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;

    // 원형 배경 그리기
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    // 흰색 테두리 추가
    final Paint borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 1, borderPaint);

    // 텍스트 추가 (기록 개수 표시)
    if (text != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size / 2.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          size / 2 - textPainter.width / 2,
          size / 2 - textPainter.height / 2,
        ),
      );
    }

    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // 날짜 포맷 함수
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month}.${dateTime.day}';
  }

  // 특정 위치로 카메라 이동
  void moveCameraToPosition(LatLng position, {double zoom = 15.0}) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, zoom));
  }

  // 전체 마커가 보이도록 카메라 이동
  void fitMapToBounds() {
    if (_markers.isEmpty || _mapController == null) return;

    // 모든 마커의 위치를 포함하는 경계 계산
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (Marker marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng)
        minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng)
        maxLng = marker.position.longitude;
    }

    // 경계에 패딩 추가
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50, // 패딩
      ),
    );
  }

  // 마커 캐시 초기화
  void clearMarkerCache() {
    _markerCache.clear();
    _markers.clear();
  }
}
