class Memory {
  final String id; // 고유 식별자
  final String videoPath; // 동영상 파일 경로
  final String memo; // 메모 텍스트
  final DateTime createdAt; // 생성 날짜

  Memory({
    required this.id,
    required this.videoPath,
    required this.memo,
    required this.createdAt,
  });

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoPath': videoPath,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // JSON에서 객체로 변환
  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'],
      videoPath: json['videoPath'],
      memo: json['memo'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
