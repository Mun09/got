import 'package:geocoding/geocoding.dart';

class Memory {
  final String id; // 고유 식별자
  final String videoPath; // 동영상 파일 경로
  final String memo; // 메모 텍스트
  final DateTime createdAt; // 생성 날짜

  String? _locationCache; // 위치 정보 추가
  double? latitude;
  double? longitude;

  Memory({
    required this.id,
    required this.videoPath,
    required this.memo,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
  });

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoPath': videoPath,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // memory.dart 또는 memory_service.dart에 추가
  Future<String?> getLocationString() async {
    if (_locationCache != null) return _locationCache;
    if (latitude == null || longitude == null) return null;

    try {
      final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];

        // 상세 주소 정보 추출
        final List<String> addressParts = [];

        // 국가
        if (placemark.country?.isNotEmpty == true) {
          addressParts.add(placemark.country!);
        }

        // 행정 구역
        if (placemark.administrativeArea?.isNotEmpty == true) {
          addressParts.add(placemark.administrativeArea!);
        }

        // 하위 행정 구역
        if (placemark.subAdministrativeArea?.isNotEmpty == true) {
          addressParts.add(placemark.subAdministrativeArea!);
        }

        // 지역
        if (placemark.locality?.isNotEmpty == true) {
          addressParts.add(placemark.locality!);
        }

        // 하위 지역
        if (placemark.subLocality?.isNotEmpty == true) {
          addressParts.add(placemark.subLocality!);
        }

        // 도로명
        if (placemark.thoroughfare?.isNotEmpty == true) {
          addressParts.add(placemark.thoroughfare!);
        }

        // 건물 번호
        if (placemark.subThoroughfare?.isNotEmpty == true) {
          addressParts.add(placemark.subThoroughfare!);
        }

        // 우편번호
        if (placemark.postalCode?.isNotEmpty == true) {
          addressParts.add('(${placemark.postalCode!})');
        }

        // 주소 조합
        _locationCache = addressParts.join(', ');
        return _locationCache;
      }
    } catch (e) {
      print('주소 변환 오류: $e');
    }
    return null;
  }

  // JSON에서 객체로 변환
  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'],
      videoPath: json['videoPath'],
      memo: json['memo'],
      createdAt: DateTime.parse(json['createdAt']),
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}
