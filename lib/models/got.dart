import 'memory.dart';

class GOT {
  final String id; // 그룹 고유 식별자
  final String name; // 그룹 이름
  final double latitude; // 그룹 위치 위도
  final double longitude; // 그룹 위치 경도
  String? locationString; // 위치 문자열 표현
  final List<Memory> memories; // 그룹에 속한 Memory 객체들

  GOT({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.locationString,
    required this.memories,
  });

  // 시간순으로 정렬된 메모리 리스트 반환 (최신순)
  List<Memory> getSortedMemoriesByTime({bool descending = true}) {
    final sortedList = List<Memory>.from(memories);
    sortedList.sort(
      (a, b) =>
          descending
              ? b.createdAt.compareTo(a.createdAt)
              : a.createdAt.compareTo(b.createdAt),
    );
    return sortedList;
  }

  // 시간 범위로 메모리 필터링
  List<Memory> filterByTimeRange(DateTime start, DateTime end) {
    return memories.where((memory) {
      return memory.createdAt.isAfter(start) && memory.createdAt.isBefore(end);
    }).toList();
  }

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'locationString': locationString,
      'memories': memories.map((memory) => memory.toJson()).toList(),
    };
  }

  // JSON에서 변환
  factory GOT.fromJson(Map<String, dynamic> json) {
    final memoriesJson = json['memories'] as List;
    final memoriesList =
        memoriesJson.map((memoryJson) => Memory.fromJson(memoryJson)).toList();

    return GOT(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      locationString: json['locationString'],
      memories: memoriesList,
    );
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

  // models/got.dart 파일에 다음 메서드 추가
  Memory getRepresentativeMemory() {
    List<Memory> sortedMemories = getSortedMemoriesByTime();

    // 미디어가 있는 메모리 먼저 찾기
    for (Memory memory in sortedMemories) {
      if (memory.hasMedia) {
        return memory;
      }
    }

    // 미디어가 없으면 가장 최근 메모리 반환
    return sortedMemories.first;
  }
}

// GOT 그룹을 관리하는 서비스 클래스
class GOTService {
  // 싱글톤 패턴
  static final GOTService _instance = GOTService._internal();

  factory GOTService() => _instance;

  GOTService._internal();

  final List<GOT> _groups = [];

  List<GOT> get groups => _groups;

  // 메모리를 적절한 그룹에 추가하거나 새 그룹 생성
  Future<void> addMemory(Memory memory) async {
    if (memory.latitude == null || memory.longitude == null) {
      return; // 위치 정보가 없으면 처리 안함
    }

    // 같은 위치의 그룹 찾기
    GOT? existingGroup;
    for (var group in _groups) {
      if (group.isSameLocation(memory.latitude!, memory.longitude!)) {
        existingGroup = group;
        break;
      }
    }

    // 기존 그룹이 있으면 거기에 추가
    if (existingGroup != null) {
      final existingMemories = existingGroup.memories;
      if (!existingMemories.any((m) => m.id == memory.id)) {
        existingMemories.add(memory);
      }
      return;
    }

    // 새 그룹 생성
    final locationString = await memory.getLocationString();
    final newGroup = GOT(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: locationString ?? "알 수 없는 위치",
      latitude: memory.latitude!,
      longitude: memory.longitude!,
      locationString: locationString,
      memories: [memory],
    );

    _groups.add(newGroup);
  }

  // 메모리 리스트를 그룹으로 구성
  Future<List<GOT>> organizeMemories(List<Memory> memories) async {
    _groups.clear();
    for (var memory in memories) {
      await addMemory(memory);
    }
    return _groups;
  }
}
