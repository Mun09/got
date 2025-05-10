// lib/models/got.dart
import '../services/memory_service.dart';
import 'memory.dart';

class GOT {
  final String id; // 그룹 고유 식별자
  final String name; // 그룹 이름 (필드 활용)
  final double latitude;
  final double longitude;
  String? locationString;
  final List<Memory> memories = [];
  DateTime createdAt;
  DateTime updatedAt;
  bool _needsRefresh = true;

  GOT({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.locationString,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // 좌표로부터 GOT ID 생성 (동일한 위치의 GOT를 식별하기 위함)
  static String generateIdFromCoordinates(double lat, double lng) {
    // 소수점 4자리까지 반올림하여 근사 위치 기반 ID 생성
    final roundedLat = (lat * 10000).round() / 10000;
    final roundedLng = (lng * 10000).round() / 10000;
    return '${roundedLat}_${roundedLng}';
  }

  // 시간순으로 정렬된 메모리 리스트 반환 (최신순)
  Future<List<Memory>> getSortedMemoriesByTime({bool descending = true}) async {
    // 캐싱 로직: 필요한 경우에만 검증 수행
    if (memories.isEmpty || _needsRefresh) {
      await refreshMemories();
      _needsRefresh = false;
    }

    // 메모리 복사본을 만들어 정렬
    final sortedList = List<Memory>.from(memories);
    sortedList.sort(
      (a, b) =>
          descending
              ? b.createdAt.compareTo(a.createdAt)
              : a.createdAt.compareTo(b.createdAt),
    );

    return sortedList;
  }

  void markNeedsRefresh() {
    _needsRefresh = true;
  }

  // 시간 범위로 메모리 필터링
  List<Memory> filterByTimeRange(DateTime start, DateTime end) {
    return memories.where((memory) {
      return memory.createdAt.isAfter(start) && memory.createdAt.isBefore(end);
    }).toList();
  }

  // 위치 문자열을 행정구역과 동네 이름까지만 간결하게 처리
  String getSimpleLocationString() {
    if (locationString == null) return "알 수 없는 위치";

    // 주소 문자열 파싱 (예: "대한민국 서울특별시 강남구 삼성동 123-45" -> "강남구 삼성동")
    List<String> parts = locationString!.split(', ');

    // 최소 3개 이상의 부분이 있는 경우 (국가, 시/도, 구/군 등)
    if (parts.length >= 3) {
      // 구/군과 동/읍/면 부분만 가져오기 (일반적으로 2-3번째 요소)
      return "${parts[parts.length > 3 ? 2 : 1]}, ${parts[parts.length > 3 ? 3 : 2]}";
    }

    // 파싱할 수 없는 경우 원본 반환 (단, 너무 길면 자르기)
    return locationString!.length > 20
        ? "${locationString!.substring(0, 20)}..."
        : locationString!;
  }

  // 위치 문자열 업데이트
  Future<void> updateLocationString() async {
    if (memories.isNotEmpty) {
      locationString = await memories.first.getLocationString();
    }
  }

  // 동일한 위치인지 확인하는 메서드 (근사치 허용)
  bool isSameLocation(double lat, double lng, {double threshold = 0.001}) {
    // threshold는 위치 차이의 허용 범위 (약 100m 정도)
    return (latitude - lat).abs() < threshold &&
        (longitude - lng).abs() < threshold;
  }

  // 대표 메모리 가져오기
  Future<Memory?> getRepresentativeMemory() async {
    if (memories.isEmpty) {
      return Memory.empty(); // Memory.empty() 대신 null 반환
    }

    try {
      // 이미지가 있는 메모리 우선
      final memoryWithMedia = memories.firstWhere(
        (memory) => memory.filePaths.isNotEmpty,
        orElse: () => memories.first,
      );
      return memoryWithMedia;
    } catch (e) {
      print('대표 메모리 로드 오류: $e');
      return null;
    }
  }

  // 유효한 메모리만 필터링하여 반환하는 비동기 메서드
  Future<List<Memory>> getValidMemories() async {
    final memoryService = MemoryService();
    List<Memory> validMemories = [];

    for (Memory memory in memories) {
      // 메모리가 실제로 데이터베이스에 존재하는지 확인
      Memory? validMemory = await memoryService.getMemoryById(memory.id);
      if (validMemory != null) {
        validMemories.add(validMemory);
      }
    }

    return validMemories;
  }

  // 현재 memories 리스트를 유효한 메모리로 업데이트
  Future<void> refreshMemories() async {
    final validMemories = await getValidMemories();
    memories.clear();
    memories.addAll(validMemories);
  }
}
